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
	-- Prefer instant info so we don't depend on item cache.
	if GetItemInfoInstant then
		local _, _, _, itemEquipLoc = GetItemInfoInstant(itemID)
		if itemEquipLoc == "INVTYPE_TABARD" then
			return true
		end
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
	pendingSwap = false,
	pendingSwapReason = nil,
	lastWatchedFactionId = nil,
	suppressNextUpdateFaction = false,
	lastClearWatchedAt = 0,
	factionRep = {},
	wasInInstance = nil,
	lastEquippedFactionId = nil,
	equippedFactionWasExalted = nil,
}

local function getInstanceContext()
	local inInstance, instanceType = IsInInstance()
	if not inInstance then return nil end
	if instanceType == "party" or instanceType == "scenario" then return "dungeon" end
	if instanceType == "raid" then return "raid" end
	if instanceType == "pvp" or instanceType == "arena" then return "pvp" end
	return "dungeon"
end

local function isFactionExalted(factionId)
	factionId = tonumber(factionId)
	if not factionId then return false end
	local rep = STATE.factionRep and STATE.factionRep[factionId]
	local accrued = rep and rep.accrued
	if type(accrued) ~= "number" then
		local data = getFactionDataByID(factionId)
		accrued = data and getTotalRepFromFactionData(data) or nil
	end
	return (type(accrued) == "number" and accrued >= EXALTED_MIN) and true or false
end

local function getWatchedFactionId()
	if C_Reputation and C_Reputation.GetWatchedFactionData then
		local ok, data = pcall(C_Reputation.GetWatchedFactionData)
		if ok and type(data) == "table" then
			return tonumber(data.factionID) or nil
		end
	end
	return nil
