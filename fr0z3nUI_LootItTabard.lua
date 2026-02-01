---@diagnostic disable: undefined-global, deprecated

local ADDON = ...

local PREFIX = "|cff00ccff[LI:Tabard]|r "

local DATA = rawget(_G, "fr0z3nUI_LootItTabardDB")

local Tabard = {}
_G.fr0z3nUI_LootItTabard = Tabard

local ACCDB
local CHARDB

local EXALTED_MIN = 42000
local EXALTED_MAX = 42999

local function EnsureTables()
	if type(ACCDB) ~= "table" then return end
	ACCDB.tabard = (type(ACCDB.tabard) == "table") and ACCDB.tabard or {}
	local db = ACCDB.tabard
	if db.enabled == nil then db.enabled = true end
	if db.delay == nil then db.delay = 0.75 end
	if db.hideRepBarWhenNoChampion == nil then db.hideRepBarWhenNoChampion = false end
	if type(db.modeByContext) ~= "table" then
		db.modeByContext = {
			solo = "nochange",
			city = "closest",
			dungeon = "closest",
			raid = "nochange",
			pvp = "nochange",
		}
	end
	if type(db.tabardMap) ~= "table" then db.tabardMap = {} end

	if type(CHARDB) == "table" then
		-- tri-state override: true/false/nil
		-- CHARDB.tabardEnabledOverride
	end
end

function Tabard.Init(accountDB, characterDB)
	ACCDB = accountDB
	CHARDB = characterDB
	EnsureTables()
	Tabard._initialized = true
end

local function IsEnabled()
	EnsureTables()
	if type(CHARDB) == "table" and CHARDB.tabardEnabledOverride ~= nil then
		return (CHARDB.tabardEnabledOverride == true)
	end
	return (ACCDB and ACCDB.tabard and ACCDB.tabard.enabled) and true or false
end

function Tabard.GetEnableMode()
	EnsureTables()
	if type(CHARDB) == "table" and CHARDB.tabardEnabledOverride == true then return "on" end
	if type(CHARDB) == "table" and CHARDB.tabardEnabledOverride == false then return "off" end
	if ACCDB and ACCDB.tabard and ACCDB.tabard.enabled then return "acc" end
	return "off"
end

function Tabard.SetEnableMode(mode)
	EnsureTables()
	mode = tostring(mode or ""):lower()
	if type(CHARDB) ~= "table" then return end
	if mode == "on" then
		CHARDB.tabardEnabledOverride = true
	elseif mode == "acc" then
		CHARDB.tabardEnabledOverride = nil
		ACCDB.tabard.enabled = true
	else
		CHARDB.tabardEnabledOverride = false
	end
	Tabard.OnSettingsChanged("enable")
end

local function getDB()
	EnsureTables()
	return ACCDB and ACCDB.tabard
end

local function getTotalRepFromFactionData(data)
	if not data then return nil end
	if type(data.currentStanding) == "number" and type(data.currentReactionThreshold) == "number" then
		return data.currentReactionThreshold + data.currentStanding
	end
	if type(data.currentStandingEarned) == "number" then
		return data.currentStandingEarned
	end
	return nil
end

local function getStandingIdFromFactionData(data)
	if not data then return 0 end
	return tonumber(data.reaction or data.standingID) or 0
end

local function getFactionDataByID(factionId)
	factionId = tonumber(factionId)
	if not factionId then return nil end
	if C_Reputation and C_Reputation.GetFactionDataByID then
		return C_Reputation.GetFactionDataByID(factionId)
	end
	if GetFactionInfoByID then
		local name, _, standingId, barMin, barMax, barVal = GetFactionInfoByID(factionId)
		if not name then return nil end
		return {
			factionID = factionId,
			name = name,
			standingID = standingId,
			currentReactionThreshold = tonumber(barMin) or 0,
			nextReactionThreshold = tonumber(barMax) or 0,
			currentStanding = (tonumber(barVal) or 0) - (tonumber(barMin) or 0),
			currentStandingEarned = tonumber(barVal) or 0,
		}
	end
	return nil