end

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
	factionId = tonumber(factionId)
	if not factionId then return end

	-- Guard: setting watched faction can fire UPDATE_FACTION; avoid loops.
	local current = getWatchedFactionId()
	if current and current == factionId then
		STATE.lastWatchedFactionId = factionId
		return
	end
	if STATE.lastWatchedFactionId and STATE.lastWatchedFactionId == factionId then
		return
	end
	STATE.lastWatchedFactionId = factionId

	if C_Reputation and C_Reputation.SetWatchedFactionByID then
		STATE.suppressNextUpdateFaction = true
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
		-- Avoid hammering the API (can also generate UPDATE_FACTION loops).
		local watched = getWatchedFactionId()
		if watched ~= nil then
			local now = (GetTime and GetTime()) or 0
			if now == 0 or (now - (STATE.lastClearWatchedAt or 0)) > 1.0 then
				STATE.lastClearWatchedAt = now
				STATE.lastWatchedFactionId = nil
				STATE.suppressNextUpdateFaction = true
				SetWatchedFactionIndex(0)
			end
		end
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

	local currentTabard = getCurrentTabardItemID()

	local function getAccruedRep(factionId)
		if not factionId then return nil end
		local cached = STATE.factionRep and STATE.factionRep[factionId]
		if cached and type(cached.accrued) == "number" then
			return cached.accrued
		end
		local data = getFactionDataByID(factionId)
		if not data then return nil end
		local total = getTotalRepFromFactionData(data)
		if type(total) ~= "number" then return nil end
		STATE.factionRep[factionId] = STATE.factionRep[factionId] or {}
		STATE.factionRep[factionId].accrued = total
		return total
	end

	local function pickClosestFromGroup(groupKey)
		local bestItemID
		local bestValue = -1
		for itemID, fId in pairs(STATE.tabardToFactionId) do
			if groupKey == "all" or isInTabardGroup(itemID, groupKey) then
				local currentValue = getAccruedRep(fId)
				if currentValue and currentValue < EXALTED_MIN then
					if currentValue > bestValue then
						bestValue = currentValue
						bestItemID = itemID
					elseif currentValue == bestValue and bestItemID ~= nil then
						-- Tie-breakers: prefer keeping current tabard, then lowest itemID.
						if itemID == currentTabard then
							bestItemID = itemID
						elseif bestItemID ~= currentTabard and itemID < bestItemID then
							bestItemID = itemID
						end
					elseif currentValue == bestValue and bestItemID == nil then
						bestItemID = itemID
					end
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
				local currentValue = getAccruedRep(fId)
				if currentValue then
					if currentValue < bestValue then
						bestValue = currentValue
						bestItemID = itemID
					elseif currentValue == bestValue and bestItemID ~= nil then
						-- Tie-breakers: prefer keeping current tabard, then lowest itemID.
						if itemID == currentTabard then
							bestItemID = itemID
						elseif bestItemID ~= currentTabard and itemID < bestItemID then
							bestItemID = itemID
						end
					elseif currentValue == bestValue and bestItemID == nil then
						bestItemID = itemID
					end
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
	-- Requested behavior: only swap automatically when entering an instance (or when becoming Exalted inside one).
	local context = getInstanceContext()
	if not context then return end
	if InCombatLockdown() then
		STATE.pendingSwap = true
		STATE.pendingSwapReason = tostring(reason or "")
		return
	end
	if C_Loot and C_Loot.IsLootOpen and C_Loot.IsLootOpen() then return end

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
	ensureScanned()
	updateReputationCache()

	local uiMapID = getPlayerUiMapID()
	local instanceMapID = getInstanceMapID()
	local instanceName, instanceType, difficultyID, difficultyName = GetInstanceInfo()
	local ctx = getContext()
	local instCtx = getInstanceContext()
	local tierGroup, tier = getCurrentDungeonTierGroup()
	local db = getDB()
	local mode = (db and db.modeByContext and ((instCtx and db.modeByContext[instCtx]) or db.modeByContext[ctx])) or nil
	local tabardCount = 0
	for _ in pairs(STATE.tabardToFactionId) do tabardCount = tabardCount + 1 end
	local current = getCurrentTabardItemID()
	local desired = (mode and mode ~= "nochange" and mode ~= "none") and chooseTabardForMode(mode) or nil
	print(PREFIX .. "debug")
	print(PREFIX .. " autoSwap: instance-enter, plus exalted-in-instance")
	print(PREFIX .. " uiMapID: " .. tostring(uiMapID) .. " instanceMapID: " .. tostring(instanceMapID))
	print(PREFIX .. " instance: " .. tostring(instanceName) .. " type: " .. tostring(instanceType) .. " difficulty: " .. tostring(difficultyID) .. " " .. tostring(difficultyName))
	print(PREFIX .. " context: " .. tostring(ctx) .. " instanceContext: " .. tostring(instCtx) .. " mode: " .. tostring(mode))
	print(PREFIX .. " tier: " .. tostring(tier) .. " tierGroup: " .. tostring(tierGroup))
	print(PREFIX .. " tabardsInBags: " .. tostring(tabardCount) .. " current: " .. tostring(current) .. " desired: " .. tostring(desired))
	print(PREFIX .. " pendingTabard: " .. tostring(STATE.pendingTabard) .. " pendingSwap: " .. tostring(STATE.pendingSwap))
	print(PREFIX .. " dataLoaded: " .. tostring(DATA ~= nil))
end

function Tabard.OnSettingsChanged(_)
	if not Tabard._initialized then return end
	if not IsEnabled() then return end
	ensureScanned()
	C_Timer.After(0, onUpdateFaction)
end

local function updateInstanceTransition(reason)
	local inInstance = select(1, IsInInstance()) and true or false
	local was = STATE.wasInInstance
	STATE.wasInInstance = inInstance

	if was == nil then
		-- First run (login/reload): treat "already inside" as an enter.
		if inInstance then
			local db = getDB()
			C_Timer.After((db and db.delay) or 0, function() maybeSwapTabard(reason or "enter") end)
		end
		return
	end

	if (not was) and inInstance then
		local db = getDB()
		C_Timer.After((db and db.delay) or 0, function() maybeSwapTabard(reason or "enter") end)
		return
	end

	if was and (not inInstance) then
		-- Reset exalt tracking when leaving instances.
		STATE.lastEquippedFactionId = nil
		STATE.equippedFactionWasExalted = nil
		STATE.pendingSwapReason = nil
	end
end

local function maybeSwapIfEquippedTabardJustHitExalted(reason)
	if not IsEnabled() then return end
	if not getInstanceContext() then
		STATE.lastEquippedFactionId = nil
		STATE.equippedFactionWasExalted = nil
		return
	end

	ensureScanned()
	updateReputationCache()

	local itemID = getCurrentTabardItemID()
	local factionId = itemID and STATE.tabardToFactionId[itemID]
	if not factionId then
		STATE.lastEquippedFactionId = nil
		STATE.equippedFactionWasExalted = nil
		return
	end

	local exalted = isFactionExalted(factionId)
	if STATE.lastEquippedFactionId ~= factionId then
		STATE.lastEquippedFactionId = factionId
		STATE.equippedFactionWasExalted = exalted
		return
	end

	if exalted and not STATE.equippedFactionWasExalted then
		STATE.equippedFactionWasExalted = true
		if InCombatLockdown() then
			STATE.pendingSwap = true
			STATE.pendingSwapReason = tostring(reason or "exalted")
			return
		end
		local db = getDB()
		C_Timer.After((db and db.delay) or 0, function() maybeSwapTabard(reason or "exalted") end)
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
		updateInstanceTransition("enter")
		C_Timer.After(0, onUpdateFaction)
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		updateInstanceTransition("zone")
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		C_Timer.After(0, onUpdateFaction)
		C_Timer.After(0, function() maybeSwapIfEquippedTabardJustHitExalted("equip") end)
	elseif event == "BAG_UPDATE_DELAYED" then
		scanBagsForTabards()
		-- No auto-swap from bag changes; only instance enter or Exalted transition.
	elseif event == "UPDATE_FACTION" then
		if STATE.suppressNextUpdateFaction then
			STATE.suppressNextUpdateFaction = false
			return
		end
		onUpdateFaction()
		maybeSwapIfEquippedTabardJustHitExalted("exalted")
	elseif event == "PLAYER_REGEN_ENABLED" then
		if STATE.pendingSwap then
			STATE.pendingSwap = false
			C_Timer.After(0, function() maybeSwapTabard(STATE.pendingSwapReason or "regen") end)
			return
		end
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
	print(PREFIX .. "Deprecated: use /fli tabard swap|debug")
	if msg == "debug" then
		Tabard.Debug()
		return
	end
	if msg == "swap" then
		Tabard.MaybeSwap("cmd")
		return
	end
	print(PREFIX .. "commands: /fli tabard swap | /fli tabard debug")
end

SLASH_FR0Z3NUILOOTITTABARD1 = "/ftm"
SlashCmdList["FR0Z3NUILOOTITTABARD"] = HandleSlash

-- ============================================================================
-- UI (merged from fr0z3nUI_LootItTabardUI.lua)
-- ============================================================================