end

local function isTabardItem(itemID)
	if not itemID then return false end
	local equipLoc = C_Item and C_Item.GetItemInventoryTypeByID and C_Item.GetItemInventoryTypeByID(itemID)
	if type(equipLoc) == "number" then
		-- INVSLOT_TABARD is 19; inventory type is a different enum; use tooltip scan fallback.
	end
	local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemID)
	return itemEquipLoc == "INVTYPE_TABARD"
end

local ScanTooltip
local function getScanTooltip()
	if ScanTooltip then return ScanTooltip end
	local tt = CreateFrame("GameTooltip", "fr0z3nUI_LootItTabardScanTooltip", UIParent, "GameTooltipTemplate")
	tt:SetOwner(UIParent, "ANCHOR_NONE")
	ScanTooltip = tt
	return tt
end

local function buildFactionNameToIDMap()
	local map, names = {}, {}
	if not (C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex) then
		return map, names
	end
	local count = C_Reputation.GetNumFactions()
	for i = 1, count do
		local data = C_Reputation.GetFactionDataByIndex(i)
		if data and data.name and data.factionID then
			map[data.name] = data.factionID
			names[#names + 1] = data.name
		end
	end
	table.sort(names, function(a, b) return #a > #b end)
	return map, names
end

local function extractFactionIdFromTooltip(tooltip, factionNameToId, factionNames)
	for i = 2, tooltip:NumLines() do
		local left = _G[tooltip:GetName() .. "TextLeft" .. i]
		local text = left and left:GetText()
		if text and text ~= "" then
			local lower = string.lower(text)
			if string.find(lower, "champion", 1, true) then
				for _, name in ipairs(factionNames) do
					if string.find(text, name, 1, true) then
						return factionNameToId[name]
					end
				end
			end
		end
	end
	return nil
end

local function isIdInMapList(id, list)
	if not (id and list) then return false end
	local needle = tostring(id)
	for idStr in string.gmatch(list, "%d+") do
		if idStr == needle then return true end
	end
	return false
end

local function getPlayerUiMapID()
	if C_Map and C_Map.GetBestMapForUnit then
		return C_Map.GetBestMapForUnit("player")
	end
	return nil
end

local function getInstanceMapID()
	local _, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
	return instanceMapID
end

local function isInTabardGroup(itemID, groupKey)
	if groupKey == "all" then return true end
	if not (DATA and DATA.tabardGroup and DATA.tabardGroup[groupKey]) then return false end
	local list = DATA.tabardGroup[groupKey]
	for idStr in string.gmatch(list, "%d+") do
		if tonumber(idStr) == itemID then return true end
	end
	return false
end

local function getCurrentDungeonTierGroup()
	local inInstance, instanceType = IsInInstance()
	if not inInstance then return nil end
	if instanceType ~= "party" and instanceType ~= "scenario" then return nil end

	local _, _, difficultyID = GetInstanceInfo()
	local heroic = (difficultyID == 2 or difficultyID == 23 or difficultyID == 8 or difficultyID == 24 or difficultyID == 33)

	local tier
	-- Scenarios treated as D90 in legacy addon.
	if instanceType == "scenario" then
		tier = "D90"
	elseif DATA and DATA.maps then
		local maps = DATA.maps
		local instanceMapID = getInstanceMapID()
		local uiMapID = getPlayerUiMapID()
		local function inBucket(bucket)
			local list = maps[bucket]
			return isIdInMapList(instanceMapID, list) or isIdInMapList(uiMapID, list)
		end

		if inBucket("X85") then
			tier = heroic and "D85" or "D60"
		elseif inBucket("X90") then
			tier = heroic and "D90" or "D60"
		elseif inBucket("H90") then tier = "H90"
		elseif inBucket("D90") then tier = "D90"
		elseif inBucket("H85") then tier = "H85"
		elseif inBucket("D85") then tier = "D85"
		elseif inBucket("H80") then tier = "H80"
		elseif inBucket("D80") then tier = "D80"
		elseif inBucket("D70") then tier = "D70"
		elseif inBucket("D60") then tier = "D60"
		elseif inBucket("D100") then tier = "D100"
		elseif inBucket("D110") then tier = "D110"
		end
	end

	if not tier then
		local playerLevel = UnitLevel("player")
		if playerLevel <= 80 then tier = heroic and "H80" or "D80"
		elseif playerLevel <= 85 then tier = heroic and "H85" or "D85"
		elseif playerLevel <= 90 then tier = heroic and "H90" or "D90"
		elseif playerLevel <= 100 then tier = "D100"
		elseif playerLevel <= 110 then tier = "D110"
		else tier = "D120" end
	end

	local group = ({
		D80 = "D80tabards",
		H80 = "D80tabards",
		D85 = "D85tabards",
		H85 = "D85tabards",
		D90 = "D90tabards",
		H90 = "D90tabards",
		D100 = "D100tabards",
		D110 = "D110tabards",
		D120 = "D120tabards",
	})[tier]

	return group, tier
end

local STATE = {
	tabardToFactionId = {},
	lastScan = 0,
	pendingTabard = nil,
	factionRep = {},
}

local function updateReputationCache()
	if not (DATA and DATA.reputationXRef) then return end
	for factionId, base in pairs(DATA.reputationXRef) do
		local data = getFactionDataByID(factionId)
		if data then
			local barMin = tonumber(data.currentReactionThreshold) or 0
			local barMax = tonumber(data.nextReactionThreshold) or barMin
			local barVal = tonumber(getTotalRepFromFactionData(data) or 0) or 0
			local standingId = getStandingIdFromFactionData(data)

			local rep = STATE.factionRep[factionId] or {}
			rep.tabard = base.tabard
			rep.group = base.group
			rep.name = data.name or rep.name
			rep.repRank = standingId
			rep.accrued = barVal
			rep.levelMin = barMin
			rep.levelMax = barMax
			rep.repCurrent = tonumber(data.currentStanding) or (barVal - barMin)
			rep.repMax = barMax - barMin
			STATE.factionRep[factionId] = rep
		end
	end
end

local function scanBagsForTabards()
	wipe(STATE.tabardToFactionId)
	local db = getDB()
	if not db then return end

	local factionNameToId, factionNames = buildFactionNameToIDMap()
	local tt = getScanTooltip()

	for bag = 0, 4 do
		local slots = C_Container.GetContainerNumSlots(bag)
		for slot = 1, slots do
			local itemID = C_Container.GetContainerItemID(bag, slot)
			if itemID and isTabardItem(itemID) then
				local factionId = (DATA and DATA.tabardXRef and DATA.tabardXRef[tostring(itemID)]) or db.tabardMap[tostring(itemID)]
				if not factionId then
					tt:ClearLines()
					tt:SetBagItem(bag, slot)
					factionId = extractFactionIdFromTooltip(tt, factionNameToId, factionNames)
					if factionId then
						db.tabardMap[tostring(itemID)] = factionId
					end
				end
				if factionId then
					STATE.tabardToFactionId[itemID] = factionId
				end
			end
		end
	end

	STATE.lastScan = GetTime()
end

local function ensureScanned()
	if not STATE.lastScan or (GetTime() - STATE.lastScan) > 2 then
		scanBagsForTabards()
	end
end

local function getCurrentTabardItemID()
	local loc = ItemLocation and ItemLocation.CreateFromEquipmentSlot and ItemLocation:CreateFromEquipmentSlot(19)
	if loc and C_Item and C_Item.GetItemID and C_Item.DoesItemExist and C_Item.DoesItemExist(loc) then
		return C_Item.GetItemID(loc)
	end
	return GetInventoryItemID and GetInventoryItemID("player", 19) or nil
end

local function setWatchedFactionById(factionId)
	if not factionId then return end
	if C_Reputation and C_Reputation.SetWatchedFactionByID then
		C_Reputation.SetWatchedFactionByID(factionId)
		return
	end
	-- Fallback to legacy index based API.
	if SetWatchedFactionIndex and GetNumFactions and GetFactionInfo then
		local expandList = {}
		local factionCount = GetNumFactions()
		local factionIndex = 1
		while factionIndex < factionCount do
			local _, _, _, _, _, _, _, _, _, isCollapsed, _, _, _, fId = GetFactionInfo(factionIndex)
			if fId and fId == factionId then
				SetWatchedFactionIndex(factionIndex)
				break
			elseif isCollapsed then
				if ExpandFactionHeader then ExpandFactionHeader(factionIndex) end
				expandList[#expandList + 1] = factionIndex
				factionCount = GetNumFactions()
			end
			factionIndex = factionIndex + 1
		end
		for i = #expandList, 1, -1 do
			if CollapseFactionHeader then CollapseFactionHeader(expandList[i]) end
		end
	end
end

local function onUpdateFaction()
	if not IsEnabled() then return end
	ensureScanned()
	updateReputationCache()
	local itemID = getCurrentTabardItemID()
	local factionId = itemID and STATE.tabardToFactionId[itemID]
	if factionId then
		setWatchedFactionById(factionId)
		return
	end

	-- If not championing, still show raid rep bars based on mapping.
	local inInstance = IsInInstance()
	if inInstance and DATA and DATA.raidFaction then
		local _, instanceType, _, _, _, _, _, instanceMapID = GetInstanceInfo()
		if instanceType == "raid" and instanceMapID then
			local factionStr = DATA.raidFaction[instanceMapID]
			if factionStr then
				local first = tostring(factionStr):match("%d+")
				if first then
					setWatchedFactionById(tonumber(first))
					return
				end
			end
		end
	end

	local db = getDB()
	if db and db.hideRepBarWhenNoChampion and SetWatchedFactionIndex then
		SetWatchedFactionIndex(0)
	end
end

local function getContext()
	local inInstance, instanceType = IsInInstance()
	if inInstance then
		if instanceType == "party" or instanceType == "scenario" then return "dungeon" end
		if instanceType == "raid" then return "raid" end
		if instanceType == "pvp" or instanceType == "arena" then return "pvp" end
		return "dungeon"
	end

	if DATA and DATA.maps then
		local uiMapID = getPlayerUiMapID()
		if uiMapID then
			local maps = DATA.maps
			if isIdInMapList(uiMapID, maps.allianceCities) or isIdInMapList(uiMapID, maps.hordeCities) or isIdInMapList(uiMapID, maps.neutralCities) then
				return "city"
			end
			if isIdInMapList(uiMapID, maps.PvPZone) or isIdInMapList(uiMapID, maps.Battlegrounds) then
				return "pvp"
			end
		end
	end

	local pvpType = GetZonePVPInfo()
	if pvpType == "sanctuary" or pvpType == "friendly" then return "city" end
	if pvpType == "hostile" then return "pvp" end
	return "solo"
end

local function removeTabard()
	if InCombatLockdown() then return false end
	if CursorHasItem() then return false end
	PickupInventoryItem(19)
	if CursorHasItem() then
		PutItemInBackpack()
		ClearCursor()
		return true
	end
	return false
end

local function equipTabard(itemID)
	if not itemID then return false end
	if InCombatLockdown() then return false end
	if CursorHasItem() then return false end
	EquipItemByName(itemID)
	return true
end

local function chooseTabardForMode(mode)
	ensureScanned()
	updateReputationCache()

	local function pickClosestFromGroup(groupKey)
		local bestItemID
		local bestValue = 0
		for itemID, fId in pairs(STATE.tabardToFactionId) do
			if groupKey == "all" or isInTabardGroup(itemID, groupKey) then
				local rep = STATE.factionRep[fId]
				local currentValue = rep and rep.repCurrent
				if currentValue and currentValue < EXALTED_MIN and currentValue > bestValue then
					bestValue = currentValue
					bestItemID = itemID
				end
			end
		end
		return bestItemID
	end

	local function pickFurthestFromGroup(groupKey, which)
		local bestItemID
		local bestValue = EXALTED_MIN
		if which == "lowest" then bestValue = EXALTED_MAX end
		for itemID, fId in pairs(STATE.tabardToFactionId) do
			if groupKey == "all" or isInTabardGroup(itemID, groupKey) then
				local rep = STATE.factionRep[fId]
				local currentValue = rep and rep.repCurrent
				if currentValue and currentValue < bestValue then
					bestValue = currentValue
					bestItemID = itemID
				end
			end
		end
		return bestItemID
	end

	local function pickRandomFromGroup(groupKey)
		local pool = {}
		for itemID in pairs(STATE.tabardToFactionId) do
			if groupKey == "all" or isInTabardGroup(itemID, groupKey) then
				pool[#pool + 1] = itemID
			end
		end
		if #pool > 0 then return pool[math.random(#pool)] end
		return nil
	end

	local dungeonGroup, dungeonTier = getCurrentDungeonTierGroup()
	local dungeonGroupForPick = dungeonGroup
	if dungeonTier == "D90" or dungeonTier == "H90" then dungeonGroupForPick = "D85tabards" end

	if mode == "closest" then
		if dungeonGroupForPick then
			local t = pickClosestFromGroup(dungeonGroupForPick)
			if t then return t end
		end
		return pickClosestFromGroup("cities") or pickClosestFromGroup("all")
	end
	if mode == "furthest" then
		if dungeonGroupForPick then
			local t = pickFurthestFromGroup(dungeonGroupForPick, "furthest")
			if t then return t end
		end
		return pickFurthestFromGroup("cities", "furthest") or pickFurthestFromGroup("all", "furthest")
	end
	if mode == "lowest" then
		if dungeonGroupForPick then
			local t = pickFurthestFromGroup(dungeonGroupForPick, "lowest")
			if t then return t end
		end
		return pickFurthestFromGroup("cities", "lowest") or pickFurthestFromGroup("all", "lowest")
	end
	if mode == "random" then
		if dungeonTier == "D90" or dungeonTier == "H90" then
			local t = pickRandomFromGroup("D85tabards")
			if t then return t end
		elseif dungeonGroup then
			local t = pickRandomFromGroup(dungeonGroup)
			if t then return t end
		end
		return pickRandomFromGroup("cities") or pickRandomFromGroup("all")
	end
	if mode == "faction" then
		local best = pickClosestFromGroup("cities")
		if best then return best end
		local pool = {}
		for itemID in pairs(STATE.tabardToFactionId) do
			if not isInTabardGroup(itemID, "D80tabards") and not isInTabardGroup(itemID, "D85tabards") then
				pool[#pool + 1] = itemID
			end
		end
		if #pool > 0 then return pool[math.random(#pool)] end
		return nil
	end
	if mode == "auto" then
		if dungeonTier == "D80" or dungeonTier == "H80" then
			local t = chooseTabardForMode("faction")
			if t then return t end
		end
		if dungeonTier == "D90" or dungeonTier == "H90" then
			local t = pickClosestFromGroup("D85tabards")
			if t then return t end
		end
		if dungeonGroup then
			local t = pickClosestFromGroup(dungeonGroup)
			if t then return t end
		end
		return chooseTabardForMode("closest")
	end
	if mode == "none" then
		return nil
	end
	return nil
end

local function maybeSwapTabard(reason)
	if not IsEnabled() then return end
	local db = getDB()
	if not db then return end
	if InCombatLockdown() then return end
	if C_Loot and C_Loot.IsLootOpen and C_Loot.IsLootOpen() then return end

	local context = getContext()
	local mode = db.modeByContext[context] or "nochange"
	if mode == "nochange" then return end

	ensureScanned()
	local desired
	if mode == "none" then
		desired = nil
	else
		desired = chooseTabardForMode(mode)
	end

	local current = getCurrentTabardItemID()
	if desired == current then
		return
	end

	if not desired then
		removeTabard()
		C_Timer.After(0, onUpdateFaction)
		return
	end

	local ok = equipTabard(desired)
	if not ok then
		STATE.pendingTabard = desired
		return
	end
	C_Timer.After(0, onUpdateFaction)
end

function Tabard.MaybeSwap(reason)
	maybeSwapTabard(reason)
end

function Tabard.Debug()
	local uiMapID = getPlayerUiMapID()
	local instanceMapID = getInstanceMapID()
	local instanceName, instanceType, difficultyID, difficultyName = GetInstanceInfo()
	local ctx = getContext()
	local tierGroup, tier = getCurrentDungeonTierGroup()
	print(PREFIX .. "debug")
	print(PREFIX .. " uiMapID: " .. tostring(uiMapID) .. " instanceMapID: " .. tostring(instanceMapID))
	print(PREFIX .. " instance: " .. tostring(instanceName) .. " type: " .. tostring(instanceType) .. " difficulty: " .. tostring(difficultyID) .. " " .. tostring(difficultyName))
	print(PREFIX .. " context: " .. tostring(ctx) .. " mode: " .. tostring(getDB() and getDB().modeByContext[ctx]))
	print(PREFIX .. " tier: " .. tostring(tier) .. " tierGroup: " .. tostring(tierGroup))
	print(PREFIX .. " dataLoaded: " .. tostring(DATA ~= nil))
end

function Tabard.OnSettingsChanged(_)
	if not Tabard._initialized then return end
	if IsEnabled() then
		ensureScanned()
		C_Timer.After(getDB().delay or 0, function() maybeSwapTabard("settings") end)
		C_Timer.After(0, onUpdateFaction)
	end
end

local FRAME = CreateFrame("Frame")
FRAME:RegisterEvent("PLAYER_ENTERING_WORLD")
FRAME:RegisterEvent("ZONE_CHANGED_NEW_AREA")
FRAME:RegisterEvent("BAG_UPDATE_DELAYED")
FRAME:RegisterEvent("UPDATE_FACTION")
FRAME:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
FRAME:RegisterEvent("PLAYER_REGEN_ENABLED")
FRAME:SetScript("OnEvent", function(_, event)
	if not Tabard._initialized then return end
	if event == "PLAYER_ENTERING_WORLD" then
		ensureScanned()
		C_Timer.After(getDB().delay or 0, function() maybeSwapTabard("enter") end)
		C_Timer.After(0, onUpdateFaction)
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		C_Timer.After(getDB().delay or 0, function() maybeSwapTabard("zone") end)
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		C_Timer.After(0, onUpdateFaction)
	elseif event == "BAG_UPDATE_DELAYED" then
		scanBagsForTabards()
		C_Timer.After(getDB().delay or 0, function() maybeSwapTabard("bags") end)
	elseif event == "UPDATE_FACTION" then
		onUpdateFaction()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if STATE.pendingTabard then
			local pending = STATE.pendingTabard
			STATE.pendingTabard = nil
			equipTabard(pending)
			C_Timer.After(0, onUpdateFaction)
		end
	end
end)

-- Optional: keep the old slash commands for convenience.
local function HandleSlash(msg)
	msg = tostring(msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "debug" then
		Tabard.Debug()
		return
	end
	if msg == "swap" then
		Tabard.MaybeSwap("cmd")
		return
	end
	print(PREFIX .. "commands: /ftm swap | /ftm debug")
end

SLASH_FR0Z3NUILOOTITTABARD1 = "/ftm"
SlashCmdList["FR0Z3NUILOOTITTABARD"] = HandleSlash