function Tabard.BuildTab(tabardPanel, env)
	if not tabardPanel then return end

	local EnsureDB = env and env.EnsureDB
	local GetDB = env and env.GetDB
	local GetCharDB = env and env.GetCharDB
	local Clamp = env and env.Clamp
	local SetCheckBoxText = env and env.SetCheckBoxText

	if type(EnsureDB) ~= "function" then EnsureDB = function(...) end end
	if type(GetDB) ~= "function" then GetDB = function(...) return nil end end
	if type(GetCharDB) ~= "function" then GetCharDB = function(...) return nil end end
	if type(Clamp) ~= "function" then
		Clamp = function(v, minV, maxV)
			v = tonumber(v) or 0
			minV = tonumber(minV)
			maxV = tonumber(maxV)
			if minV and v < minV then v = minV end
			if maxV and v > maxV then v = maxV end
			return v
		end
	end
	if type(SetCheckBoxText) ~= "function" then SetCheckBoxText = function(...) end end

	local tabardTitle = tabardPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	tabardTitle:SetPoint("TOPLEFT", tabardPanel, "TOPLEFT", 10, -10)
	tabardTitle:SetText("")
	if tabardTitle.Hide then tabardTitle:Hide() end

	local function GetTabardEnableMode()
		local mod = _G and rawget(_G, "fr0z3nUI_LootItTabard")
		if mod and mod.GetEnableMode then
			return mod.GetEnableMode()
		end
		EnsureDB()
		local DB = GetDB()
		local CHARDB = GetCharDB()
		if CHARDB and CHARDB.tabardEnabledOverride == true then return "on" end
		if CHARDB and CHARDB.tabardEnabledOverride == false then return "off" end
		if DB and DB.tabard and DB.tabard.enabled then return "acc" end
		return "off"
	end

	local function SetTabardEnableMode(mode)
		local mod = _G and rawget(_G, "fr0z3nUI_LootItTabard")
		if mod and mod.SetEnableMode then
			mod.SetEnableMode(mode)
			return
		end
		EnsureDB()
		local DB = GetDB()
		local CHARDB = GetCharDB()
		if not (DB and CHARDB) then return end

		DB.tabard = (type(DB.tabard) == "table") and DB.tabard or {}
		mode = tostring(mode or ""):lower()
		if mode == "on" then
			CHARDB.tabardEnabledOverride = true
		elseif mode == "acc" then
			CHARDB.tabardEnabledOverride = nil
			DB.tabard.enabled = true
		else
			CHARDB.tabardEnabledOverride = false
		end
	end

	local tabardEnableLabel = tabardPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	tabardEnableLabel:SetPoint("TOPLEFT", tabardPanel, "TOPLEFT", 10, -10)
	tabardEnableLabel:SetText("")
	if tabardEnableLabel.Hide then tabardEnableLabel:Hide() end

	local tabardEnableModeBtn = CreateFrame("Button", nil, tabardPanel, "UIPanelButtonTemplate")
	tabardEnableModeBtn:SetSize(90, 20)
	tabardEnableModeBtn:SetPoint("TOPLEFT", tabardPanel, "TOPLEFT", 10, -10)

	local function RefreshTabardEnableModeButton()
		if not (tabardEnableModeBtn and tabardEnableModeBtn.SetText) then return end
		local m = GetTabardEnableMode()
		tabardEnableModeBtn:SetText((m == "on") and "On" or ((m == "acc") and "On Acc" or "Off"))
	end

	tabardEnableModeBtn:SetScript("OnClick", function()
		local cur = GetTabardEnableMode()
		local nextMode = (cur == "off") and "on" or ((cur == "on") and "acc" or "off")
		SetTabardEnableMode(nextMode)
		RefreshTabardEnableModeButton()
	end)

	tabardEnableModeBtn:SetScript("OnEnter", function(self)
		if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
		local m = GetTabardEnableMode()
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Enable")
		GameTooltip:AddLine("Cycles: On / On Acc / Off", 0.85, 0.85, 0.85, true)
		GameTooltip:AddLine("Current: " .. ((m == "on") and "On" or ((m == "acc") and "On Acc" or "Off")), 0.85, 0.85, 0.85, true)
		GameTooltip:Show()
	end)
	tabardEnableModeBtn:SetScript("OnLeave", function()
		if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
	end)

	local function TabardMod()
		return _G and rawget(_G, "fr0z3nUI_LootItTabard")
	end

	local function EnsureTabardDB()
		EnsureDB()
		local DB = GetDB()
		if not DB then return {} end

		DB.tabard = (type(DB.tabard) == "table") and DB.tabard or {}
		DB.tabard.modeByContext = (type(DB.tabard.modeByContext) == "table") and DB.tabard.modeByContext or {
			solo = "nochange",
			city = "closest",
			dungeon = "closest",
			raid = "nochange",
			pvp = "nochange",
		}
		if DB.tabard.delay == nil then DB.tabard.delay = 0.75 end
		if DB.tabard.hideRepBarWhenNoChampion == nil then DB.tabard.hideRepBarWhenNoChampion = false end
		return DB.tabard
	end

	local function NotifyTabardSettingsChanged(reason)
		local mod = TabardMod()
		if mod and mod.OnSettingsChanged then
			mod.OnSettingsChanged(reason or "ui")
		end
	end

	-- Context mode controls
	local tabardModeTitle = tabardPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	tabardModeTitle:SetPoint("TOPLEFT", tabardEnableModeBtn, "BOTTOMLEFT", 0, -18)
	tabardModeTitle:SetText("Context modes")

	local MODE_LABELS = {
		nochange = "No change",
		closest = "Closest to Exalted",
		furthest = "Furthest from Exalted",
		lowest = "Lowest rep",
		random = "Random",
		faction = "Faction (cities)",
		auto = "Auto",
		none = "Unequip",
	}

	local MODE_ORDER = { "nochange", "closest", "furthest", "lowest", "random", "auto", "faction", "none" }

	local function CreateModeDropDown(name, anchor, yOffset)
		local label = tabardPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
		label:SetText(name)

		local dd = CreateFrame("Frame", nil, tabardPanel, "UIDropDownMenuTemplate")
		dd:SetPoint("LEFT", label, "RIGHT", -6, -2)
		UIDropDownMenu_SetWidth(dd, 170)
		return label, dd
	end

	local soloLabel, soloDD = CreateModeDropDown("Solo", tabardModeTitle, -8)
	local cityLabel, cityDD = CreateModeDropDown("City", soloLabel, -8)
	local dungeonLabel, dungeonDD = CreateModeDropDown("Dungeon", cityLabel, -8)
	local raidLabel, raidDD = CreateModeDropDown("Raid", dungeonLabel, -8)
	local pvpLabel, pvpDD = CreateModeDropDown("PvP", raidLabel, -8)

	local function SetModeFor(ctx, mode)
		local tdb = EnsureTabardDB()
		tdb.modeByContext[ctx] = tostring(mode or "nochange")
		NotifyTabardSettingsChanged("mode")
	end

	local function GetModeFor(ctx)
		local tdb = EnsureTabardDB()
		return tostring((tdb.modeByContext and tdb.modeByContext[ctx]) or "nochange")
	end

	local function InitModeDropDown(dd, ctx)
		UIDropDownMenu_Initialize(dd, function(_, level)
			if level ~= 1 then return end
			local current = GetModeFor(ctx)
			for _, key in ipairs(MODE_ORDER) do
				local info = UIDropDownMenu_CreateInfo()
				info.text = MODE_LABELS[key] or key
				info.value = key
				info.checked = (key == current)
				info.func = function()
					UIDropDownMenu_SetText(dd, MODE_LABELS[key] or key)
					SetModeFor(ctx, key)
				end
				UIDropDownMenu_AddButton(info, level)
			end
		end)
	end

	InitModeDropDown(soloDD, "solo")
	InitModeDropDown(cityDD, "city")
	InitModeDropDown(dungeonDD, "dungeon")
	InitModeDropDown(raidDD, "raid")
	InitModeDropDown(pvpDD, "pvp")

	-- Delay + misc
	local delayLabel = tabardPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	delayLabel:SetPoint("TOPLEFT", pvpLabel, "BOTTOMLEFT", 0, -14)
	delayLabel:SetText("Delay")

	local delaySlider = CreateFrame("Slider", nil, tabardPanel, "OptionsSliderTemplate")
	delaySlider:SetPoint("LEFT", delayLabel, "RIGHT", 14, 0)
	delaySlider:SetWidth(180)
	delaySlider:SetMinMaxValues(0, 3.0)
	delaySlider:SetValueStep(0.05)
	delaySlider:SetObeyStepOnDrag(true)
	if delaySlider.Low then delaySlider.Low:SetText("0") end
	if delaySlider.High then delaySlider.High:SetText("3.0") end
	if delaySlider.Text then delaySlider.Text:SetText("") end

	local delayValue = tabardPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	delayValue:SetPoint("LEFT", delaySlider, "RIGHT", 10, 0)
	delayValue:SetText("0.75s")

	delaySlider:SetScript("OnValueChanged", function(self, value)
		local tdb = EnsureTabardDB()
		local v = Clamp(value or 0, 0, 3.0)
		tdb.delay = v
		delayValue:SetText(string.format("%.2fs", v))
		NotifyTabardSettingsChanged("delay")
	end)

	local repCB = CreateFrame("CheckButton", nil, tabardPanel, "UICheckButtonTemplate")
	repCB:SetPoint("TOPLEFT", delayLabel, "BOTTOMLEFT", 0, -10)
	SetCheckBoxText(repCB, "Hide rep bar when not championing")
	repCB:SetScript("OnClick", function(self)
		local tdb = EnsureTabardDB()
		tdb.hideRepBarWhenNoChampion = self:GetChecked() and true or false
		NotifyTabardSettingsChanged("repbar")
	end)

	local swapBtn = CreateFrame("Button", nil, tabardPanel, "UIPanelButtonTemplate")
	swapBtn:SetSize(90, 20)
	swapBtn:SetPoint("TOPLEFT", repCB, "BOTTOMLEFT", 0, -10)
	swapBtn:SetText("Swap Now")
	swapBtn:SetScript("OnClick", function()
		local mod = TabardMod()
		if mod and mod.MaybeSwap then mod.MaybeSwap("ui") end
	end)

	local dbgBtn = CreateFrame("Button", nil, tabardPanel, "UIPanelButtonTemplate")
	dbgBtn:SetSize(90, 20)
	dbgBtn:SetPoint("LEFT", swapBtn, "RIGHT", 10, 0)
	dbgBtn:SetText("Debug")
	dbgBtn:SetScript("OnClick", function()
		local mod = TabardMod()
		if mod and mod.Debug then mod.Debug() end
	end)

	local tip = tabardPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	tip:SetPoint("TOPLEFT", swapBtn, "BOTTOMLEFT", 0, -10)
	tip:SetJustifyH("LEFT")
	tip:SetText("Tip: If you don't want auto-equips in towns, set City to 'No change'.")

	local function RefreshTabardControls()
		RefreshTabardEnableModeButton()
		local tdb = EnsureTabardDB()
		UIDropDownMenu_SetText(soloDD, MODE_LABELS[GetModeFor("solo")] or GetModeFor("solo"))
		UIDropDownMenu_SetText(cityDD, MODE_LABELS[GetModeFor("city")] or GetModeFor("city"))
		UIDropDownMenu_SetText(dungeonDD, MODE_LABELS[GetModeFor("dungeon")] or GetModeFor("dungeon"))
		UIDropDownMenu_SetText(raidDD, MODE_LABELS[GetModeFor("raid")] or GetModeFor("raid"))
		UIDropDownMenu_SetText(pvpDD, MODE_LABELS[GetModeFor("pvp")] or GetModeFor("pvp"))
		local d = tonumber(tdb.delay) or 0.75
		delaySlider:SetValue(Clamp(d, 0, 3.0))
		delayValue:SetText(string.format("%.2fs", Clamp(d, 0, 3.0)))
		repCB:SetChecked(tdb.hideRepBarWhenNoChampion and true or false)
	end

	tabardPanel.Refresh = RefreshTabardControls

	tabardPanel:SetScript("OnShow", RefreshTabardEnableModeButton)
	tabardPanel:SetScript("OnShow", RefreshTabardControls)
end
