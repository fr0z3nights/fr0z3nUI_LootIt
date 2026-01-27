local ADDON = ...

local PREFIX = "|cff00ccff[LI]|r "

-- WoW globals (shadowed to locals so diagnostics stay clean)
local UISpecialFrames = _G and rawget(_G, "UISpecialFrames")
local NUM_CHAT_WINDOWS = _G and rawget(_G, "NUM_CHAT_WINDOWS")
local RAID_CLASS_COLORS = _G and rawget(_G, "RAID_CLASS_COLORS")

local ChatFrame_AddMessageEventFilter = _G and rawget(_G, "ChatFrame_AddMessageEventFilter")
local ChatFrame_RemoveMessageEventFilter = _G and rawget(_G, "ChatFrame_RemoveMessageEventFilter")

local UIDropDownMenu_Initialize = _G and rawget(_G, "UIDropDownMenu_Initialize")
local UIDropDownMenu_CreateInfo = _G and rawget(_G, "UIDropDownMenu_CreateInfo")
local UIDropDownMenu_AddButton = _G and rawget(_G, "UIDropDownMenu_AddButton")
local UIDropDownMenu_SetWidth = _G and rawget(_G, "UIDropDownMenu_SetWidth")
local UIDropDownMenu_SetText = _G and rawget(_G, "UIDropDownMenu_SetText")
local UIDropDownMenu_SetSelectedID = _G and rawget(_G, "UIDropDownMenu_SetSelectedID")
local ToggleDropDownMenu = _G and rawget(_G, "ToggleDropDownMenu")
local CloseDropDownMenus = _G and rawget(_G, "CloseDropDownMenus")

local Clamp = _G and rawget(_G, "Clamp")
if not Clamp then
  Clamp = function(v, mn, mx)
    v = tonumber(v)
    mn = tonumber(mn)
    mx = tonumber(mx)
    if not v then return mn end
    if mn and v < mn then return mn end
    if mx and v > mx then return mx end
    return v
  end
end

-- Built-in aliases shipped with the addon (account aliases override these).
-- Keyed by itemID; values are display-only text (link remains the original item).
local ADDON_LINK_ALIASES = (type(rawget(_G, "fr0z3nUI_LootIt_AddonAliases")) == "table") and rawget(_G, "fr0z3nUI_LootIt_AddonAliases") or {}
-- Built-in currency aliases shipped with the addon.
-- Keyed by currencyID; values are display-only text (link remains the original currency).
local ADDON_CURRENCY_ALIASES = (type(rawget(_G, "fr0z3nUI_LootIt_AddonCurrencyAliases")) == "table") and rawget(_G, "fr0z3nUI_LootIt_AddonCurrencyAliases") or {}

local DEFAULTS = {
  enabled = true,
  hideLootText = true, -- suppress the default "You receive loot:" chat line
  echoItem = true, -- re-print a simplified line with just the item link
  showItemLevel = true, -- append (ilvl N) for equippable items
  linkAliases = {}, -- [itemID] = "Short Name" (display only, keeps original link)
  linkAliasDisabledAddon = {}, -- [itemID] = true disables addon built-in alias
  linkAliasDisabledAccount = {}, -- [itemID] = true disables account alias
  currencyAliases = {}, -- [currencyID] = "Short Name" (display only, keeps original link)
  currencyAliasDisabledAddon = {}, -- [currencyID] = true disables addon built-in alias
  currencyAliasDisabledAccount = {}, -- [currencyID] = true disables account alias
  aliasInputMode = "item", -- item | currency
  echoPrefix = "", -- optional; leave blank for no prefix
  outputChatFrame = 1,
  showSelfNameAlways = true,
  lootCombineCount = 1, -- 1 = normal (one item per line); >1 buffers items briefly and prints as "A, B, C"
  lootCombineIncludeCurrency = false, -- when combining, include currency in the combined line
  lootCombineIncludeGold = false, -- when combining, include money (gold/silver/copper per toggles) in the combined line
  lootCombineIncludeMoneyCurrency = false, -- legacy (kept for migration)
  lootCombineMode = "loot", -- loot | timer
  mailNotify = {
    enabled = true,
    showInCombat = true,
    model = {
      kind = "npc", -- player | display | file
      id = 104230,
      rotation = 0.15,
      zoom = 0.9,
      anim = 0,
      animRandom = false,
      animRepeat = false,
      animRepeatSec = 10,
    },
    ui = {
      point = "TOPRIGHT",
      x = -260,
      y = -220,
      w = 200,
      h = 220,
    },
  },
  money = {
    gold = true,
    silver = false,
    copper = false,
  },
  ui = {
    point = "CENTER",
    x = 0,
    y = 0,
  },

  other = {
    outputChatFrame = 1,
    achievement = {
      enabled = true,
    },
  },
}

fr0z3nUI_LootItDB = fr0z3nUI_LootItDB or nil
fr0z3nUI_LootItCharDB = fr0z3nUI_LootItCharDB or nil
local DB
local CHARDB

local function IsEnabled()
  if CHARDB and CHARDB.enabledOverride ~= nil then
    return (CHARDB.enabledOverride == true)
  end
  return (DB and DB.enabled) and true or false
end

local function CopyDefaults(dst, src)
  if type(dst) ~= "table" then dst = {} end
  for k, v in pairs(src) do
    if dst[k] == nil then
      if type(v) == "table" then
        dst[k] = CopyDefaults({}, v)
      else
        dst[k] = v
      end
    elseif type(v) == "table" and type(dst[k]) == "table" then
      dst[k] = CopyDefaults(dst[k], v)
    end
  end
  return dst
end

local function EnsureDB()
  if type(fr0z3nUI_LootItDB) ~= "table" then fr0z3nUI_LootItDB = {} end
  if type(fr0z3nUI_LootItCharDB) ~= "table" then fr0z3nUI_LootItCharDB = {} end

  -- Migration: older versions used a single toggle for "include money+currency".
  local hadNewCurrency = (fr0z3nUI_LootItDB.lootCombineIncludeCurrency ~= nil)
  local hadNewGold = (fr0z3nUI_LootItDB.lootCombineIncludeGold ~= nil)

  DB = CopyDefaults(fr0z3nUI_LootItDB, DEFAULTS)
  CHARDB = fr0z3nUI_LootItCharDB
  if type(CHARDB.linkAliases) ~= "table" then CHARDB.linkAliases = {} end
  if type(CHARDB.linkAliasDisabledChar) ~= "table" then CHARDB.linkAliasDisabledChar = {} end

  if type(CHARDB.currencyAliases) ~= "table" then CHARDB.currencyAliases = {} end
  if type(CHARDB.currencyAliasDisabledChar) ~= "table" then CHARDB.currencyAliasDisabledChar = {} end

  if DB and type(DB.other) ~= "table" then
    DB.other = {}
  end
  if DB and DB.other and DB.other.outputChatFrame == nil then
    DB.other.outputChatFrame = DB.outputChatFrame or 1
  end

  if (not hadNewCurrency) and (not hadNewGold) and (fr0z3nUI_LootItDB.lootCombineIncludeMoneyCurrency == true) then
    fr0z3nUI_LootItDB.lootCombineIncludeCurrency = true
    fr0z3nUI_LootItDB.lootCombineIncludeGold = true
    DB.lootCombineIncludeCurrency = true
    DB.lootCombineIncludeGold = true
  end

  -- Migration: old versions used showSelfNameInGroup; new is showSelfNameAlways.
  if DB and DB.showSelfNameAlways == nil and fr0z3nUI_LootItDB.showSelfNameInGroup ~= nil then
    DB.showSelfNameAlways = (fr0z3nUI_LootItDB.showSelfNameInGroup == true)
    fr0z3nUI_LootItDB.showSelfNameAlways = DB.showSelfNameAlways
  end
end

local function IsItemLevelEnabled()
  if CHARDB and CHARDB.showItemLevel ~= nil then
    return (CHARDB.showItemLevel == true)
  end
  return (DB and DB.showItemLevel ~= false) and true or false
end

local function Print(msg)
  local frame
  if DB and type(DB.outputChatFrame) == "number" then
    frame = _G and _G["ChatFrame" .. DB.outputChatFrame]
  end
  if not (frame and frame.AddMessage) then
    frame = DEFAULT_CHAT_FRAME
  end
  if frame and frame.AddMessage then
    local text = tostring(msg or "")
    local prefix = (DB and DB.echoPrefix)
    if type(prefix) ~= "string" then
      prefix = ""
    end
    if prefix ~= "" then
      frame:AddMessage(prefix .. text)
    else
      frame:AddMessage(text)
    end
  end
end

local function PrintToChatFrame(msg, chatFrameID)
  local frame
  local n = tonumber(chatFrameID)
  if n and _G then
    frame = _G["ChatFrame" .. n]
  end
  if not (frame and frame.AddMessage) then
    frame = DEFAULT_CHAT_FRAME
  end
  if frame and frame.AddMessage then
    frame:AddMessage(tostring(msg or ""))
  end
end

local function SetCheckBoxText(cb, text)
  if not cb then return end
  local label = cb.Text or (cb.GetName and cb:GetName() and _G[cb:GetName() .. "Text"]) or cb.text
  if label and label.SetText then
    label:SetText(text)
  end
end

local function SetCheckBoxChecked(cb, checked)
  if cb and cb.SetChecked then
    cb:SetChecked(checked and true or false)
  end
end

local function EscapeLuaPattern(text)
  text = tostring(text or "")
  return (text:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1"))
end

local function GlobalStringToPattern(globalString)
  if type(globalString) ~= "string" or globalString == "" then return nil end

  -- Preserve tokens first, then escape everything, then restore tokens.
  local s = globalString
  s = s:gsub("%%s", "\0S\0")
  s = s:gsub("%%d", "\0D\0")

  s = EscapeLuaPattern(s)

  -- Use non-greedy captures; some loot strings contain multiple %s tokens.
  s = s:gsub("\0S\0", "(.-)")
  s = s:gsub("\0D\0", "(%d+)")

  return "^" .. s .. "$"
end

local LOOT_PATTERNS = nil
local LOOT_PREFIXES = nil
local LOOT_GROUP_PATTERNS = nil

local LOOT_PATTERN_KEYS
local LOOT_GROUP_PATTERN_KEYS

local function BuildLootPatterns()
  local patterns = {}
  local prefixes = {}
  local groupPatterns = {}

  local keys = {
    "LOOT_ITEM_SELF",
    "LOOT_ITEM_SELF_MULTIPLE",
    "LOOT_ITEM_PUSHED_SELF",
    "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
    "LOOT_ITEM_CREATED_SELF",
    "LOOT_ITEM_CREATED_SELF_MULTIPLE",
    "LOOT_ITEM_BONUS_ROLL_SELF",
    "LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE",
  }

  for _, k in ipairs(keys) do
    local gs = _G and rawget(_G, k)
    local pat = GlobalStringToPattern(gs)
    if pat then
      patterns[#patterns + 1] = pat
    end

    if type(gs) == "string" and gs ~= "" then
      -- Extract localized prefix up to the first %s or %d token, e.g. "You receive loot: "
      local prefix = gs:match("^(.-)%%[sd]")
      if prefix and prefix ~= "" then
        prefixes[#prefixes + 1] = prefix
      end
    end
  end

  for _, k in ipairs(LOOT_GROUP_PATTERN_KEYS) do
    local gs = _G and rawget(_G, k)
    local pat = GlobalStringToPattern(gs)
    if pat then
      groupPatterns[#groupPatterns + 1] = pat
    end
  end

  LOOT_PATTERNS = patterns
  LOOT_PREFIXES = prefixes
  LOOT_GROUP_PATTERNS = groupPatterns
end

LOOT_PATTERN_KEYS = {
  "LOOT_ITEM_SELF",
  "LOOT_ITEM_SELF_MULTIPLE",
  "LOOT_ITEM_PUSHED_SELF",
  "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
  "LOOT_ITEM_CREATED_SELF",
  "LOOT_ITEM_CREATED_SELF_MULTIPLE",
  "LOOT_ITEM_BONUS_ROLL_SELF",
  "LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE",
}

LOOT_GROUP_PATTERN_KEYS = {
  "LOOT_ITEM",
  "LOOT_ITEM_MULTIPLE",
  "LOOT_ITEM_PUSHED",
  "LOOT_ITEM_PUSHED_MULTIPLE",
  "LOOT_ITEM_CREATED",
  "LOOT_ITEM_CREATED_MULTIPLE",
  "LOOT_ITEM_BONUS_ROLL",
  "LOOT_ITEM_BONUS_ROLL_MULTIPLE",
}

local function StripRealmFromName(name)
  if type(name) ~= "string" then return name end
  return name:match("^([^%-]+)") or name
end

local function IsItemLink(text)
  return type(text) == "string" and text:find("|Hitem:", 1, true) ~= nil
end

local function ColorizeByClass(classFile, text)
  if type(text) ~= "string" then
    text = tostring(text or "")
  end
  if not classFile or classFile == "" then
    return text
  end

  if C_ClassColor and C_ClassColor.GetClassColor then
    local color = C_ClassColor.GetClassColor(classFile)
    if color and color.WrapTextInColorCode then
      return color:WrapTextInColorCode(text)
    end
  end

  local rc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if rc and rc.colorStr then
    return "|c" .. rc.colorStr .. text .. "|r"
  end

  return text
end

local function GetGroupUnitForShortName(shortName)
  if type(shortName) ~= "string" or shortName == "" then return nil end

  if IsInRaid and IsInRaid() then
    local count = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    for i = 1, count do
      local unit = "raid" .. i
      local unitName = UnitName and UnitName(unit)
      unitName = StripRealmFromName(unitName)
      if unitName == shortName then
        return unit
      end
    end
  elseif IsInGroup and IsInGroup() then
    local count = (GetNumSubgroupMembers and GetNumSubgroupMembers()) or 0
    for i = 1, count do
      local unit = "party" .. i
      local unitName = UnitName and UnitName(unit)
      unitName = StripRealmFromName(unitName)
      if unitName == shortName then
        return unit
      end
    end
  end

  return nil
end

local function GetClassColoredName(fullOrShortName)
  local shortName = StripRealmFromName(fullOrShortName)
  if not shortName or shortName == "" then
    return ""
  end

  local myName = StripRealmFromName((UnitName and UnitName("player")) or "")
  if myName ~= "" and shortName == myName then
    local classFile
    if UnitClass then
      _, classFile = UnitClass("player")
    end
    return ColorizeByClass(classFile, shortName)
  end

  local unit = GetGroupUnitForShortName(shortName)
  if unit then
    local classFile
    if UnitClass then
      _, classFile = UnitClass(unit)
    end
    return ColorizeByClass(classFile, shortName)
  end

  return shortName
end

local function IsInAnyGroup()
  -- Some edge cases can report "in group" while effectively solo.
  -- Require evidence of other members.
  if IsInRaid and IsInRaid() then
    local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    return (tonumber(n) or 0) > 1
  end
  if IsInGroup and IsInGroup() then
    local sub = (GetNumSubgroupMembers and GetNumSubgroupMembers())
    if (tonumber(sub) or 0) > 0 then
      return true
    end
    local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    return (tonumber(n) or 0) > 1
  end
  return false
end

local function ExtractLinkFallback(msg)
  if type(msg) ~= "string" then return nil end
  return msg:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
    or msg:match("(|Hitem:.-|h%[.-%]|h)")
end

local function NormalizeItemLink(link)
  if type(link) ~= "string" or link == "" then return link end
  if link:match("^|c%x%x%x%x%x%x%x%x|Hitem:") then
    return link
  end

  if link:match("|Hitem:") then
    if C_Item and C_Item.GetItemInfo then
      local _, itemLink = C_Item.GetItemInfo(link)
      if type(itemLink) == "string" and itemLink ~= "" then
        return itemLink
      end
    end
  end

  return link
end

local function StripDisplayedLinkBrackets(link)
  if type(link) ~= "string" or link == "" then return link end
  -- Convert |h[Name]|h -> |hName|h (still clickable, just no inner brackets)
  return link:gsub("|h%[([^%]]+)%]|h", "|h%1|h")
end

local function GetItemIDFromLink(link)
  if type(link) ~= "string" or link == "" then return nil end
  local id = link:match("|Hitem:(%d+)")
  if not id then return nil end
  return tonumber(id)
end

local function GetCurrencyIDFromLink(link)
  if type(link) ~= "string" or link == "" then return nil end
  local id = link:match("|Hcurrency:(%d+)")
  if not id then return nil end
  return tonumber(id)
end

local function ApplyItemLinkAlias(link)
  if type(link) ~= "string" or link == "" then return link end
  local id = GetItemIDFromLink(link)
  if not id then return link end

  local alias

  local charDisabled = (CHARDB and type(CHARDB.linkAliasDisabledChar) == "table" and CHARDB.linkAliasDisabledChar[id] == true)
  local acctDisabled = (DB and type(DB.linkAliasDisabledAccount) == "table" and DB.linkAliasDisabledAccount[id] == true)
  local addonDisabled = (DB and type(DB.linkAliasDisabledAddon) == "table" and DB.linkAliasDisabledAddon[id] == true)

  -- Per-character disable suppresses ALL alias sources for this item.
  if charDisabled then
    return link
  end

  if (not charDisabled) and CHARDB and type(CHARDB.linkAliases) == "table" then
    alias = CHARDB.linkAliases[id]
  end
  if (type(alias) ~= "string" or alias == "") and (not acctDisabled) and DB and type(DB.linkAliases) == "table" then
    alias = DB.linkAliases[id]
  end
  if (type(alias) ~= "string" or alias == "") and (not addonDisabled) then
    alias = ADDON_LINK_ALIASES[id]
  end
  if type(alias) ~= "string" or alias == "" then
    return link
  end

  -- Replace the displayed text, preserving the hyperlink.
  local out = link
  out = out:gsub("(|Hitem:[^|]+|h)%[([^%]]+)%](|h)", "%1" .. alias .. "%3", 1)
  out = out:gsub("(|Hitem:[^|]+|h)([^|]+)(|h)", "%1" .. alias .. "%3", 1)
  return out
end

local function ApplyCurrencyLinkAlias(link)
  if type(link) ~= "string" or link == "" then return link end
  local id = GetCurrencyIDFromLink(link)
  if not id then return link end

  local alias

  local charDisabled = (CHARDB and type(CHARDB.currencyAliasDisabledChar) == "table" and CHARDB.currencyAliasDisabledChar[id] == true)
  local acctDisabled = (DB and type(DB.currencyAliasDisabledAccount) == "table" and DB.currencyAliasDisabledAccount[id] == true)
  local addonDisabled = (DB and type(DB.currencyAliasDisabledAddon) == "table" and DB.currencyAliasDisabledAddon[id] == true)

  if charDisabled then
    return link
  end

  if (not charDisabled) and CHARDB and type(CHARDB.currencyAliases) == "table" then
    alias = CHARDB.currencyAliases[id]
  end
  if (type(alias) ~= "string" or alias == "") and (not acctDisabled) and DB and type(DB.currencyAliases) == "table" then
    alias = DB.currencyAliases[id]
  end
  if (type(alias) ~= "string" or alias == "") and (not addonDisabled) then
    alias = ADDON_CURRENCY_ALIASES[id]
  end
  if type(alias) ~= "string" or alias == "" then
    return link
  end

  local out = link
  out = out:gsub("(|Hcurrency:[^|]+|h)%[([^%]]+)%](|h)", "%1" .. alias .. "%3", 1)
  out = out:gsub("(|Hcurrency:[^|]+|h)([^|]+)(|h)", "%1" .. alias .. "%3", 1)
  return out
end

local function GetEquippableItemLevelSuffix(link)
  if type(link) ~= "string" or link == "" then return nil end

  local isEquippable
  if C_Item and C_Item.IsEquippableItem then
    isEquippable = C_Item.IsEquippableItem(link)
  end
  if not isEquippable then
    return nil
  end

  local equipLoc
  if C_Item and C_Item.GetItemInfoInstant then
    local _, _, _, e = C_Item.GetItemInfoInstant(link)
    equipLoc = e
  end
  if not equipLoc or equipLoc == "" then
    return nil
  end

  -- Fallback: parse the localized tooltip "Item Level" line.
  -- This can be more reliable than link-based APIs for some upgraded/scaled items.
  if _G and CreateFrame and UIParent then
    if not (_G and rawget(_G, "fr0z3nUI_LootItScanTooltip")) then
      local tt = CreateFrame("GameTooltip", "fr0z3nUI_LootItScanTooltip", UIParent, "GameTooltipTemplate")
      tt:SetOwner(UIParent, "ANCHOR_NONE")
      tt:Hide()
    end

    local tt = _G and rawget(_G, "fr0z3nUI_LootItScanTooltip")
    if tt and tt.SetOwner and tt.SetHyperlink and tt.NumLines then
      tt:ClearLines()
      tt:SetOwner(UIParent, "ANCHOR_NONE")
      tt:SetHyperlink(link)

      local pat = GlobalStringToPattern((_G and rawget(_G, "ITEM_LEVEL")) or "")
      local nLines = tt:NumLines() or 0
      for i = 2, nLines do
        local fs = _G["fr0z3nUI_LootItScanTooltipTextLeft" .. i]
        local text = fs and fs.GetText and fs:GetText()
        if type(text) == "string" and text ~= "" then
          local lvl
          if pat then
            lvl = tonumber((text:match(pat)))
          end
          if not lvl then
            lvl = tonumber(text:match("(%d+)$"))
          end
          if lvl and lvl > 0 then
            tt:Hide()
            return lvl
          end
        end
      end
      tt:Hide()
    end
  end

  return nil
end

local function ExtractCurrencyLinkFallback(msg)
  if type(msg) ~= "string" then return nil end
  return msg:match("(|c%x+|Hcurrency:.-|h%[.-%]|h|r)")
    or msg:match("(|Hcurrency:.-|h%[.-%]|h)")
end

local function ExtractAchievementLinkFallback(msg)
  if type(msg) ~= "string" then return nil end
  return msg:match("(|c%x+|Hachievement:.-|h%[.-%]|h|r)")
    or msg:match("(|Hachievement:.-|h%[.-%]|h)")
end

local function FormatSelfLine(text)
  -- Always show your name in groups; the toggle only affects solo output.
  if IsInAnyGroup() or (DB and DB.showSelfNameAlways) then
    local me = GetClassColoredName(UnitName and UnitName("player"))
    if me and me ~= "" then
      return string.format("%s: %s", me, text)
    end
  end
  return text
end

local LOOT_COMBINE_DELAY = 0.25
local lootCombineParts
local lootCombineGen = 0
local lootCombineLootOpen = false

local function LootCombineEnabled()
  local n = DB and tonumber(DB.lootCombineCount) or 1
  return (n and n > 1)
end

local function LootCombineMode()
  local mode = DB and tostring(DB.lootCombineMode or "loot") or "loot"
  mode = mode:lower()
  if mode ~= "loot" and mode ~= "timer" then
    mode = "loot"
  end
  return mode
end

local function LootCombineFlush()
  if not lootCombineParts or #lootCombineParts == 0 then return end
  local msg = table.concat(lootCombineParts, "|cff15AB0D,|r ")
  for i = #lootCombineParts, 1, -1 do
    lootCombineParts[i] = nil
  end
  Print(FormatSelfLine(msg))
end

local function LootCombineCancelTimers()
  lootCombineGen = (lootCombineGen or 0) + 1
end

local function LootCombineWindowStart()
  if not LootCombineEnabled() then return end
  if LootCombineMode() ~= "loot" then return end
  lootCombineLootOpen = true
  LootCombineCancelTimers()
end

local function LootCombineWindowEnd()
  if not lootCombineLootOpen then return end
  lootCombineLootOpen = false
  LootCombineCancelTimers()
  LootCombineFlush()
end

local function LootCombineAdd(part)
  if not LootCombineEnabled() then
    Print(FormatSelfLine(part))
    return
  end

  local maxN = tonumber(DB.lootCombineCount) or 1
  if maxN < 2 then
    Print(FormatSelfLine(part))
    return
  end
  if maxN > 25 then maxN = 25 end

  if not lootCombineParts then lootCombineParts = {} end
  lootCombineParts[#lootCombineParts + 1] = part

  if #lootCombineParts >= maxN then
    LootCombineFlush()
    return
  end

  local mode = LootCombineMode()
  if mode == "timer" then
    LootCombineCancelTimers()
    local gen = lootCombineGen
    if C_Timer and C_Timer.After then
      C_Timer.After(LOOT_COMBINE_DELAY, function()
        if gen ~= lootCombineGen then return end
        LootCombineFlush()
      end)
    end
  else
    -- Loot-window mode: hold until LOOT_CLOSED. If LOOT_CLOSED never arrives (edge cases),
    -- use a longer fallback flush when we aren't in an open loot window.
    if not lootCombineLootOpen then
      LootCombineCancelTimers()
      local gen = lootCombineGen
      if C_Timer and C_Timer.After then
        C_Timer.After(1.25, function()
          if gen ~= lootCombineGen then return end
          LootCombineFlush()
        end)
      end
    end
  end
end

local function FormatOtherLine(name, text)
  local colored = GetClassColoredName(name or "")
  if colored and colored ~= "" then
    return string.format("%s: %s", colored, text)
  end
  return text
end

local CURRENCY_PATTERNS
local CURRENCY_PREFIXES

local CURRENCY_PATTERN_KEYS = {
  -- Retail GlobalStrings (localization-safe):
  "CURRENCY_GAINED",
  "CURRENCY_GAINED_MULTIPLE",
  -- Some clients/locales may also expose these variants; harmless if nil.
  "CURRENCY_GAINED_SELF",
  "CURRENCY_GAINED_SELF_MULTIPLE",
}

local function BuildCurrencyPatterns()
  local patterns = {}
  local prefixes = {}

  for _, k in ipairs(CURRENCY_PATTERN_KEYS) do
    local gs = _G and rawget(_G, k)
    local pat = GlobalStringToPattern(gs)
    if pat then
      patterns[#patterns + 1] = pat
    end
    if type(gs) == "string" and gs ~= "" then
      local prefix = gs:match("^(.-)%%[sd]")
      if prefix and prefix ~= "" then
        prefixes[#prefixes + 1] = prefix
      end
    end
  end

  CURRENCY_PATTERNS = patterns
  CURRENCY_PREFIXES = prefixes
end

local function OnCurrencyChat(_, _, msg, ...)
  if not IsEnabled() then return false end
  if type(msg) ~= "string" or msg == "" then return false end

  if not CURRENCY_PATTERNS then BuildCurrencyPatterns() end

  local link, qty
  for _, pat in ipairs(CURRENCY_PATTERNS or {}) do
    local a, b = msg:match(pat)
    if a then
      if b then
        local aIsLink = type(a) == "string" and a:find("|Hcurrency:", 1, true) ~= nil
        local bIsLink = type(b) == "string" and b:find("|Hcurrency:", 1, true) ~= nil

        -- Some locales/globalstrings put %d before %s, so captures can be swapped.
        if aIsLink and not bIsLink then
          link, qty = a, b
        elseif bIsLink and not aIsLink then
          link, qty = b, a
        else
          -- Fallback: pick the one that looks numeric as qty.
          if tonumber(a) and not tonumber(b) then
            qty = a
          elseif tonumber(b) and not tonumber(a) then
            qty = b
          end
          link = ExtractCurrencyLinkFallback(msg) or a
        end
      else
        link = a
      end
      break
    end
  end

  if not link then
    link = ExtractCurrencyLinkFallback(msg)
  end
  if not link then
    return false
  end

  -- Quantity fallback: some clients/locales don't expose a %d token for currency gain.
  -- Try to parse a trailing multiplier near the currency token.
  if not qty then
    local escaped = EscapeLuaPattern(link)
    qty = msg:match(escaped .. "%s*[x×]%s*(%d+)")
      or msg:match(escaped .. "[\r\n ]*[x×]%s*(%d+)")
      or msg:match("%s*[x×]%s*(%d+)%s*%.?$")
  end

  -- Prefer constructing a canonical currency hyperlink so color/clickability is consistent.
  local n = tonumber(qty)
  local currencyID = GetCurrencyIDFromLink(link)
  if currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyLink then
    local built = C_CurrencyInfo.GetCurrencyLink(currencyID, (n and n > 0) and n or 0)
    if type(built) == "string" and built ~= "" then
      link = built
    end
  end

  local handled = false
  if DB.echoItem then
    local out = ApplyCurrencyLinkAlias(link)
    out = StripDisplayedLinkBrackets(out)
    if n and n > 1 then
      out = string.format("%s x%d", out, n)
    end
    if LootCombineEnabled() then
      if DB and DB.lootCombineIncludeCurrency then
        LootCombineAdd(out)
        handled = true
      end
    else
      Print(FormatSelfLine(out))
      handled = true
    end
  end

  -- Only suppress the original system line when we actually output (or buffer) a replacement.
  -- This avoids "missing" currency lines when loot-combine is enabled but currency is excluded.
  return (handled and DB.hideLootText) and true or false
end

local MONEY_PATTERNS
local MONEY_PREFIXES

local MONEY_PATTERN_KEYS = {
  "LOOT_MONEY",
  "LOOT_MONEY_SPLIT",
}

local function BuildMoneyPatterns()
  local patterns = {}
  local prefixes = {}

  for _, k in ipairs(MONEY_PATTERN_KEYS) do
    local gs = _G and rawget(_G, k)
    local pat = GlobalStringToPattern(gs)
    if pat then
      patterns[#patterns + 1] = pat
    end
    if type(gs) == "string" and gs ~= "" then
      local prefix = gs:match("^(.-)%%[sd]")
      if prefix and prefix ~= "" then
        prefixes[#prefixes + 1] = prefix
      end
    end
  end

  MONEY_PATTERNS = patterns
  MONEY_PREFIXES = prefixes
end

local function ParseCoinsFromMoneyMessage(msg)
  if type(msg) ~= "string" or msg == "" then return nil end

  local function numBeforeTexture(textureNeedle)
    local s = msg:match("([%d,]+)%s*|T.-" .. textureNeedle .. ".-|t")
    if not s then return nil end
    s = s:gsub(",", "")
    return tonumber(s)
  end

  local gold = numBeforeTexture("UI%-GoldIcon")
  local silver = numBeforeTexture("UI%-SilverIcon")
  local copper = numBeforeTexture("UI%-CopperIcon")

  -- Some clients/sources emit money text without textures (e.g. "5 gold").
  -- Try a lightweight localized word/symbol parse as fallback.
  if not (gold or silver or copper) then
    local lower = msg:lower()

    local function numBeforeToken(token)
      if type(token) ~= "string" or token == "" then return nil end
      local n = lower:match("([%d,]+)%s*" .. EscapeLuaPattern(token:lower()))
      if not n then return nil end
      n = n:gsub(",", "")
      return tonumber(n)
    end

    gold = numBeforeToken((_G and rawget(_G, "GOLD")) or "gold")
      or numBeforeToken((_G and rawget(_G, "GOLD_AMOUNT_SYMBOL")) or "g")
    silver = numBeforeToken((_G and rawget(_G, "SILVER")) or "silver")
      or numBeforeToken((_G and rawget(_G, "SILVER_AMOUNT_SYMBOL")) or "s")
    copper = numBeforeToken((_G and rawget(_G, "COPPER")) or "copper")
      or numBeforeToken((_G and rawget(_G, "COPPER_AMOUNT_SYMBOL")) or "c")
  end

  return {
    gold = gold or 0,
    silver = silver or 0,
    copper = copper or 0,
  }
end

local function FormatMoney(coins)
  if type(coins) ~= "table" then return nil end
  local m = (DB and type(DB.money) == "table") and DB.money or DEFAULTS.money

  local parts = {}
  if m.gold and (tonumber(coins.gold) or 0) > 0 then
    parts[#parts + 1] = tostring(coins.gold) .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
  end
  if m.silver and (tonumber(coins.silver) or 0) > 0 then
    parts[#parts + 1] = tostring(coins.silver) .. "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
  end
  if m.copper and (tonumber(coins.copper) or 0) > 0 then
    parts[#parts + 1] = tostring(coins.copper) .. "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
  end

  if #parts == 0 then
    return nil
  end

  return table.concat(parts, " ")
end

local function IsLikelyMoneyMessage(msg)
  if type(msg) ~= "string" or msg == "" then return false end

  -- Fast path: coin textures are present in the chat message.
  if msg:find("UI%-GoldIcon") or msg:find("UI%-SilverIcon") or msg:find("UI%-CopperIcon") then
    return true
  end

  local lower = msg:lower()

  -- Prefer matching the full localized string (LOOT_MONEY / LOOT_MONEY_SPLIT),
  -- but keep additional heuristics for edge cases.
  if not MONEY_PATTERNS then BuildMoneyPatterns() end

  for _, pat in ipairs(MONEY_PATTERNS or {}) do
    if msg:match(pat) then
      return true
    end
  end

  for _, prefix in ipairs(MONEY_PREFIXES or {}) do
    if msg:sub(1, #prefix) == prefix then
      return true
    end
  end

  -- Fallback: explicit money words (localized when possible).
  local function hasToken(token)
    if type(token) ~= "string" or token == "" then return false end
    return lower:find(token:lower(), 1, true) ~= nil
  end
  if hasToken((_G and rawget(_G, "GOLD")) or "gold") or hasToken((_G and rawget(_G, "SILVER")) or "silver") or hasToken((_G and rawget(_G, "COPPER")) or "copper") then
    return true
  end

  -- Fallback: symbol forms, but only when a number precedes the symbol.
  -- (Important: don't treat plain 'g'/'s'/'c' letters as money; that would match normal loot lines.)
  local function hasNumberBeforeToken(token)
    if type(token) ~= "string" or token == "" then return false end
    return lower:match("[%d,]+%s*" .. EscapeLuaPattern(token:lower())) ~= nil
  end
  if hasNumberBeforeToken((_G and rawget(_G, "GOLD_AMOUNT_SYMBOL")) or "g")
    or hasNumberBeforeToken((_G and rawget(_G, "SILVER_AMOUNT_SYMBOL")) or "s")
    or hasNumberBeforeToken((_G and rawget(_G, "COPPER_AMOUNT_SYMBOL")) or "c") then
    return true
  end

  return false
end

local function OnMoneyChat(_, _, msg, ...)
  if not IsEnabled() then return false end
  if type(msg) ~= "string" or msg == "" then return false end

  if not IsLikelyMoneyMessage(msg) then return false end

  local handled = false
  if DB.echoItem then
    local coins = ParseCoinsFromMoneyMessage(msg)
    local out = FormatMoney(coins)
    if out then
      if LootCombineEnabled() then
        if DB and DB.lootCombineIncludeGold then
          LootCombineAdd(out)
          handled = true
        end
      else
        Print(FormatSelfLine(out))
        handled = true
      end
    end
  end

  -- Only suppress the original system line when we actually output (or buffer) a replacement.
  -- This avoids "missing" money lines when loot-combine is enabled but gold is excluded.
  return (handled and DB.hideLootText) and true or false
end

local function OnLootChat(_, _, msg, author, ...)
  if not IsEnabled() then return false end
  if type(msg) ~= "string" or msg == "" then return false end

  if not LOOT_PATTERNS then BuildLootPatterns() end

  -- Some rewards (e.g. end-of-dungeon) can arrive as CHAT_MSG_LOOT but contain currency links.
  -- Rewrite them using the same path as CHAT_MSG_CURRENCY so we don't leak default loot text.
  if msg:find("|Hcurrency:", 1, true) then
    local handled = false

    local link = (ExtractCurrencyLinkFallback and ExtractCurrencyLinkFallback(msg))
      or msg:match("(|Hcurrency:%d+.-|h.-|h)")
      or msg:match("(|c%x%x%x%x%x%x%x%x|Hcurrency:%d+.-|h.-|h|r)")

    if link and DB and DB.echoItem then
      local qty
      local escaped = EscapeLuaPattern(link)
      qty = msg:match(escaped .. "%s*[x×]%s*(%d+)")
        or msg:match(escaped .. "[\r\n ]*[x×]%s*(%d+)")
        or msg:match("%s*[x×]%s*(%d+)%s*%.?$")

      local n = tonumber(qty)
      local currencyID = (GetCurrencyIDFromLink and GetCurrencyIDFromLink(link)) or nil
      if currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyLink then
        local built = C_CurrencyInfo.GetCurrencyLink(currencyID, (n and n > 0) and n or 0)
        if type(built) == "string" and built ~= "" then
          link = built
        end
      end

      local out = (ApplyCurrencyLinkAlias and ApplyCurrencyLinkAlias(link)) or link
      out = StripDisplayedLinkBrackets(out)
      if n and n > 1 then
        out = string.format("%s x%d", out, n)
      end

      if LootCombineEnabled() then
        if DB and DB.lootCombineIncludeCurrency then
          LootCombineAdd(out)
          handled = true
        end
      else
        Print(FormatSelfLine(out))
        handled = true
      end
    end

    return (handled and DB and DB.hideLootText) and true or false
  end

  -- Some loot sources emit a standalone header line like "You receive loot:" with no link,
  -- followed by separate item lines. Hiding it avoids the brief "addon turned off" look.
  if (DB and DB.hideLootText) and (LOOT_PREFIXES and #LOOT_PREFIXES > 0) then
    local hasItem = msg:find("|Hitem:", 1, true) ~= nil
    local hasCurrency = msg:find("|Hcurrency:", 1, true) ~= nil
    if (not hasItem) and (not hasCurrency) and (not IsLikelyMoneyMessage(msg)) then
      local function Trim(s)
        if type(s) ~= "string" then return "" end
        s = s:gsub("^%s+", "")
        s = s:gsub("%s+$", "")
        return s
      end

      local tmsg = Trim(msg)
      for _, prefix in ipairs(LOOT_PREFIXES) do
        if tmsg == Trim(prefix) then
          return true
        end
      end
    end
  end

  -- Some clients/sources emit coin loot via CHAT_MSG_LOOT instead of CHAT_MSG_MONEY.
  -- Catch and filter it here so "You loot X gold/silver/copper" doesn't leak through.
  if IsLikelyMoneyMessage(msg) then
    local handled = false
    if DB.echoItem then
      local coins = ParseCoinsFromMoneyMessage(msg)
      local out = FormatMoney(coins)
      if out then
        if LootCombineEnabled() and (DB and DB.lootCombineIncludeGold) then
          LootCombineAdd(out)
          handled = true
        else
          Print(FormatSelfLine(out))
          handled = true
        end
      end
    end
    return (handled and DB.hideLootText) and true or false
  end

  local isSelfLoot = false
  local playerName
  local link, qty

  -- Prefer matching the self-loot patterns directly. Relying on extracted localized
  -- prefixes is fragile across client versions/locales.
  for _, pat in ipairs(LOOT_PATTERNS or {}) do
    local a, b = msg:match(pat)
    if a then
      isSelfLoot = true
      if b then
        link, qty = a, b
      else
        link = a
      end
      break
    end
  end

  -- If it wasn't a self-loot line, try group/other-player patterns.
  if not link then
    for _, pat in ipairs(LOOT_GROUP_PATTERNS or {}) do
      local a, b, c = msg:match(pat)
      if a and b then
        if IsItemLink(a) and not IsItemLink(b) then
          link, playerName, qty = a, b, c
        elseif IsItemLink(b) and not IsItemLink(a) then
          playerName, link, qty = a, b, c
        else
          playerName, link, qty = a, b, c
        end
        break
      end
    end

    -- Some loot lines may not include the looter name in the localized string,
    -- but the chat event can still provide an author. Use that as fallback.
    if (not playerName or playerName == "") and type(author) == "string" and author ~= "" then
      playerName = author
    end
  end

  if not link then
    link = ExtractLinkFallback(msg)
  end
  if not link then
    return false
  end

  if DB.echoItem then
    link = NormalizeItemLink(link)
    link = ApplyItemLinkAlias(link)
    local displayLink = StripDisplayedLinkBrackets(link)
    local out = displayLink
    local n = tonumber(qty)
    if n and n > 1 then
      out = string.format("%s x%d", displayLink, n)
    end

    if IsItemLevelEnabled() then
      local ilvl = GetEquippableItemLevelSuffix(link)
      if ilvl then
        local color = link:match("^(|c%x%x%x%x%x%x%x%x)")
        local ilvlText
        if color then
          ilvlText = color .. tostring(ilvl) .. "|r"
        else
          ilvlText = tostring(ilvl)
        end

        out = out .. " " .. ilvlText
      end
    end

    if isSelfLoot then
      LootCombineAdd(out)
    else
      Print(FormatOtherLine(playerName, out))
    end
  end

  return DB.hideLootText and true or false
end

local function OnAchievementChat(_, _, msg, author, ...)
  if not (DB and DB.other and DB.other.achievement and DB.other.achievement.enabled) then
    return false
  end
  if type(msg) ~= "string" or msg == "" then
    return false
  end

  local link = ExtractAchievementLinkFallback(msg)
  if not link then
    return false
  end

  local name = StripRealmFromName(author)
  if type(name) ~= "string" or name == "" then
    name = "Character"
  end

  local displayLink = StripDisplayedLinkBrackets(link)
  local out = string.format("%s: earned %s!", name, displayLink)

  local outFrame = (DB.other and DB.other.outputChatFrame) or (DB and DB.outputChatFrame) or 1
  PrintToChatFrame(out, outFrame)

  return true
end

local function ApplyFilters()
  -- These globals can be nil at addon load time depending on UI load order.
  -- Resolve them lazily here so the addon still works reliably.
  if not ChatFrame_AddMessageEventFilter then
    ChatFrame_AddMessageEventFilter = _G and rawget(_G, "ChatFrame_AddMessageEventFilter")
  end
  if not ChatFrame_RemoveMessageEventFilter then
    ChatFrame_RemoveMessageEventFilter = _G and rawget(_G, "ChatFrame_RemoveMessageEventFilter")
  end
  if not (ChatFrame_AddMessageEventFilter and ChatFrame_RemoveMessageEventFilter) then return end

  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_LOOT", OnLootChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_CURRENCY", OnCurrencyChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONEY", OnMoneyChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_ACHIEVEMENT", OnAchievementChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_GUILD_ACHIEVEMENT", OnAchievementChat)
  if IsEnabled() then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", OnLootChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CURRENCY", OnCurrencyChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_MONEY", OnMoneyChat)
  end
  if DB and DB.other and DB.other.achievement and DB.other.achievement.enabled then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_ACHIEVEMENT", OnAchievementChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD_ACHIEVEMENT", OnAchievementChat)
  end
end

local function ApplyFiltersSoon(delaySeconds)
  if not (C_Timer and C_Timer.After) then return end
  local d = tonumber(delaySeconds) or 0
  if d < 0 then d = 0 end
  C_Timer.After(d, function()
    EnsureDB()
    ApplyFilters()
  end)
end

local function GetSupportedMessageLines()
  local lines = {}
  lines[#lines + 1] = "Supported message events:"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "CHAT_MSG_LOOT"
  lines[#lines + 1] = "  - Filters only self loot lines (localized via GlobalStrings)"
  lines[#lines + 1] = "  - GlobalString keys:"
  for _, k in ipairs(LOOT_PATTERN_KEYS) do
    lines[#lines + 1] = "    - " .. k
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  - Also handles group loot lines (other players)"
  lines[#lines + 1] = "  - Reprints as 'Name: [Item]' (realm suffix removed)"
  lines[#lines + 1] = "  - GlobalString keys:"
  for _, k in ipairs(LOOT_GROUP_PATTERN_KEYS) do
    lines[#lines + 1] = "    - " .. k
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Notes:"
  lines[#lines + 1] = "  - This does not block loot itself, only chat text."
  lines[#lines + 1] = "  - Loot distribution is unchanged; only chat text is filtered."
  lines[#lines + 1] = ""
  lines[#lines + 1] = "CHAT_MSG_ACHIEVEMENT / CHAT_MSG_GUILD_ACHIEVEMENT"
  lines[#lines + 1] = "  - Optional: rewrites to 'Name: earned Link!'"
  lines[#lines + 1] = "  - Realm removed; achievement link brackets removed"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "CHAT_MSG_CURRENCY"
  lines[#lines + 1] = "  - Filters 'You receive currency: ...' (self)"
  lines[#lines + 1] = "  - GlobalString keys:"
  for _, k in ipairs(CURRENCY_PATTERN_KEYS) do
    lines[#lines + 1] = "    - " .. k
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "CHAT_MSG_MONEY"
  lines[#lines + 1] = "  - Filters 'You loot ...' money lines (self)"
  lines[#lines + 1] = "  - Reprints selected coins (gold/silver/copper)"
  lines[#lines + 1] = "  - GlobalString keys:"
  for _, k in ipairs(MONEY_PATTERN_KEYS) do
    lines[#lines + 1] = "    - " .. k
  end
  return lines
end

local ConfigUI

local function IsMailEditorOpen()
  if not (ConfigUI and ConfigUI.IsShown and ConfigUI:IsShown()) then return false end
  return (ConfigUI._activeTab == "mail")
end

-- Forward declarations (CreateConfigUI references these).
local CreateMailNotifier
local UpdateMailNotifier

local ApplyMailModelToFrame

local MailNotifier

local ApplyMailNotifierInteractivity
local ModelGetRotation
local ModelSetRotation
local ModelApplyZoom
local ModelApplyAnimation

local OpenMailModelPicker

local function CreateConfigUI()
  if ConfigUI then return ConfigUI end

  local frame = CreateFrame("Frame", "fr0z3nUI_LootIt_Config", UIParent, "BasicFrameTemplateWithInset")

  -- Allow closing with Escape.
  if type(UISpecialFrames) == "table" then
    local name = "fr0z3nUI_LootIt_Config"
    local exists = false
    for i = 1, #UISpecialFrames do
      if UISpecialFrames[i] == name then exists = true break end
    end
    if not exists and tinsert then tinsert(UISpecialFrames, name) end
  end

  frame:SetSize(480, 400)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if DB and DB.ui then
      local point, _, _, x, y = self:GetPoint(1)
      DB.ui.point = point or "CENTER"
      DB.ui.x = x or 0
      DB.ui.y = y or 0
    end
  end)

  local titleFS = frame.TitleText
  if not (titleFS and titleFS.SetText and titleFS.SetPoint) then
    titleFS = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  end
  frame._titleFS = titleFS

  titleFS:SetText("|cff00ccff[FLI]|r LootIt")
  titleFS:ClearAllPoints()
  titleFS:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -6)

  local function GetEnableMode()
    EnsureDB()
    if CHARDB and CHARDB.enabledOverride == true then return "on" end
    if CHARDB and CHARDB.enabledOverride == false then return "off" end
    if DB and DB.enabled then return "acc" end
    return "off"
  end

  local function SetEnableMode(mode)
    EnsureDB()
    mode = tostring(mode or ""):lower()
    if mode == "on" then
      CHARDB.enabledOverride = true
    elseif mode == "acc" then
      CHARDB.enabledOverride = nil
      DB.enabled = true
    else -- off
      CHARDB.enabledOverride = false
    end
    ApplyFilters()
  end

  local enableModeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  enableModeBtn:SetSize(90, 20)
  enableModeBtn:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -6)
  enableModeBtn:SetScript("OnClick", function()
    local cur = GetEnableMode()
    local nextMode = (cur == "off") and "on" or ((cur == "on") and "acc" or "off")
    SetEnableMode(nextMode)
    -- Refresh text immediately.
    local m = GetEnableMode()
    enableModeBtn:SetText((m == "on") and "On" or ((m == "acc") and "On Acc" or "Off"))
  end)

  local sub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  sub:SetPoint("TOPLEFT", frame.InsetBg, "TOPLEFT", 10, -10)
  sub:SetJustifyH("LEFT")
  sub:SetText("")

  -- Tabs
  local tabLoot = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  tabLoot:SetSize(80, 22)
  tabLoot:SetPoint("LEFT", enableModeBtn, "RIGHT", 10, 0)
  tabLoot:SetText("Loot")

  local tabAlias = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  tabAlias:SetSize(80, 22)
  tabAlias:SetPoint("LEFT", tabLoot, "RIGHT", 10, 0)
  tabAlias:SetText("Alias")

  local tabOther = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  tabOther:SetSize(80, 22)
  tabOther:SetPoint("LEFT", tabAlias, "RIGHT", 10, 0)
  tabOther:SetText("Other")

  local tabMail = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  tabMail:SetSize(80, 22)
  tabMail:SetPoint("LEFT", tabOther, "RIGHT", 10, 0)
  tabMail:SetText("Mail")

  local lootPanel = CreateFrame("Frame", nil, frame)
  lootPanel:SetPoint("TOPLEFT", frame.InsetBg, "TOPLEFT", 0, -24)
  lootPanel:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", 0, 0)

  local mailPanel = CreateFrame("Frame", nil, frame)
  mailPanel:SetPoint("TOPLEFT", frame.InsetBg, "TOPLEFT", 0, -24)
  mailPanel:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", 0, 0)

  local aliasPanel = CreateFrame("Frame", nil, frame)
  aliasPanel:SetPoint("TOPLEFT", frame.InsetBg, "TOPLEFT", 0, -24)
  aliasPanel:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", 0, 0)

  local otherPanel = CreateFrame("Frame", nil, frame)
  otherPanel:SetPoint("TOPLEFT", frame.InsetBg, "TOPLEFT", 0, -24)
  otherPanel:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", 0, 0)

  local function SelectTab(which)
    which = tostring(which or "loot"):lower()
    local isLoot = (which == "loot")
    local isAlias = (which == "alias")
    local isOther = (which == "other")
    local isMail = (which == "mail")

    lootPanel:SetShown(isLoot)
    aliasPanel:SetShown(isAlias)
    otherPanel:SetShown(isOther)
    mailPanel:SetShown(isMail)

    tabLoot:SetEnabled(not isLoot)
    tabAlias:SetEnabled(not isAlias)
    tabOther:SetEnabled(not isOther)
    tabMail:SetEnabled(not isMail)

    frame._activeTab = isLoot and "loot" or (isAlias and "alias" or (isOther and "other" or "mail"))

    ApplyMailNotifierInteractivity()
  end

  frame.SelectTab = SelectTab

  tabLoot:SetScript("OnClick", function() SelectTab("loot") end)
  tabAlias:SetScript("OnClick", function() SelectTab("alias") end)
  tabOther:SetScript("OnClick", function() SelectTab("other") end)
  tabMail:SetScript("OnClick", function() SelectTab("mail") end)

  -- Other tab
  local otherTitle = otherPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  otherTitle:SetPoint("TOPLEFT", otherPanel, "TOPLEFT", 10, -10)
  otherTitle:SetText("Other")

  local achCB = CreateFrame("CheckButton", nil, otherPanel, "UICheckButtonTemplate")
  achCB:SetPoint("TOPLEFT", otherTitle, "BOTTOMLEFT", 0, -10)
  SetCheckBoxText(achCB, "Achievement")
  achCB:SetScript("OnClick", function(self)
    EnsureDB()
    DB.other = (type(DB.other) == "table") and DB.other or {}
    DB.other.achievement = (type(DB.other.achievement) == "table") and DB.other.achievement or {}
    DB.other.achievement.enabled = self:GetChecked() and true or false
    ApplyFilters()
  end)

  do
    local t = achCB.Text or achCB.text
    if t and t.ClearAllPoints and t.SetPoint then
      if achCB and achCB.SetSize then
        achCB:SetSize(24, 24)
      end
      t:ClearAllPoints()
      t:SetPoint("LEFT", achCB, "RIGHT", 3, 0)

      if achCB and achCB.SetHitRectInsets and t.GetStringWidth then
        local w = tonumber(t:GetStringWidth()) or 0
        if w > 0 then
          achCB:SetHitRectInsets(0, -(w + 10), 0, 0)
        end
      end
    end
  end

  local otherOutputLabel = otherPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  otherOutputLabel:SetPoint("LEFT", (achCB.Text or achCB.text) or achCB, "RIGHT", 18, 0)
  otherOutputLabel:SetText("Output")

  local otherOutputDD = CreateFrame("Frame", "fr0z3nUI_LootIt_OtherOutputDropDown", otherPanel, "UIDropDownMenuTemplate")
  otherOutputDD:SetPoint("LEFT", otherOutputLabel, "RIGHT", -6, -2)
  UIDropDownMenu_SetWidth(otherOutputDD, 140)

  do
    local mu = _G and rawget(_G, "MenuUtil")
    if type(mu) == "table" and type(mu.CreateContextMenu) == "function" then
      local anchor = otherOutputDD.Button or otherOutputDD
      if anchor and anchor.SetScript then
        anchor:SetScript("OnClick", function(btn)
          mu.CreateContextMenu(btn, function(_, root)
            if root and root.CreateTitle then root:CreateTitle("Output") end
            EnsureDB()
            DB.other = (type(DB.other) == "table") and DB.other or {}
            for i = 1, (NUM_CHAT_WINDOWS or 1) do
              local name = GetChatWindowInfo and GetChatWindowInfo(i)
              if not name or name == "" then name = "Chat " .. i end
              local label = string.format("%d: %s", i, name)
              if root and root.CreateRadio then
                root:CreateRadio(label, function() return (DB.other.outputChatFrame == i) end, function()
                  EnsureDB()
                  DB.other = (type(DB.other) == "table") and DB.other or {}
                  DB.other.outputChatFrame = i
                  if UIDropDownMenu_SetSelectedID then UIDropDownMenu_SetSelectedID(otherOutputDD, i) end
                end)
              elseif root and root.CreateButton then
                root:CreateButton(label, function()
                  EnsureDB()
                  DB.other = (type(DB.other) == "table") and DB.other or {}
                  DB.other.outputChatFrame = i
                  if UIDropDownMenu_SetSelectedID then UIDropDownMenu_SetSelectedID(otherOutputDD, i) end
                end)
              end
            end
          end)
        end)
      end
    else
      UIDropDownMenu_Initialize(otherOutputDD, function(_, level)
    level = level or 1
    if level ~= 1 then return end
    EnsureDB()
    DB.other = (type(DB.other) == "table") and DB.other or {}

    for i = 1, (NUM_CHAT_WINDOWS or 1) do
      local name = GetChatWindowInfo and GetChatWindowInfo(i)
      if not name or name == "" then
        name = "Chat " .. i
      end

      local info = UIDropDownMenu_CreateInfo()
      info.text = string.format("%d: %s", i, name)
      info.checked = (DB.other.outputChatFrame == i)
      info.func = function()
        EnsureDB()
        DB.other = (type(DB.other) == "table") and DB.other or {}
        DB.other.outputChatFrame = i
        UIDropDownMenu_SetSelectedID(otherOutputDD, i)
        do local cdm = _G and rawget(_G, "CloseDropDownMenus"); if cdm then cdm() end end
      end
      UIDropDownMenu_AddButton(info, level)
    end
      end)
    end
  end

  local exampleTitle = otherPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  exampleTitle:SetPoint("TOPLEFT", achCB, "BOTTOMLEFT", 0, -14)
  exampleTitle:SetText("Achievement Format")

  local ex1 = otherPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ex1:SetPoint("TOPLEFT", exampleTitle, "BOTTOMLEFT", 0, -6)
  ex1:SetJustifyH("LEFT")
  ex1:SetText("[Character] has earned the achievement [link]")

  local ex2 = otherPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ex2:SetPoint("TOPLEFT", ex1, "BOTTOMLEFT", 0, -4)
  ex2:SetJustifyH("LEFT")
  ex2:SetText("Character: earned Link!")

  otherPanel.Refresh = function()
    EnsureDB()
    DB.other = (type(DB.other) == "table") and DB.other or {}
    DB.other.achievement = (type(DB.other.achievement) == "table") and DB.other.achievement or {}
    SetCheckBoxChecked(achCB, DB.other.achievement.enabled == true)
    UIDropDownMenu_SetSelectedID(otherOutputDD, DB.other.outputChatFrame or 1)
  end

  local hide = CreateFrame("CheckButton", nil, lootPanel, "UICheckButtonTemplate")
  hide:SetPoint("TOPLEFT", lootPanel, "TOPLEFT", 10, -6)
  SetCheckBoxText(hide, "Hide |cff15AB0DYou receive loot:|r")
  hide:SetScript("OnClick", function(self)
    EnsureDB()
    DB.hideLootText = self:GetChecked() and true or false
  end)

  local function TightenCheckBoxLabel(cb)
    local t = cb and (cb.Text or cb.text)
    if t and t.ClearAllPoints and t.SetPoint then
      if cb and cb.SetSize then
        cb:SetSize(24, 24)
      end
      t:ClearAllPoints()
      t:SetPoint("LEFT", cb, "RIGHT", 3, 0)

      -- Keep the click area covering the label even though the button itself is small.
      if cb and cb.SetHitRectInsets and t.GetStringWidth then
        local w = tonumber(t:GetStringWidth()) or 0
        if w > 0 then
          cb:SetHitRectInsets(0, -(w + 10), 0, 0)
        end
      end
    end
  end

  TightenCheckBoxLabel(hide)

  local hideText = hide.Text or hide.text
  if hideText and hideText.SetWidth then
    hideText:SetWidth(220)
  end
  if hideText and hideText.GetFont and hideText.SetFont then
    local f, s, flags = hideText:GetFont()
    if f and s then
      hideText:SetFont(f, s + 1, flags)
    end
  end

  local echo = CreateFrame("CheckButton", nil, lootPanel, "UICheckButtonTemplate")
  echo:SetPoint("LEFT", (hide.Text or hide.text) or hide, "RIGHT", 10, 0)
  SetCheckBoxText(echo, "Show Loot Only Line")
  echo:SetScript("OnClick", function(self)
    EnsureDB()
    DB.echoItem = self:GetChecked() and true or false
  end)

  TightenCheckBoxLabel(echo)

  local combineLabel = lootPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  combineLabel:SetPoint("TOPLEFT", hide, "BOTTOMLEFT", 2, -10)
  combineLabel:SetText("Loot In Line")

  local combineBox = CreateFrame("EditBox", nil, lootPanel, "InputBoxTemplate")
  combineBox:SetSize(46, 20)
  combineBox:SetPoint("LEFT", combineLabel, "RIGHT", 8, 0)
  combineBox:SetAutoFocus(false)
  combineBox:SetNumeric(true)
  combineBox:SetJustifyH("CENTER")
  combineBox:SetScript("OnEnterPressed", function(self)
    EnsureDB()
    local n = tonumber(self:GetText() or "") or 1
    if n < 1 then n = 1 end
    if n > 25 then n = 25 end
    DB.lootCombineCount = n
    self:SetText(tostring(n))
    self:ClearFocus()

    if n <= 1 then
      LootCombineCancelTimers()
      LootCombineFlush()
    end
  end)

  local function CreateInlineTextToggleButton(parent, text, onColor)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(70, 20)

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetColorTexture(1, 1, 1, 0.06)
    hl:SetAllPoints(b)

    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER", b, "CENTER", 0, 0)
    fs:SetText(tostring(text or ""))
    b._text = fs
    b._onColor = onColor

    function b:SetOn(on)
      self._on = on and true or false
      if self._text then
        if self._on then
          local c = self._onColor or { 1, 1, 1, 1 }
          self._text:SetTextColor(c[1], c[2], c[3], c[4] or 1)
        else
          self._text:SetTextColor(0.65, 0.65, 0.65, 1)
        end
      end
    end

    b:SetOn(false)
    return b
  end

  local plusGold = lootPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  plusGold:SetPoint("LEFT", combineBox, "RIGHT", 8, 0)
  plusGold:SetText("+")

  local combineGold = CreateInlineTextToggleButton(lootPanel, "Gold", { 1, 0.82, 0, 1 })
  combineGold:SetSize(52, 20)
  combineGold:SetPoint("LEFT", plusGold, "RIGHT", 8, 0)
  combineGold:SetScript("OnClick", function(self)
    EnsureDB()
    DB.lootCombineIncludeGold = not (DB.lootCombineIncludeGold == true)
    self:SetOn(DB.lootCombineIncludeGold)
  end)

  local plusCur = lootPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  plusCur:SetPoint("LEFT", combineGold, "RIGHT", 8, 0)
  plusCur:SetText("+")

  local combineCur = CreateInlineTextToggleButton(lootPanel, "Currency", { 0.85, 0.85, 0.85, 1 })
  combineCur:SetSize(72, 20)
  combineCur:SetPoint("LEFT", plusCur, "RIGHT", 8, 0)
  combineCur:SetScript("OnClick", function(self)
    EnsureDB()
    DB.lootCombineIncludeCurrency = not (DB.lootCombineIncludeCurrency == true)
    self:SetOn(DB.lootCombineIncludeCurrency)
  end)

  local perLabel = lootPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  perLabel:SetPoint("LEFT", combineCur, "RIGHT", 8, 0)
  perLabel:SetText("Per")

  local modeToggle = CreateFrame("Button", nil, lootPanel)
  modeToggle:SetSize(108, 20)
  modeToggle:SetPoint("LEFT", perLabel, "RIGHT", 8, 0)

  local modeHL = modeToggle:CreateTexture(nil, "HIGHLIGHT")
  modeHL:SetColorTexture(1, 1, 1, 0.06)
  modeHL:SetAllPoints(modeToggle)

  local modeText = modeToggle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  modeText:SetPoint("CENTER", modeToggle, "CENTER", 0, 0)
  modeToggle._text = modeText

  local COPPER = { 0.78, 0.61, 0.43, 1 }

  local function RefreshCombineModeButtons()
    EnsureDB()
    local isLoot = (tostring(DB.lootCombineMode or "loot") == "loot")
    if modeToggle._text then
      modeToggle._text:SetText(isLoot and "Loot Window" or "Loot Period")
      modeToggle._text:SetTextColor(COPPER[1], COPPER[2], COPPER[3], COPPER[4])
    end
  end

  modeToggle:SetScript("OnClick", function()
    EnsureDB()
    local isLoot = (tostring(DB.lootCombineMode or "loot") == "loot")
    DB.lootCombineMode = (isLoot and "timer" or "loot")
    LootCombineCancelTimers()
    LootCombineFlush()
    RefreshCombineModeButtons()
  end)

  local function CreateCurrencyToggleButton(parent, texturePath)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(28, 28)
    b:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      tile = true,
      tileSize = 16,
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    -- Always transparent background; state is shown via icon color.
    b:SetBackdropBorderColor(0, 0, 0, 0)
    b:SetBackdropColor(0, 0, 0, 0)

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetColorTexture(1, 1, 1, 0.08)
    hl:SetAllPoints(b)

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(texturePath)
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    b._icon = icon

    function b:SetOn(on)
      self._on = on and true or false
      -- Keep background transparent; toggle icon saturation.
      if self._icon and self._icon.SetDesaturated then
        self._icon:SetDesaturated(not self._on)
      end
      if self._icon and self._icon.SetVertexColor then
        if self._on then
          self._icon:SetVertexColor(1, 1, 1, 1)
        else
          self._icon:SetVertexColor(0.7, 0.7, 0.7, 1)
        end
      end
    end

    return b
  end

  local moneySilver = CreateCurrencyToggleButton(lootPanel, "Interface\\MoneyFrame\\UI-SilverIcon")
  moneySilver:SetPoint("TOP", combineBox, "BOTTOM", 0, -6)

  local moneyGold = CreateCurrencyToggleButton(lootPanel, "Interface\\MoneyFrame\\UI-GoldIcon")
  moneyGold:SetPoint("RIGHT", moneySilver, "LEFT", -8, 0)

  local moneyCopper = CreateCurrencyToggleButton(lootPanel, "Interface\\MoneyFrame\\UI-CopperIcon")
  moneyCopper:SetPoint("LEFT", moneySilver, "RIGHT", 8, 0)

  local function RefreshMoneyButtons()
    EnsureDB()
    DB.money = DB.money or {}
    moneyGold:SetOn(DB.money.gold ~= false)
    moneySilver:SetOn(DB.money.silver == true)
    moneyCopper:SetOn(DB.money.copper == true)
  end

  moneyGold:SetScript("OnClick", function(self)
    EnsureDB()
    DB.money = DB.money or {}
    DB.money.gold = not (DB.money.gold ~= false)
    RefreshMoneyButtons()
  end)

  moneySilver:SetScript("OnClick", function(self)
    EnsureDB()
    DB.money = DB.money or {}
    DB.money.silver = not (DB.money.silver == true)
    RefreshMoneyButtons()
  end)

  moneyCopper:SetScript("OnClick", function(self)
    EnsureDB()
    DB.money = DB.money or {}
    DB.money.copper = not (DB.money.copper == true)
    RefreshMoneyButtons()
  end)

  local selfName = CreateFrame("CheckButton", nil, lootPanel, "UICheckButtonTemplate")
  SetCheckBoxText(selfName, "Show My Name Always")
  selfName:SetScript("OnClick", function(self)
    EnsureDB()
    DB.showSelfNameAlways = self:GetChecked() and true or false
  end)

  TightenCheckBoxLabel(selfName)

  local outputLabel = lootPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  outputLabel:SetPoint("TOPLEFT", moneyGold, "BOTTOMLEFT", 2, -12)
  outputLabel:SetText("Output")

  local outputDD = CreateFrame("Frame", "fr0z3nUI_LootIt_OutputDropDown", lootPanel, "UIDropDownMenuTemplate")
  outputDD:SetPoint("LEFT", outputLabel, "RIGHT", -6, -2)
  UIDropDownMenu_SetWidth(outputDD, 100)

  do
    local mu = _G and rawget(_G, "MenuUtil")
    if type(mu) == "table" and type(mu.CreateContextMenu) == "function" then
      local anchor = outputDD.Button or outputDD
      if anchor and anchor.SetScript then
        anchor:SetScript("OnClick", function(btn)
          mu.CreateContextMenu(btn, function(_, root)
            if root and root.CreateTitle then root:CreateTitle("Output") end
            EnsureDB()
            for i = 1, (NUM_CHAT_WINDOWS or 1) do
              local name = GetChatWindowInfo and GetChatWindowInfo(i)
              if not name or name == "" then name = "Chat " .. i end
              local label = string.format("%d: %s", i, name)
              if root and root.CreateRadio then
                root:CreateRadio(label, function() return (DB.outputChatFrame == i) end, function()
                  EnsureDB()
                  DB.outputChatFrame = i
                  if UIDropDownMenu_SetSelectedID then UIDropDownMenu_SetSelectedID(outputDD, i) end
                end)
              elseif root and root.CreateButton then
                root:CreateButton(label, function()
                  EnsureDB()
                  DB.outputChatFrame = i
                  if UIDropDownMenu_SetSelectedID then UIDropDownMenu_SetSelectedID(outputDD, i) end
                end)
              end
            end
          end)
        end)
      end
    else
      UIDropDownMenu_Initialize(outputDD, function(_, level)
    level = level or 1
    if level ~= 1 then return end
    EnsureDB()

    for i = 1, (NUM_CHAT_WINDOWS or 1) do
      local name = GetChatWindowInfo and GetChatWindowInfo(i)
      if not name or name == "" then
        name = "Chat " .. i
      end

      local info = UIDropDownMenu_CreateInfo()
      info.text = string.format("%d: %s", i, name)
      info.checked = (DB.outputChatFrame == i)
      info.func = function()
        EnsureDB()
        DB.outputChatFrame = i
        UIDropDownMenu_SetSelectedID(outputDD, i)
        do local cdm = _G and rawget(_G, "CloseDropDownMenus"); if cdm then cdm() end end
      end
      UIDropDownMenu_AddButton(info, level)
    end
      end)
    end
  end

  local prefixLabel = lootPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  prefixLabel:SetPoint("LEFT", outputDD, "RIGHT", 6, 2)
  prefixLabel:SetText("Prefix")

  local prefixBox = CreateFrame("EditBox", nil, lootPanel, "InputBoxTemplate")
  prefixBox:SetSize(120, 20)
  prefixBox:SetPoint("LEFT", prefixLabel, "RIGHT", 6, 0)
  prefixBox:SetAutoFocus(false)
  prefixBox:SetJustifyH("LEFT")
  prefixBox:SetScript("OnEnterPressed", function(self)
    EnsureDB()
    DB.echoPrefix = tostring(self:GetText() or "")
    self:ClearFocus()
  end)
  prefixBox:SetScript("OnEscapePressed", function(self)
    self:SetText(DB and DB.echoPrefix or "")
    self:ClearFocus()
  end)

  do
    local ph = prefixBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    ph:SetPoint("LEFT", prefixBox, "LEFT", 6, 0)
    ph:SetText("Optional")
    ph:Show()
    local function UpdatePlaceholder()
      local txt = tostring(prefixBox:GetText() or "")
      if txt == "" and not prefixBox:HasFocus() then
        ph:Show()
      else
        ph:Hide()
      end
    end
    prefixBox:HookScript("OnEditFocusGained", UpdatePlaceholder)
    prefixBox:HookScript("OnEditFocusLost", UpdatePlaceholder)
    prefixBox:HookScript("OnTextChanged", UpdatePlaceholder)
    UpdatePlaceholder()
  end

  -- Align "Show My Name in Groups" checkbox with the prefix box left edge.
  selfName:ClearAllPoints()
  selfName:SetPoint("TOP", moneyGold, "TOP", 0, 0)
  selfName:SetPoint("LEFT", prefixLabel, "LEFT", 0, 0)

  -- iLvl display: 3-state (account-wide on, per-char off, account-wide off)
  local ilvlRow = CreateFrame("Frame", nil, lootPanel)
  ilvlRow:SetHeight(20)
  ilvlRow:SetPoint("TOPLEFT", outputLabel, "BOTTOMLEFT", 0, -10)
  ilvlRow:SetPoint("RIGHT", lootPanel, "RIGHT", -10, 0)

  local ilvlLabel = lootPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  ilvlLabel:SetPoint("LEFT", ilvlRow, "LEFT", 0, 0)
  ilvlLabel:SetText("iLvl")

  local ilvlToggle = CreateFrame("Button", nil, lootPanel)
  ilvlToggle:SetSize(210, 20)
  ilvlToggle:SetPoint("LEFT", ilvlLabel, "RIGHT", 10, 0)

  local ilvlHL = ilvlToggle:CreateTexture(nil, "HIGHLIGHT")
  ilvlHL:SetColorTexture(1, 1, 1, 0.06)
  ilvlHL:SetAllPoints(ilvlToggle)

  local ilvlText = ilvlToggle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  ilvlText:SetPoint("CENTER", ilvlToggle, "CENTER", 0, 0)
  ilvlToggle._text = ilvlText

  local function GetIlvlMode()
    EnsureDB()
    local accOn = (DB.showItemLevel ~= false)
    local charHasOverride = (CHARDB and CHARDB.showItemLevel ~= nil)

    if not accOn then
      return "off_acc"
    end
    if charHasOverride and (CHARDB.showItemLevel == false) then
      return "off_char"
    end
    return "on_acc"
  end

  local function RefreshIlvlButtons()
    local mode = GetIlvlMode()
    if ilvlToggle._text then
      if mode == "on_acc" then
        ilvlToggle._text:SetText("On Acc")
        ilvlToggle._text:SetTextColor(0.20, 1.00, 0.20, 1)
      elseif mode == "off_char" then
        ilvlToggle._text:SetText("Off Char")
        ilvlToggle._text:SetTextColor(1.00, 0.72, 0.10, 1)
      else
        ilvlToggle._text:SetText("Off Acc")
        ilvlToggle._text:SetTextColor(1.00, 0.25, 0.25, 1)
      end
    end
  end

  ilvlToggle:SetScript("OnClick", function()
    local mode = GetIlvlMode()
    EnsureDB()

    if mode == "on_acc" then
      -- Next: Off Char
      if CHARDB then CHARDB.showItemLevel = false end
    elseif mode == "off_char" then
      -- Next: Off Acc
      DB.showItemLevel = false
      if CHARDB then CHARDB.showItemLevel = nil end
    else
      -- Next: On Acc
      DB.showItemLevel = true
      if CHARDB then CHARDB.showItemLevel = nil end
    end

    RefreshIlvlButtons()
  end)

  RefreshIlvlButtons()

  local mailNotify, mailCombat

  local reset = CreateFrame("Button", nil, lootPanel, "UIPanelButtonTemplate")
  reset:SetSize(120, 22)

  -- Center the reset button across the panel, but keep the same vertical placement.
  local resetRow = CreateFrame("Frame", nil, lootPanel)
  resetRow:SetHeight(1)
  resetRow:SetPoint("TOP", ilvlRow, "BOTTOM", 0, -10)
  resetRow:SetPoint("LEFT", lootPanel, "LEFT", 0, 0)
  resetRow:SetPoint("RIGHT", lootPanel, "RIGHT", 0, 0)

  reset:SetPoint("TOP", resetRow, "TOP", 0, 0)
  reset:SetText("Reset Defaults")
  reset:SetScript("OnClick", function()
    fr0z3nUI_LootItDB = {}
    fr0z3nUI_LootItCharDB = {}
    EnsureDB()
    ApplyFilters()
    UpdateMailNotifier()
    do
      local mode
      if CHARDB and CHARDB.enabledOverride == true then
        mode = "on"
      elseif CHARDB and CHARDB.enabledOverride == false then
        mode = "off"
      elseif DB and DB.enabled then
        mode = "acc"
      else
        mode = "off"
      end
      enableModeBtn:SetText((mode == "on") and "On" or ((mode == "acc") and "On Acc" or "Off"))
    end
    SetCheckBoxChecked(hide, DB.hideLootText)
    SetCheckBoxChecked(echo, DB.echoItem)
    SetCheckBoxChecked(selfName, DB.showSelfNameAlways)
    SetCheckBoxChecked(mailNotify, DB.mailNotify and DB.mailNotify.enabled)
    SetCheckBoxChecked(mailCombat, DB.mailNotify and DB.mailNotify.showInCombat ~= false)
    combineBox:SetText(tostring(DB.lootCombineCount or 1))
    combineCur:SetOn(DB.lootCombineIncludeCurrency)
    combineGold:SetOn(DB.lootCombineIncludeGold)
    RefreshCombineModeButtons()
    RefreshMoneyButtons()
    RefreshIlvlButtons()
    prefixBox:SetText(DB.echoPrefix or "")
  end)

  local supportedLabel = lootPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")

  local supportedRow = CreateFrame("Frame", nil, lootPanel)
  supportedRow:SetHeight(1)
  supportedRow:SetPoint("TOP", reset, "BOTTOM", 0, -18)
  supportedRow:SetPoint("LEFT", lootPanel, "LEFT", 10, 0)
  supportedRow:SetPoint("RIGHT", lootPanel, "RIGHT", -10, 0)

  supportedLabel:SetPoint("TOPLEFT", supportedRow, "TOPLEFT", 0, 0)
  supportedLabel:SetText("Messages it can handle")

  local scroll = CreateFrame("ScrollFrame", nil, lootPanel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", supportedLabel, "BOTTOMLEFT", 0, -8)
  scroll:SetPoint("BOTTOMRIGHT", lootPanel, "BOTTOMRIGHT", -28, 16)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(340, 1)
  scroll:SetScrollChild(content)

  local lineHeight = 14
  local linePool = {}

  local function GetLine(i)
    if not linePool[i] then
      local fs = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      fs:SetJustifyH("LEFT")
      fs:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -((i - 1) * lineHeight))
      fs:SetPoint("RIGHT", content, "RIGHT", -2, 0)
      linePool[i] = fs
    end
    return linePool[i]
  end

  local function RefreshSupportedList()
    local lines = GetSupportedMessageLines()

    -- Keep the scroll child reasonably wide, otherwise text wraps to 1px.
    local w = (scroll.GetWidth and scroll:GetWidth()) or 340
    if type(w) == "number" and w > 40 then
      content:SetWidth(w - 26)
    else
      content:SetWidth(340)
    end

    for i = 1, #lines do
      local fs = GetLine(i)
      fs:SetText(lines[i])
      fs:Show()
    end
    for i = #lines + 1, #linePool do
      linePool[i]:Hide()
    end
    content:SetHeight(#lines * lineHeight + 6)
  end

  -- Alias tab
  do
    local function HideInputBoxTemplateArt(e)
      if not (e and e.GetRegions) then return end
      for _, region in ipairs({ e:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
          region:Hide()
        end
      end
    end

    local function SetEditFontSize(e, size)
      if not (e and e.GetFont and e.SetFont) then return end
      local font, _, flags = e:GetFont()
      if type(font) ~= "string" or font == "" then
        font = "Fonts\\FRIZQT__.TTF"
      end
      e:SetFont(font, size, flags)
    end

    local function SetFontStringSize(fs, size)
      if not (fs and fs.GetFont and fs.SetFont) then return end
      local font, _, flags = fs:GetFont()
      if type(font) ~= "string" or font == "" then
        font = "Fonts\\FRIZQT__.TTF"
      end
      fs:SetFont(font, size, flags)
    end

    local function AddPlaceholder(e, text)
      if not (e and e.CreateFontString) then return nil end
      local fs = e:CreateFontString(nil, "OVERLAY", "GameFontDisable")
      fs:SetText(tostring(text or ""))
      fs:SetPoint("LEFT", e, "LEFT", 10, 0)
      fs:SetJustifyH("LEFT")

      local function Update()
        local t = tostring(e:GetText() or "")
        if t == "" and not e:HasFocus() then
          fs:Show()
        else
          fs:Hide()
        end
      end

      e:HookScript("OnEditFocusGained", Update)
      e:HookScript("OnEditFocusLost", Update)
      e:HookScript("OnTextChanged", Update)
      Update()
      return fs
    end

    local info = aliasPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    info:SetPoint("TOP", aliasPanel, "TOP", 0, -18)
    info:SetText("Enter ItemID Below")
    SetFontStringSize(info, 15)

    local itemEdit = CreateFrame("EditBox", nil, aliasPanel, "InputBoxTemplate")
    itemEdit:SetSize(175, 38)
    itemEdit:SetPoint("TOP", info, "BOTTOM", 0, -2)
    itemEdit:SetAutoFocus(false)
    itemEdit:SetJustifyH("CENTER")
    if itemEdit.SetJustifyV then itemEdit:SetJustifyV("MIDDLE") end
    itemEdit:SetTextInsets(6, 6, 0, 0)
    SetEditFontSize(itemEdit, 16)
    HideInputBoxTemplateArt(itemEdit)
    itemEdit:SetNumeric(true)

    local MODE_ITEM = "item"
    local MODE_CURRENCY = "currency"

    local modeBtn = CreateFrame("Button", nil, aliasPanel)
    modeBtn:SetSize(18, 18)
    modeBtn:SetPoint("RIGHT", itemEdit, "LEFT", -6, 0)
    modeBtn:RegisterForClicks("LeftButtonUp")

    local modeBtnText = modeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    modeBtnText:SetPoint("CENTER", modeBtn, "CENTER", 0, 0)
    SetFontStringSize(modeBtnText, 16)

    local function GetAliasInputMode()
      EnsureDB()
      local m = DB and DB.aliasInputMode
      if m ~= MODE_ITEM and m ~= MODE_CURRENCY then
        m = MODE_ITEM
      end
      return m
    end

    local function SetAliasInputMode(m)
      EnsureDB()
      if m ~= MODE_ITEM and m ~= MODE_CURRENCY then
        m = MODE_ITEM
      end
      DB.aliasInputMode = m
    end

    local itemPH = aliasPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    itemPH:SetPoint("CENTER", itemEdit, "CENTER", 0, 0)
    itemPH:SetText("ItemID")
    itemPH:SetTextColor(1, 1, 1, 0.35)
    SetFontStringSize(itemPH, 13)

    local function UpdateItemPlaceholder()
      local txt = tostring(itemEdit:GetText() or "")
      local hasText = (txt ~= "")
      local focused = (itemEdit.HasFocus and itemEdit:HasFocus()) or false
      itemPH:SetShown((not hasText) and (not focused))
    end
    itemEdit:SetScript("OnEditFocusGained", function() itemPH:Hide() end)
    itemEdit:SetScript("OnEditFocusLost", function() UpdateItemPlaceholder() end)
    itemEdit:HookScript("OnTextChanged", function() UpdateItemPlaceholder() end)
    UpdateItemPlaceholder()

    local nameLabel = aliasPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameLabel:SetPoint("TOP", itemEdit, "BOTTOM", 0, -2)
    nameLabel:SetPoint("LEFT", aliasPanel, "LEFT", 10, 0)
    nameLabel:SetPoint("RIGHT", aliasPanel, "RIGHT", -10, 0)
    nameLabel:SetJustifyH("CENTER")
    nameLabel:SetWordWrap(true)
    nameLabel:SetText("")
    nameLabel:SetTextColor(1, 0.82, 0, 1)
    SetFontStringSize(nameLabel, 17)

    local renameEdit = CreateFrame("EditBox", nil, aliasPanel, "InputBoxTemplate")
    renameEdit:SetSize(175, 38)
    renameEdit:SetPoint("TOP", nameLabel, "BOTTOM", 0, -2)
    renameEdit:SetAutoFocus(false)
    renameEdit:SetJustifyH("CENTER")
    if renameEdit.SetJustifyV then renameEdit:SetJustifyV("MIDDLE") end
    renameEdit:SetTextInsets(6, 6, 0, 0)
    SetEditFontSize(renameEdit, 16)
    HideInputBoxTemplateArt(renameEdit)

    local aliasPH = aliasPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    aliasPH:SetPoint("CENTER", renameEdit, "CENTER", 0, 0)
    aliasPH:SetText("Short Name Here")
    aliasPH:SetTextColor(1, 1, 1, 0.35)
    SetFontStringSize(aliasPH, 13)

    local function UpdateAliasPlaceholder()
      local txt = tostring(renameEdit:GetText() or "")
      local hasText = (txt ~= "")
      local focused = (renameEdit.HasFocus and renameEdit:HasFocus()) or false
      aliasPH:SetShown((not hasText) and (not focused))
    end
    renameEdit:SetScript("OnEditFocusGained", function() aliasPH:Hide() end)
    renameEdit:SetScript("OnEditFocusLost", function() UpdateAliasPlaceholder() end)
    renameEdit:HookScript("OnTextChanged", function() UpdateAliasPlaceholder() end)
    UpdateAliasPlaceholder()

    local status = aliasPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOP", renameEdit, "BOTTOM", 0, -2)
    status:SetPoint("LEFT", aliasPanel, "LEFT", 10, 0)
    status:SetPoint("RIGHT", aliasPanel, "RIGHT", -10, 0)
    status:SetJustifyH("CENTER")
    status:SetTextColor(1, 0.55, 0.1, 1)
    status:SetText("Type/Paste an ID above")
    SetFontStringSize(status, 13)

    local BTN_W, BTN_H, BTN_GAP = 120, 22, 10
    local ADD_ROW_X = (BTN_W / 2) + (BTN_GAP / 2)

    local btnAcc = CreateFrame("Button", nil, aliasPanel, "UIPanelButtonTemplate")
    btnAcc:SetSize(BTN_W, BTN_H)
    btnAcc:SetPoint("BOTTOM", aliasPanel, "BOTTOM", -ADD_ROW_X, 18)
    btnAcc:SetText("Account")
    btnAcc:Disable()
    btnAcc:RegisterForClicks("LeftButtonUp")

    do
      local fs = btnAcc.GetFontString and btnAcc:GetFontString()
      if fs then
        SetFontStringSize(fs, 13)
      end
    end

    local btnChar = CreateFrame("Button", nil, aliasPanel, "UIPanelButtonTemplate")
    btnChar:SetSize(BTN_W, BTN_H)
    btnChar:SetPoint("BOTTOM", aliasPanel, "BOTTOM", ADD_ROW_X, 18)
    btnChar:SetText("Character")
    btnChar:Disable()
    btnChar:RegisterForClicks("LeftButtonUp")

    do
      local fs = btnChar.GetFontString and btnChar:GetFontString()
      if fs then
        SetFontStringSize(fs, 13)
      end
    end

    local function SetButtonColor(btn, label, color)
      if not btn then return end
      if color == "yellow" then
        btn:SetText("|cffffff00" .. label .. "|r")
      elseif color == "red" then
        btn:SetText("|cffff0000" .. label .. "|r")
      else
        btn:SetText(label)
      end
    end

    local function Trim(s)
      s = tostring(s or "")
      return s:gsub("^%s+", ""):gsub("%s+$", "")
    end

    local function GetValidID()
      local txt = tostring(itemEdit:GetText() or "")
      local n = tonumber(txt)
      if n and n > 0 then
        return n
      end
      return nil
    end

    local function SetNameLabelColorForItem(id)
      if not id then
        nameLabel:SetTextColor(1, 0.82, 0, 1)
        return
      end

      local quality
      if C_Item and C_Item.GetItemInfo then
        local _, _, q = C_Item.GetItemInfo(id)
        quality = q
      end

      if type(quality) == "number" then
        local c = _G and rawget(_G, "ITEM_QUALITY_COLORS")
        c = (type(c) == "table") and c[quality] or nil
        if c and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
          nameLabel:SetTextColor(c.r, c.g, c.b, 1)
          return
        end
      end

      nameLabel:SetTextColor(1, 0.82, 0, 1)
    end

    local function SetNameLabelColorForCurrency()
      -- Rare blue
      nameLabel:SetTextColor(0, 0.44, 0.87, 1)
    end

    local function GetDisplayNameForID(mode, id)
      if not id then return nil end
      if mode == MODE_CURRENCY then
        if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
          local info = C_CurrencyInfo.GetCurrencyInfo(id)
          if info and type(info.name) == "string" and info.name ~= "" then
            return info.name
          end
        end
        return "CurrencyID: " .. tostring(id)
      end

      if C_Item and C_Item.GetItemInfo then
        local name = C_Item.GetItemInfo(id)
        if type(name) == "string" and name ~= "" then
          return name
        end
      end
      return "ItemID: " .. tostring(id)
    end

    local function GetAliasState(mode, id)
      EnsureDB()

      local out = {
        char = { text = nil, disabled = false },
        acc = { text = nil, disabled = false },
        addon = { text = nil, disabled = false },
      }

      if mode == MODE_CURRENCY then
        if CHARDB and type(CHARDB.currencyAliases) == "table" then
          out.char.text = CHARDB.currencyAliases[id]
        end
        if CHARDB and type(CHARDB.currencyAliasDisabledChar) == "table" then
          out.char.disabled = (CHARDB.currencyAliasDisabledChar[id] == true)
        end

        if DB and type(DB.currencyAliases) == "table" then
          out.acc.text = DB.currencyAliases[id]
        end
        if DB and type(DB.currencyAliasDisabledAccount) == "table" then
          out.acc.disabled = (DB.currencyAliasDisabledAccount[id] == true)
        end

        out.addon.text = ADDON_CURRENCY_ALIASES[id]
        if DB and type(DB.currencyAliasDisabledAddon) == "table" then
          out.addon.disabled = (DB.currencyAliasDisabledAddon[id] == true)
        end
      else
        if CHARDB and type(CHARDB.linkAliases) == "table" then
          out.char.text = CHARDB.linkAliases[id]
        end
        if CHARDB and type(CHARDB.linkAliasDisabledChar) == "table" then
          out.char.disabled = (CHARDB.linkAliasDisabledChar[id] == true)
        end

        if DB and type(DB.linkAliases) == "table" then
          out.acc.text = DB.linkAliases[id]
        end
        if DB and type(DB.linkAliasDisabledAccount) == "table" then
          out.acc.disabled = (DB.linkAliasDisabledAccount[id] == true)
        end

        out.addon.text = ADDON_LINK_ALIASES[id]
        if DB and type(DB.linkAliasDisabledAddon) == "table" then
          out.addon.disabled = (DB.linkAliasDisabledAddon[id] == true)
        end
      end

      return out
    end

    local function AnyAliasExists(st)
      if not st then return false end
      if type(st.acc.text) == "string" and st.acc.text ~= "" then return true end
      if type(st.addon.text) == "string" and st.addon.text ~= "" then return true end
      if type(st.char.text) == "string" and st.char.text ~= "" then return true end
      return false
    end

    local function GetEffectiveAlias(mode, id)
      local st = GetAliasState(mode, id)

      -- Per-character disable suppresses all sources.
      if st.char.disabled then
        return nil, nil
      end

      if type(st.char.text) == "string" and st.char.text ~= "" then
        return st.char.text, "Character"
      end
      if type(st.acc.text) == "string" and st.acc.text ~= "" and not st.acc.disabled then
        return st.acc.text, "Account"
      end
      if type(st.addon.text) == "string" and st.addon.text ~= "" and not st.addon.disabled then
        return st.addon.text, "Addon"
      end

      return nil, nil
    end

    local function GetEditSeedAlias(mode, id)
      local st = GetAliasState(mode, id)
      if type(st.acc.text) == "string" and st.acc.text ~= "" then
        return st.acc.text, "Account"
      end
      if type(st.addon.text) == "string" and st.addon.text ~= "" then
        return st.addon.text, "Addon"
      end
      if type(st.char.text) == "string" and st.char.text ~= "" then
        return st.char.text, "Character"
      end
      return "", nil
    end

    local function SyncUI()
      local mode = GetAliasInputMode()
      aliasPanel._aliasMode = mode
      local id = GetValidID()
      aliasPanel._aliasID = id

      if aliasPanel._aliasBaseline == nil then
        aliasPanel._aliasBaseline = ""
      end

      if not id then
        nameLabel:SetText("")
        status:SetText("Type/Paste an ID above")
        btnAcc:Disable()
        btnChar:Disable()
        SetButtonColor(btnAcc, "Account", nil)
        SetButtonColor(btnChar, "Character", nil)
        return
      end

      nameLabel:SetText(GetDisplayNameForID(mode, id) or "")
      if mode == MODE_CURRENCY then
        SetNameLabelColorForCurrency()
      else
        SetNameLabelColorForItem(id)
      end

      local st = GetAliasState(mode, id)
      local exists = AnyAliasExists(st)

      local activeText, activeSource = GetEffectiveAlias(mode, id)
      if activeText then
        -- Keep status instructional; details are already visible via the name + alias box.
      else
      end

      -- Seed rename box and baseline when not actively editing.
      if not renameEdit:HasFocus() then
        local seedText = select(1, GetEditSeedAlias(mode, id))
        renameEdit:SetText(tostring(seedText or ""))
        renameEdit:HighlightText()
        aliasPanel._aliasBaseline = Trim(seedText)
      end

      local current = Trim(renameEdit:GetText())
      local baseline = Trim(aliasPanel._aliasBaseline)
      local edited = (current ~= baseline)

      if not exists then
        -- Input - Doesn't exist: Account Active / Character Inactive.
        btnAcc:Enable()
        btnChar:Disable()
        SetButtonColor(btnAcc, "Account", nil)
        SetButtonColor(btnChar, "Character", nil)
        status:SetText("Type an Alias, Click Account to Save")
        return
      end

      if edited then
        -- Alias edited: Account Yellow / Character Inactive.
        btnAcc:Enable()
        btnChar:Disable()
        SetButtonColor(btnAcc, "Account", "yellow")
        SetButtonColor(btnChar, "Character", nil)
        status:SetText("Click Account to Save")
        return
      end

      -- Input - Exists, no edit: Account Red (remove from both), Character Red/Yellow (toggle char disable).
      btnAcc:Enable()
      btnChar:Enable()
      SetButtonColor(btnAcc, "Account", "red")
      SetButtonColor(btnChar, "Character", st.char.disabled and "yellow" or "red")

      if st.char.disabled then
        status:SetText("Click Character to Enable, Account to Remove")
      else
        status:SetText("Click Character to Disable, Account to Remove")
      end
    end

    local function RemoveFromBoth(mode, id)
      EnsureDB()
      if not id then return end

      if mode == MODE_CURRENCY then
        DB.currencyAliases = (type(DB.currencyAliases) == "table") and DB.currencyAliases or {}
        DB.currencyAliasDisabledAccount = (type(DB.currencyAliasDisabledAccount) == "table") and DB.currencyAliasDisabledAccount or {}
        DB.currencyAliasDisabledAddon = (type(DB.currencyAliasDisabledAddon) == "table") and DB.currencyAliasDisabledAddon or {}

        CHARDB.currencyAliases = (type(CHARDB.currencyAliases) == "table") and CHARDB.currencyAliases or {}
        CHARDB.currencyAliasDisabledChar = (type(CHARDB.currencyAliasDisabledChar) == "table") and CHARDB.currencyAliasDisabledChar or {}

        DB.currencyAliases[id] = nil
        DB.currencyAliasDisabledAccount[id] = nil
        CHARDB.currencyAliases[id] = nil
        CHARDB.currencyAliasDisabledChar[id] = nil

        if ADDON_CURRENCY_ALIASES and ADDON_CURRENCY_ALIASES[id] then
          DB.currencyAliasDisabledAddon[id] = true
        end

        Print(PREFIX .. string.format("Alias removed (Currency): %d", id))
      else
        DB.linkAliases = (type(DB.linkAliases) == "table") and DB.linkAliases or {}
        DB.linkAliasDisabledAccount = (type(DB.linkAliasDisabledAccount) == "table") and DB.linkAliasDisabledAccount or {}
        DB.linkAliasDisabledAddon = (type(DB.linkAliasDisabledAddon) == "table") and DB.linkAliasDisabledAddon or {}

        CHARDB.linkAliases = (type(CHARDB.linkAliases) == "table") and CHARDB.linkAliases or {}
        CHARDB.linkAliasDisabledChar = (type(CHARDB.linkAliasDisabledChar) == "table") and CHARDB.linkAliasDisabledChar or {}

        DB.linkAliases[id] = nil
        DB.linkAliasDisabledAccount[id] = nil
        CHARDB.linkAliases[id] = nil
        CHARDB.linkAliasDisabledChar[id] = nil

        if ADDON_LINK_ALIASES and ADDON_LINK_ALIASES[id] then
          DB.linkAliasDisabledAddon[id] = true
        end

        Print(PREFIX .. string.format("Alias removed: %d", id))
      end
      aliasPanel._aliasBaseline = ""
    end

    local function SaveToAccount(mode, id)
      EnsureDB()
      if not id then return end

      local txt = Trim(renameEdit:GetText())
      if txt == "" then
        RemoveFromBoth(mode, id)
        return
      end

      if mode == MODE_CURRENCY then
        DB.currencyAliases = (type(DB.currencyAliases) == "table") and DB.currencyAliases or {}
        DB.currencyAliasDisabledAccount = (type(DB.currencyAliasDisabledAccount) == "table") and DB.currencyAliasDisabledAccount or {}
        DB.currencyAliasDisabledAddon = (type(DB.currencyAliasDisabledAddon) == "table") and DB.currencyAliasDisabledAddon or {}

        DB.currencyAliases[id] = txt
        DB.currencyAliasDisabledAccount[id] = nil
        DB.currencyAliasDisabledAddon[id] = nil

        Print(PREFIX .. string.format("Alias set (Account, Currency): %d -> %s", id, txt))
      else
        DB.linkAliases = (type(DB.linkAliases) == "table") and DB.linkAliases or {}
        DB.linkAliasDisabledAccount = (type(DB.linkAliasDisabledAccount) == "table") and DB.linkAliasDisabledAccount or {}
        DB.linkAliasDisabledAddon = (type(DB.linkAliasDisabledAddon) == "table") and DB.linkAliasDisabledAddon or {}

        DB.linkAliases[id] = txt
        DB.linkAliasDisabledAccount[id] = nil
        DB.linkAliasDisabledAddon[id] = nil

        Print(PREFIX .. string.format("Alias set (Account): %d -> %s", id, txt))
      end
      aliasPanel._aliasBaseline = txt
    end

    local function ToggleCharDisable(mode, id)
      EnsureDB()
      if not id then return end

      if mode == MODE_CURRENCY then
        CHARDB.currencyAliasDisabledChar = (type(CHARDB.currencyAliasDisabledChar) == "table") and CHARDB.currencyAliasDisabledChar or {}
        if CHARDB.currencyAliasDisabledChar[id] then
          CHARDB.currencyAliasDisabledChar[id] = nil
          Print(PREFIX .. string.format("Alias enabled (Character, Currency): %d", id))
        else
          CHARDB.currencyAliasDisabledChar[id] = true
          Print(PREFIX .. string.format("Alias disabled (Character, Currency): %d", id))
        end
      else
        CHARDB.linkAliasDisabledChar = (type(CHARDB.linkAliasDisabledChar) == "table") and CHARDB.linkAliasDisabledChar or {}
        if CHARDB.linkAliasDisabledChar[id] then
          CHARDB.linkAliasDisabledChar[id] = nil
          Print(PREFIX .. string.format("Alias enabled (Character): %d", id))
        else
          CHARDB.linkAliasDisabledChar[id] = true
          Print(PREFIX .. string.format("Alias disabled (Character): %d", id))
        end
      end
    end

    local function UpdateModeUI()
      local mode = GetAliasInputMode()
      if mode == MODE_CURRENCY then
        info:SetText("Enter CurrencyID Below")
        itemPH:SetText("CurrencyID")
        modeBtnText:SetText("C")
        modeBtnText:SetTextColor(0, 0.44, 0.87, 1)
      else
        info:SetText("Enter ItemID Below")
        itemPH:SetText("ItemID")
        modeBtnText:SetText("I")
        modeBtnText:SetTextColor(0.64, 0.21, 0.93, 1)
      end
      itemEdit:SetText("")
      renameEdit:SetText("")
      aliasPanel._aliasBaseline = ""
      UpdateItemPlaceholder()
      UpdateAliasPlaceholder()
    end

    modeBtn:SetScript("OnClick", function()
      local cur = GetAliasInputMode()
      if cur == MODE_CURRENCY then
        SetAliasInputMode(MODE_ITEM)
      else
        SetAliasInputMode(MODE_CURRENCY)
      end
      UpdateModeUI()
      SyncUI()
    end)

    itemEdit:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      SyncUI()
    end)
    itemEdit:SetScript("OnTextChanged", function()
      SyncUI()
    end)

    renameEdit:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      local id = aliasPanel._aliasID or GetValidID()
      local mode = aliasPanel._aliasMode or GetAliasInputMode()
      SaveToAccount(mode, id)
      SyncUI()
    end)

    renameEdit:SetScript("OnTextChanged", function(self)
      if self and self.HasFocus and self:HasFocus() then
        SyncUI()
      end
    end)

    btnAcc:SetScript("OnClick", function()
      local id = aliasPanel._aliasID or GetValidID()
      local mode = aliasPanel._aliasMode or GetAliasInputMode()
      if not id then return end

      local st = GetAliasState(mode, id)
      local exists = AnyAliasExists(st)
      local current = Trim(renameEdit:GetText())
      local baseline = Trim(aliasPanel._aliasBaseline)
      local edited = (current ~= baseline)

      if (not exists) or edited then
        SaveToAccount(mode, id)
      else
        RemoveFromBoth(mode, id)
      end
      SyncUI()
    end)

    btnChar:SetScript("OnClick", function()
      local id = aliasPanel._aliasID or GetValidID()
      local mode = aliasPanel._aliasMode or GetAliasInputMode()
      if not id then return end

      local st = GetAliasState(mode, id)
      local exists = AnyAliasExists(st)
      if not exists then return end

      local current = Trim(renameEdit:GetText())
      local baseline = Trim(aliasPanel._aliasBaseline)
      local edited = (current ~= baseline)
      if edited then return end

      ToggleCharDisable(mode, id)
      SyncUI()
    end)

    aliasPanel.Refresh = function()
      EnsureDB()
      UpdateModeUI()
      SyncUI()
    end

    UpdateModeUI()
    SyncUI()
  end

  -- Mail tab controls
  mailNotify = CreateFrame("CheckButton", nil, mailPanel, "UICheckButtonTemplate")
  mailNotify:SetPoint("TOPLEFT", mailPanel, "TOPLEFT", 8, -6)
  SetCheckBoxText(mailNotify, "Notifier")
  mailNotify:SetScript("OnClick", function(self)
    EnsureDB()
    DB.mailNotify = DB.mailNotify or {}
    DB.mailNotify.enabled = self:GetChecked() and true or false
    UpdateMailNotifier()
  end)

  mailCombat = CreateFrame("CheckButton", nil, mailPanel, "UICheckButtonTemplate")
  mailCombat:SetPoint("LEFT", mailNotify, "RIGHT", 90, 0)
  SetCheckBoxText(mailCombat, "In combat")
  mailCombat:SetScript("OnClick", function(self)
    EnsureDB()
    DB.mailNotify = DB.mailNotify or {}
    DB.mailNotify.showInCombat = self:GetChecked() and true or false
    UpdateMailNotifier()
  end)

  -- Embedded mail model editor (replaces the old pop-out window).
  local modelUI = CreateFrame("Frame", nil, mailPanel)
  modelUI:SetPoint("TOPLEFT", mailPanel, "TOPLEFT", 8, -6)
  modelUI:SetPoint("BOTTOMRIGHT", mailPanel, "BOTTOMRIGHT", -12, 8)
  mailPanel.modelUI = modelUI

  local preview = CreateFrame("DressUpModel", nil, modelUI)
  preview:SetPoint("TOPLEFT", modelUI, "TOPLEFT", 2, 0)
  preview:SetSize(190, 250)
  modelUI.preview = preview

  local RefreshViewControls

  modelUI._repeatElapsed = 0
  modelUI:SetScript("OnUpdate", function(self, elapsed)
    EnsureDB()
    if not (DB and DB.mailNotify and DB.mailNotify.model) then return end
    local spec = DB.mailNotify.model
    if not spec.animRepeat then return end

    local interval = tonumber(spec.animRepeatSec) or 10
    if interval < 0.5 then interval = 0.5 end
    if interval > 3600 then interval = 3600 end

    self._repeatElapsed = (self._repeatElapsed or 0) + (elapsed or 0)
    if self._repeatElapsed < interval then return end
    self._repeatElapsed = 0

    local anim = tonumber(spec.anim) or 0
    if preview then
      ModelApplyAnimation(preview, anim)
    end
    if MailNotifier and MailNotifier.model then
      ModelApplyAnimation(MailNotifier.model, anim)
    end
  end)

  preview:EnableMouseWheel(true)
  preview:SetScript("OnMouseWheel", function(self, delta)
    EnsureDB()
    DB.mailNotify = DB.mailNotify or {}
    DB.mailNotify.model = DB.mailNotify.model or {}

    if IsShiftKeyDown and IsShiftKeyDown() then
      local r = tonumber(DB.mailNotify.model.rotation) or ModelGetRotation(self) or 0
      r = r + (delta * 0.20)
      DB.mailNotify.model.rotation = r
      ModelSetRotation(self, r)
    else
      local z = tonumber(DB.mailNotify.model.zoom)
      if not z then z = 1.0 end
      z = Clamp(z + (delta * 0.08), 0.20, 3.00)
      DB.mailNotify.model.zoom = z
      ModelApplyZoom(self, z)
    end
  end)

  local function NewPresetButton(text, npcID)
    local b = CreateFrame("Button", nil, modelUI, "UIPanelButtonTemplate")
    b:SetSize(110, 18)
    b:SetText(text)
    b:SetScript("OnClick", function()
      EnsureDB()
      DB.mailNotify = DB.mailNotify or {}
      DB.mailNotify.model = DB.mailNotify.model or {}
      DB.mailNotify.model.kind = "npc"
      DB.mailNotify.model.id = npcID
      modelUI.rPlayer:SetChecked(false)
      modelUI.rNPC:SetChecked(true)
      modelUI.rDisplay:SetChecked(false)
      modelUI.rFile:SetChecked(false)
      modelUI.idBox:SetEnabled(true)
      modelUI.idBox:SetText(tostring(npcID))
      ApplyMailModelToFrame(preview)
      UpdateMailNotifier()
    end)
    return b
  end

  local kindLabel = modelUI:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  kindLabel:SetPoint("TOPLEFT", preview, "TOPRIGHT", 12, 2)
  kindLabel:SetText("Type")

  local function NewRadio(text)
    local r = CreateFrame("CheckButton", nil, modelUI, "UIRadioButtonTemplate")
    SetCheckBoxText(r, text)
    return r
  end

  local rPlayer = NewRadio("Player")
  rPlayer:SetPoint("TOPLEFT", kindLabel, "BOTTOMLEFT", -2, -6)
  local rNPC = NewRadio("NPCID")
  rNPC:SetPoint("TOPLEFT", rPlayer, "BOTTOMLEFT", 0, -6)
  local rDisplay = NewRadio("DisplayID")
  rDisplay:SetPoint("TOPLEFT", rNPC, "BOTTOMLEFT", 0, -6)
  local rFile = NewRadio("FileID")
  rFile:SetPoint("TOPLEFT", rDisplay, "BOTTOMLEFT", 0, -6)
  modelUI.rPlayer, modelUI.rNPC, modelUI.rDisplay, modelUI.rFile = rPlayer, rNPC, rDisplay, rFile

  local idLabel = modelUI:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  idLabel:SetPoint("LEFT", kindLabel, "RIGHT", 64, 0)
  idLabel:SetText("ID")

  local idBox = CreateFrame("EditBox", nil, modelUI, "InputBoxTemplate")
  idBox:SetSize(110, 20)
  idBox:SetPoint("LEFT", idLabel, "RIGHT", 8, 0)
  idBox:SetAutoFocus(false)
  idBox:SetJustifyH("CENTER")
  modelUI.idBox = idBox

  local presetKaty = NewPresetButton("Katy", 132969)
  presetKaty:SetPoint("TOPLEFT", idBox, "BOTTOMLEFT", 0, -6)
  local presetDalaran = NewPresetButton("Dalaran", 104230)
  presetDalaran:SetPoint("TOPLEFT", presetKaty, "BOTTOMLEFT", 0, -4)
  local presetPlagued = NewPresetButton("Plagued", 155971)
  presetPlagued:SetPoint("TOPLEFT", presetDalaran, "BOTTOMLEFT", 0, -4)

  local function GetKind()
    if rNPC:GetChecked() then return "npc" end
    if rDisplay:GetChecked() then return "display" end
    if rFile:GetChecked() then return "file" end
    return "player"
  end

  local function SetKind(kind)
    kind = tostring(kind or "player"):lower()
    rPlayer:SetChecked(kind == "player")
    rNPC:SetChecked(kind == "npc" or kind == "creature")
    rDisplay:SetChecked(kind == "display")
    rFile:SetChecked(kind == "file")
    idBox:SetEnabled(kind ~= "player")
    if kind == "player" then
      idBox:SetText("")
    end
  end

  local function PreviewSpec()
    EnsureDB()
    local spec = DB.mailNotify and DB.mailNotify.model or {}
    local kind = GetKind()
    local id = tonumber(idBox:GetText() or "")
    spec.kind = kind
    spec.id = (kind == "player") and nil or id
    DB.mailNotify.model = spec
    ApplyMailModelToFrame(preview)
  end

  local function ApplyNotifierSizingAndAlpha()
    EnsureDB()
    DB.mailNotify = DB.mailNotify or {}
    DB.mailNotify.ui = DB.mailNotify.ui or {}

    local w = Clamp(DB.mailNotify.ui.w or 140, 40, 600)
    local h = Clamp(DB.mailNotify.ui.h or 140, 40, 600)
    local a = Clamp(DB.mailNotify.ui.alpha or 1, 0.10, 1.00)
    DB.mailNotify.ui.w, DB.mailNotify.ui.h, DB.mailNotify.ui.alpha = w, h, a

    local mn = MailNotifier or CreateMailNotifier()
    if mn then
      mn:SetSize(w, h)
      if mn.model and mn.model.SetAlpha then
        mn.model:SetAlpha(a)
      end
      if DB.mailNotify.ui and DB.mailNotify.ui.strata and mn.SetFrameStrata then
        mn:SetFrameStrata(DB.mailNotify.ui.strata)
      end
    end
  end

  local function OnRadioClick(self)
    rPlayer:SetChecked(self == rPlayer)
    rNPC:SetChecked(self == rNPC)
    rDisplay:SetChecked(self == rDisplay)
    rFile:SetChecked(self == rFile)
    SetKind(GetKind())
    PreviewSpec()
  end

  rPlayer:SetScript("OnClick", OnRadioClick)
  rNPC:SetScript("OnClick", OnRadioClick)
  rDisplay:SetScript("OnClick", OnRadioClick)
  rFile:SetScript("OnClick", OnRadioClick)
  idBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    PreviewSpec()
  end)

  local apply = CreateFrame("Button", nil, modelUI, "UIPanelButtonTemplate")
  apply:SetSize(90, 22)
  apply:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -8)
  apply:SetText("Apply")
  apply:SetScript("OnClick", function()
    PreviewSpec()
    UpdateMailNotifier()
  end)

  local reset = CreateFrame("Button", nil, modelUI, "UIPanelButtonTemplate")
  reset:SetSize(90, 22)
  reset:SetPoint("LEFT", apply, "RIGHT", 10, 0)
  reset:SetText("Reset")
  reset:SetScript("OnClick", function()
    EnsureDB()
    DB.mailNotify = DB.mailNotify or {}
    DB.mailNotify.model = DB.mailNotify.model or {}
    DB.mailNotify.model.kind = "player"
    DB.mailNotify.model.id = nil
    DB.mailNotify.model.anim = nil
    DB.mailNotify.model.rotation = 0
    DB.mailNotify.model.zoom = 1.0
    SetKind("player")
    ApplyMailModelToFrame(preview)
    UpdateMailNotifier()
    if RefreshViewControls then RefreshViewControls() end
  end)

  -- Move Notifier + In combat under Apply/Reset.
  mailNotify:ClearAllPoints()
  mailNotify:SetPoint("TOPLEFT", apply, "BOTTOMLEFT", -2, -2)
  mailCombat:ClearAllPoints()
  mailCombat:SetPoint("TOPLEFT", reset, "BOTTOMLEFT", -2, -2)

  local viewContent = CreateFrame("Frame", nil, modelUI)
  viewContent:SetPoint("TOPLEFT", rFile, "BOTTOMLEFT", -2, -10)
  viewContent:SetPoint("BOTTOMRIGHT", modelUI, "BOTTOMRIGHT", -12, 64)

  local viewLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  viewLabel:SetPoint("TOPLEFT", viewContent, "TOPLEFT", 6, -4)
  viewLabel:SetText("View")

  local wLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  wLabel:SetPoint("TOPLEFT", viewLabel, "BOTTOMLEFT", 0, -10)
  wLabel:SetText("Notifier W/H")

  local wBox = CreateFrame("EditBox", nil, viewContent, "InputBoxTemplate")
  wBox:SetSize(46, 20)
  wBox:SetPoint("LEFT", wLabel, "RIGHT", 10, 0)
  wBox:SetAutoFocus(false)
  wBox:SetJustifyH("CENTER")

  local hBox = CreateFrame("EditBox", nil, viewContent, "InputBoxTemplate")
  hBox:SetSize(46, 20)
  hBox:SetPoint("LEFT", wBox, "RIGHT", 10, 0)
  hBox:SetAutoFocus(false)
  hBox:SetJustifyH("CENTER")

  local applyWH = CreateFrame("Button", nil, viewContent, "UIPanelButtonTemplate")
  applyWH:SetSize(54, 20)
  applyWH:SetPoint("LEFT", hBox, "RIGHT", 10, 0)
  applyWH:SetText("Set")

  local alphaLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  alphaLabel:SetPoint("TOPLEFT", wLabel, "BOTTOMLEFT", 0, -12)
  alphaLabel:SetText("Alpha")

  local alphaSlider = CreateFrame("Slider", "fr0z3nUI_LootIt_MailModelPickerAlpha", viewContent, "OptionsSliderTemplate")
  alphaSlider:SetPoint("LEFT", alphaLabel, "RIGHT", 16, 0)
  alphaSlider:SetWidth(170)
  alphaSlider:SetMinMaxValues(0.10, 1.00)
  alphaSlider:SetValueStep(0.05)
  if alphaSlider.SetObeyStepOnDrag then alphaSlider:SetObeyStepOnDrag(true) end
  _G[alphaSlider:GetName() .. "Low"]:SetText("0.1")
  _G[alphaSlider:GetName() .. "High"]:SetText("1.0")
  _G[alphaSlider:GetName() .. "Text"]:SetText(" ")

  local strataLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  strataLabel:SetPoint("TOPLEFT", alphaLabel, "BOTTOMLEFT", 0, -18)
  strataLabel:SetText("Layer")

  local strataDD = CreateFrame("Frame", "fr0z3nUI_LootIt_MailModelPickerStrata", viewContent, "UIDropDownMenuTemplate")
  strataDD:SetPoint("LEFT", strataLabel, "RIGHT", -10, -2)
  UIDropDownMenu_SetWidth(strataDD, 145)

  local STRATA = {
    { key = "BACKGROUND", text = "Background" },
    { key = "LOW", text = "Low" },
    { key = "MEDIUM", text = "Medium" },
    { key = "HIGH", text = "High" },
    { key = "DIALOG", text = "Dialog" },
    { key = "FULLSCREEN", text = "Fullscreen" },
    { key = "FULLSCREEN_DIALOG", text = "Fullscreen Dialog" },
    { key = "TOOLTIP", text = "Tooltip" },
  }

  do
    local mu = _G and rawget(_G, "MenuUtil")
    if type(mu) == "table" and type(mu.CreateContextMenu) == "function" then
      local anchor = strataDD.Button or strataDD
      if anchor and anchor.SetScript then
        anchor:SetScript("OnClick", function(btn)
          mu.CreateContextMenu(btn, function(_, root)
            if root and root.CreateTitle then root:CreateTitle("Layer") end
            EnsureDB()
            DB.mailNotify = DB.mailNotify or {}
            DB.mailNotify.ui = DB.mailNotify.ui or {}
            local selected = tostring(DB.mailNotify.ui.strata or "")
            for i, s in ipairs(STRATA) do
              if root and root.CreateRadio then
                root:CreateRadio(s.text, function() return selected == s.key end, function()
                  EnsureDB()
                  DB.mailNotify = DB.mailNotify or {}
                  DB.mailNotify.ui = DB.mailNotify.ui or {}
                  DB.mailNotify.ui.strata = s.key
                  if UIDropDownMenu_SetSelectedID then UIDropDownMenu_SetSelectedID(strataDD, i) end
                  ApplyNotifierSizingAndAlpha()
                  UpdateMailNotifier()
                end)
              elseif root and root.CreateButton then
                root:CreateButton(s.text, function()
                  EnsureDB()
                  DB.mailNotify = DB.mailNotify or {}
                  DB.mailNotify.ui = DB.mailNotify.ui or {}
                  DB.mailNotify.ui.strata = s.key
                  if UIDropDownMenu_SetSelectedID then UIDropDownMenu_SetSelectedID(strataDD, i) end
                  ApplyNotifierSizingAndAlpha()
                  UpdateMailNotifier()
                end)
              end
            end
          end)
        end)
      end
    else
      UIDropDownMenu_Initialize(strataDD, function(_, level)
        if level ~= 1 then return end
        for i, s in ipairs(STRATA) do
          local info = UIDropDownMenu_CreateInfo()
          info.text = s.text
          info.func = function()
            EnsureDB()
            DB.mailNotify = DB.mailNotify or {}
            DB.mailNotify.ui = DB.mailNotify.ui or {}
            DB.mailNotify.ui.strata = s.key
            UIDropDownMenu_SetSelectedID(strataDD, i)
            ApplyNotifierSizingAndAlpha()
            UpdateMailNotifier()
          end
          UIDropDownMenu_AddButton(info, level)
        end
      end)
    end
  end

  local zoomLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  zoomLabel:SetPoint("TOPLEFT", strataLabel, "BOTTOMLEFT", 0, -18)
  zoomLabel:SetText("Zoom")

  local zoomSlider = CreateFrame("Slider", "fr0z3nUI_LootIt_MailModelPickerZoom", viewContent, "OptionsSliderTemplate")
  zoomSlider:SetPoint("LEFT", zoomLabel, "RIGHT", 18, 0)
  zoomSlider:SetWidth(170)
  zoomSlider:SetMinMaxValues(0.20, 3.00)
  zoomSlider:SetValueStep(0.05)
  if zoomSlider.SetObeyStepOnDrag then zoomSlider:SetObeyStepOnDrag(true) end
  _G[zoomSlider:GetName() .. "Low"]:SetText("0.2")
  _G[zoomSlider:GetName() .. "High"]:SetText("3.0")
  _G[zoomSlider:GetName() .. "Text"]:SetText(" ")

  local rotLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  rotLabel:SetPoint("TOPLEFT", zoomLabel, "BOTTOMLEFT", 0, -18)
  rotLabel:SetText("Rotate")

  local rotLeft = CreateFrame("Button", nil, viewContent, "UIPanelButtonTemplate")
  rotLeft:SetSize(30, 20)
  rotLeft:SetPoint("LEFT", rotLabel, "RIGHT", 16, 0)
  rotLeft:SetText("<")

  local rotReset = CreateFrame("Button", nil, viewContent, "UIPanelButtonTemplate")
  rotReset:SetSize(46, 20)
  rotReset:SetPoint("LEFT", rotLeft, "RIGHT", 8, 0)
  rotReset:SetText("Reset")

  local rotRight = CreateFrame("Button", nil, viewContent, "UIPanelButtonTemplate")
  rotRight:SetSize(30, 20)
  rotRight:SetPoint("LEFT", rotReset, "RIGHT", 8, 0)
  rotRight:SetText(">")

  local actionLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  actionLabel:SetPoint("TOPLEFT", rotLabel, "BOTTOMLEFT", 0, -12)
  actionLabel:SetText("Action")

  local actionPrev = CreateFrame("Button", nil, viewContent, "UIPanelButtonTemplate")
  actionPrev:SetSize(30, 20)
  actionPrev:SetPoint("LEFT", actionLabel, "RIGHT", 16, 0)
  actionPrev:SetText("<")

  local actionBox = CreateFrame("EditBox", nil, viewContent, "InputBoxTemplate")
  actionBox:SetSize(46, 20)
  actionBox:SetPoint("LEFT", actionPrev, "RIGHT", 8, 0)
  actionBox:SetAutoFocus(false)
  actionBox:SetJustifyH("CENTER")
  actionBox:SetNumeric(true)
  actionBox:SetText("0")

  local actionNext = CreateFrame("Button", nil, viewContent, "UIPanelButtonTemplate")
  actionNext:SetSize(30, 20)
  actionNext:SetPoint("LEFT", actionBox, "RIGHT", 8, 0)
  actionNext:SetText(">")

  local actionRandom = CreateFrame("CheckButton", nil, viewContent, "UICheckButtonTemplate")
  SetCheckBoxText(actionRandom, "")
  if actionRandom.Text then actionRandom.Text:Hide() end
  if actionRandom.text then actionRandom.text:Hide() end
  actionRandom:SetSize(24, 24)
  actionRandom:SetPoint("LEFT", actionNext, "RIGHT", 10, 0)

  local randomLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  randomLabel:SetPoint("LEFT", actionRandom, "RIGHT", 6, 0)
  randomLabel:SetText("Random")

  local repeatCB = CreateFrame("CheckButton", nil, viewContent, "UICheckButtonTemplate")
  SetCheckBoxText(repeatCB, "")
  if repeatCB.Text then repeatCB.Text:Hide() end
  if repeatCB.text then repeatCB.text:Hide() end
  repeatCB:SetSize(24, 24)

  local repeatSecBox = CreateFrame("EditBox", nil, viewContent, "InputBoxTemplate")
  repeatSecBox:SetSize(50, 20)
  repeatSecBox:SetPoint("TOPLEFT", actionBox, "BOTTOMLEFT", 0, -10)
  repeatSecBox:SetAutoFocus(false)
  repeatSecBox:SetJustifyH("CENTER")
  repeatSecBox:SetNumeric(true)
  repeatSecBox:SetText("10")

  repeatCB:SetPoint("RIGHT", repeatSecBox, "LEFT", -6, 0)

  local repeatLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  repeatLabel:SetPoint("LEFT", repeatSecBox, "RIGHT", 6, 0)
  repeatLabel:SetText("sec. Repeat")

  local mailTest = CreateFrame("Button", nil, modelUI, "UIPanelButtonTemplate")
  mailTest:SetSize(110, 18)
  mailTest:SetPoint("TOPLEFT", presetPlagued, "BOTTOMLEFT", 0, -6)
  mailTest:SetText("Test")
  mailTest:SetScript("OnClick", function()
    EnsureDB()
    DB.mailNotify = DB.mailNotify or {}
    DB.mailNotify.enabled = true
    local mf = CreateMailNotifier()
    if DB.mailNotify and DB.mailNotify.ui then
      mf:ClearAllPoints()
      mf:SetPoint(DB.mailNotify.ui.point or "TOPRIGHT", UIParent, DB.mailNotify.ui.point or "TOPRIGHT", DB.mailNotify.ui.x or 0, DB.mailNotify.ui.y or 0)
    end
    if (DB.mailNotify.showInCombat == false) and InCombatLockdown and InCombatLockdown() then
      mf:Hide()
      Print("Mail notifier: hidden in combat.")
      return
    end
    ApplyMailModelToFrame(mf.model)
    mf:Show()
    Print("Mail notifier: shown (test).")
  end)

  RefreshViewControls = function()
    EnsureDB()
    DB.mailNotify = DB.mailNotify or {}
    DB.mailNotify.ui = DB.mailNotify.ui or {}
    DB.mailNotify.model = DB.mailNotify.model or {}

    local w = Clamp(DB.mailNotify.ui.w or 140, 40, 600)
    local h = Clamp(DB.mailNotify.ui.h or 140, 40, 600)
    local a = Clamp(DB.mailNotify.ui.alpha or 1, 0.10, 1.00)
    wBox:SetText(tostring(math.floor(w + 0.5)))
    hBox:SetText(tostring(math.floor(h + 0.5)))
    alphaSlider:SetValue(a)

    local want = tostring(DB.mailNotify.ui.strata or "HIGH")
    local selected = 4
    for i, s in ipairs(STRATA) do
      if s.key == want then selected = i break end
    end
    UIDropDownMenu_SetSelectedID(strataDD, selected)

    local z = Clamp(DB.mailNotify.model.zoom or 1.0, 0.20, 3.00)
    zoomSlider:SetValue(z)

    local anim = tonumber(DB.mailNotify.model.anim) or 0
    actionBox:SetText(tostring(anim))
    SetCheckBoxChecked(actionRandom, DB.mailNotify.model.animRandom)

    local repeatOn = (DB.mailNotify.model.animRepeat == true)
    local sec = tonumber(DB.mailNotify.model.animRepeatSec) or 10
    if sec < 1 then sec = 1 end
    if sec > 3600 then sec = 3600 end
    repeatSecBox:SetText(tostring(math.floor(sec + 0.5)))
    SetCheckBoxChecked(repeatCB, repeatOn)
    repeatSecBox:SetEnabled(repeatOn)

    local randomOn = (DB.mailNotify.model.animRandom == true)
    local allowManual = (not randomOn)
    actionBox:SetEnabled(allowManual)
    actionPrev:SetEnabled(allowManual)
    actionNext:SetEnabled(allowManual)
  end

  applyWH:SetScript("OnClick", function()
    EnsureDB()
    DB.mailNotify = DB.mailNotify or {}
    DB.mailNotify.ui = DB.mailNotify.ui or {}

    DB.mailNotify.ui.w = tonumber(wBox:GetText() or "") or DB.mailNotify.ui.w or 140
    DB.mailNotify.ui.h = tonumber(hBox:GetText() or "") or DB.mailNotify.ui.h or 140
    ApplyNotifierSizingAndAlpha()
    UpdateMailNotifier()
    RefreshViewControls()
  end)

  wBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    applyWH:Click()
  end)
  hBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    applyWH:Click()
  end)

  alphaSlider:SetScript("OnValueChanged", function(_, v)
    EnsureDB()
    DB.mailNotify = DB.mailNotify or {}
    DB.mailNotify.ui = DB.mailNotify.ui or {}
    DB.mailNotify.ui.alpha = Clamp(v, 0.10, 1.00)
    ApplyNotifierSizingAndAlpha()
    if preview and preview.SetAlpha then
      preview:SetAlpha(DB.mailNotify.ui.alpha)
    end
    UpdateMailNotifier()
  end)

  zoomSlider:SetScript("OnValueChanged", function(_, v)
    EnsureDB()
    DB.mailNotify = DB.mailNotify or {}
    DB.mailNotify.model = DB.mailNotify.model or {}
    DB.mailNotify.model.zoom = Clamp(v, 0.20, 3.00)
    ApplyMailModelToFrame(preview)
    UpdateMailNotifier()
  end)

  local function NudgeRotation(dir)
    EnsureDB()
    DB.mailNotify = DB.mailNotify or {}
    DB.mailNotify.model = DB.mailNotify.model or {}
    local r = tonumber(DB.mailNotify.model.rotation) or ModelGetRotation(preview) or 0
    r = r + (dir * 0.20)
    DB.mailNotify.model.rotation = r
    ModelSetRotation(preview, r)
    UpdateMailNotifier()
  end

  rotLeft:SetScript("OnClick", function() NudgeRotation(-1) end)
  rotRight:SetScript("OnClick", function() NudgeRotation(1) end)
  rotReset:SetScript("OnClick", function()
    EnsureDB()
    DB.mailNotify = DB.mailNotify or {}
    DB.mailNotify.model = DB.mailNotify.model or {}
    DB.mailNotify.model.rotation = 0
    ModelSetRotation(preview, 0)
    UpdateMailNotifier()
  end)

  local function SetAction(anim)
    EnsureDB()
    DB.mailNotify = DB.mailNotify or {}
    DB.mailNotify.model = DB.mailNotify.model or {}
    anim = tonumber(anim) or 0
    if anim < 0 then anim = 0 end
    if anim > 150 then anim = 0 end
    DB.mailNotify.model.animRandom = false
    DB.mailNotify.model.anim = anim
    actionBox:SetText(tostring(anim))
    SetCheckBoxChecked(actionRandom, false)
    actionBox:SetEnabled(true)
    actionPrev:SetEnabled(true)
    actionNext:SetEnabled(true)
    ModelApplyAnimation(preview, anim)
    UpdateMailNotifier()
  end

  actionPrev:SetScript("OnClick", function()
    EnsureDB()
    local anim = tonumber(DB.mailNotify and DB.mailNotify.model and DB.mailNotify.model.anim) or 0
    SetAction(anim - 1)
  end)

  actionNext:SetScript("OnClick", function()
    EnsureDB()
    local anim = tonumber(DB.mailNotify and DB.mailNotify.model and DB.mailNotify.model.anim) or 0
    SetAction(anim + 1)
  end)

  actionBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    SetAction(tonumber(self:GetText()) or 0)
  end)

  actionRandom:SetScript("OnClick", function(self)
    EnsureDB()
    DB.mailNotify = DB.mailNotify or {}
    DB.mailNotify.model = DB.mailNotify.model or {}

    local on = self:GetChecked() and true or false
    DB.mailNotify.model.animRandom = on

    if on then
      DB.mailNotify.model.anim = math.random(0, 150)
      actionBox:SetEnabled(false)
      actionPrev:SetEnabled(false)
      actionNext:SetEnabled(false)
    else
      local repeatOn = (DB.mailNotify.model.animRepeat == true)
      actionBox:SetEnabled(not repeatOn)
      actionPrev:SetEnabled(not repeatOn)
      actionNext:SetEnabled(not repeatOn)
    end

    ApplyMailModelToFrame(preview)
    UpdateMailNotifier()
    RefreshViewControls()
  end)

  repeatCB:SetScript("OnClick", function(self)
    EnsureDB()
    DB.mailNotify = DB.mailNotify or {}
    DB.mailNotify.model = DB.mailNotify.model or {}

    local on = self:GetChecked() and true or false
    DB.mailNotify.model.animRepeat = on
    if DB.mailNotify.model.animRepeatSec == nil then
      DB.mailNotify.model.animRepeatSec = 10
    end

    repeatSecBox:SetEnabled(on)
    RefreshViewControls()
  end)

  repeatSecBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    EnsureDB()
    DB.mailNotify = DB.mailNotify or {}
    DB.mailNotify.model = DB.mailNotify.model or {}

    local sec = tonumber(self:GetText() or "") or 10
    if sec < 1 then sec = 1 end
    if sec > 3600 then sec = 3600 end
    DB.mailNotify.model.animRepeatSec = sec
    RefreshViewControls()
  end)

  local hint = modelUI:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("BOTTOMLEFT", modelUI, "BOTTOMLEFT", 10, 10)
  hint:SetPoint("BOTTOMRIGHT", modelUI, "BOTTOMRIGHT", -10, 10)
  hint:SetJustifyH("CENTER")
  hint:SetText("Shift-click uses Katy's Stampwhistle.")

  modelUI.Refresh = function()
    EnsureDB()
    local spec = DB.mailNotify and DB.mailNotify.model or {}
    SetKind(spec.kind or "player")
    if spec.id then idBox:SetText(tostring(spec.id)) end
    ApplyMailModelToFrame(preview)
    ApplyNotifierSizingAndAlpha()
    if RefreshViewControls then RefreshViewControls() end
  end

  frame:SetScript("OnShow", function(self)
    EnsureDB()
    do
      local mode
      if CHARDB and CHARDB.enabledOverride == true then
        mode = "on"
      elseif CHARDB and CHARDB.enabledOverride == false then
        mode = "off"
      elseif DB and DB.enabled then
        mode = "acc"
      else
        mode = "off"
      end
      enableModeBtn:SetText((mode == "on") and "On" or ((mode == "acc") and "On Acc" or "Off"))
    end
    SetCheckBoxChecked(hide, DB.hideLootText)
    SetCheckBoxChecked(echo, DB.echoItem)
    SetCheckBoxChecked(selfName, DB.showSelfNameAlways)
    RefreshIlvlButtons()
    combineBox:SetText(tostring(DB.lootCombineCount or 1))
    combineCur:SetOn(DB.lootCombineIncludeCurrency)
    combineGold:SetOn(DB.lootCombineIncludeGold)
    RefreshCombineModeButtons()
    SetCheckBoxChecked(mailNotify, DB.mailNotify and DB.mailNotify.enabled)
    SetCheckBoxChecked(mailCombat, DB.mailNotify and DB.mailNotify.showInCombat ~= false)
    RefreshMoneyButtons()
    UIDropDownMenu_SetSelectedID(outputDD, DB.outputChatFrame or 1)
    prefixBox:SetText(DB.echoPrefix or "")
    if DB.ui then
      self:ClearAllPoints()
      self:SetPoint(DB.ui.point or "CENTER", UIParent, DB.ui.point or "CENTER", DB.ui.x or 0, DB.ui.y or 0)
    end
    SelectTab(self._activeTab or "loot")
    if aliasPanel and aliasPanel.Refresh then
      aliasPanel:Refresh()
    end
    if otherPanel and otherPanel.Refresh then
      otherPanel:Refresh()
    end
    if mailPanel and mailPanel.modelUI and mailPanel.modelUI.Refresh then
      mailPanel.modelUI:Refresh()
    end
    RefreshSupportedList()
  end)

  frame:SetScript("OnHide", function()
    ApplyMailNotifierInteractivity()
  end)

  -- Default tab
  SelectTab("loot")

  frame:Hide()
  ConfigUI = frame
  return frame
end

local function ToggleConfigUI()
  EnsureDB()
  local frame = CreateConfigUI()
  if frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
  end
end

local MailModelPicker

local function Clamp(v, minV, maxV)
  if v == nil then return minV end
  v = tonumber(v)
  if not v then return minV end
  if minV and v < minV then return minV end
  if maxV and v > maxV then return maxV end
  return v
end

local MAIL_TOY_KATY_STAMPWHISTLE = 156833

local function FormatCooldown(seconds)
  seconds = tonumber(seconds) or 0
  if seconds <= 0 then return "0s" end
  if SecondsToTime then
    return SecondsToTime(seconds)
  end
  local m = math.floor(seconds / 60)
  local s = math.floor(seconds % 60)
  if m > 0 then
    return string.format("%dm %ds", m, s)
  end
  return string.format("%ds", s)
end

local function TryUseKatyStampwhistle()
  local id = MAIL_TOY_KATY_STAMPWHISTLE

  if PlayerHasToy and not PlayerHasToy(id) then
    Print("You don't have Katy's Stampwhistle.")
    return
  end

  local start, duration, enable
  if C_ToyBox and C_ToyBox.GetToyCooldown then
    start, duration, enable = C_ToyBox.GetToyCooldown(id)
  end

  if enable == 1 and start and duration and duration > 0 then
    local remaining = (start + duration) - (GetTime and GetTime() or 0)
    if remaining and remaining > 0.25 then
      Print("Katy is busy rn, try again in [" .. FormatCooldown(remaining) .. "]")
      return
    end
  end

  if C_ToyBox and C_ToyBox.IsToyUsable and not C_ToyBox.IsToyUsable(id) then
    -- Can be unusable due to being indoors, etc.
    Print("Katy is not usable right now.")
    return
  end

  if UseToy then
    UseToy(id)
  elseif C_ToyBox and C_ToyBox.UseToy then
    C_ToyBox.UseToy(id)
  else
    Print("Cannot use toys on this client.")
  end
end

ApplyMailNotifierInteractivity = function()
  if not MailNotifier then return end
  local pickerOpen = IsMailEditorOpen()
  local shiftDown = (IsShiftKeyDown and IsShiftKeyDown()) and true or false
  local interactive = pickerOpen or shiftDown

  -- Clickthrough unless holding Shift, except when the picker is open (always interactive then).
  MailNotifier:EnableMouse(true)
  if MailNotifier.SetMouseClickEnabled then
    local ok = pcall(MailNotifier.SetMouseClickEnabled, MailNotifier, interactive)
    if not ok then
      pcall(MailNotifier.SetMouseClickEnabled, MailNotifier, "LeftButton", interactive)
      pcall(MailNotifier.SetMouseClickEnabled, MailNotifier, "RightButton", interactive)
    end
  elseif MailNotifier.SetPropagateMouseClicks then
    pcall(MailNotifier.SetPropagateMouseClicks, MailNotifier, not interactive)
  else
    MailNotifier:EnableMouse(interactive)
  end

  -- Lock movement when the editor is closed.
  if not pickerOpen then
    MailNotifier:SetMovable(false)
    MailNotifier:RegisterForDrag()
  else
    MailNotifier:SetMovable(true)
    MailNotifier:RegisterForDrag("LeftButton")
  end
end

ModelGetRotation = function(modelFrame)
  if not modelFrame then return 0 end
  if modelFrame.GetFacing then
    return modelFrame:GetFacing() or 0
  end
  if modelFrame.GetRotation then
    return modelFrame:GetRotation() or 0
  end
  return 0
end

ModelSetRotation = function(modelFrame, rotation)
  if not modelFrame then return end
  rotation = tonumber(rotation) or 0
  if modelFrame.SetFacing then
    modelFrame:SetFacing(rotation)
    return
  end
  if modelFrame.SetRotation then
    modelFrame:SetRotation(rotation)
    return
  end
end

ModelApplyZoom = function(modelFrame, zoom)
  if not modelFrame then return end
  zoom = tonumber(zoom)
  if not zoom then return end

  -- Retail APIs differ across model frame types; try most common ones first.
  if modelFrame.SetCamDistanceScale then
    modelFrame:SetCamDistanceScale(zoom)
    return
  end
  if modelFrame.SetPortraitZoom then
    modelFrame:SetPortraitZoom(zoom)
    return
  end
  if modelFrame.SetModelScale then
    modelFrame:SetModelScale(zoom)
    return
  end
end

ModelApplyAnimation = function(modelFrame, anim)
  if not modelFrame then return end
  anim = tonumber(anim)
  if anim == nil then return end
  if modelFrame.SetAnimation then
    modelFrame:SetAnimation(anim)
  end
end

ApplyMailModelToFrame = function(modelFrame)
  if not modelFrame then return end
  EnsureDB()
  local spec = DB and DB.mailNotify and DB.mailNotify.model or nil
  local kind = spec and tostring(spec.kind or "player"):lower() or "player"
  local id = spec and spec.id or nil

  if modelFrame.ClearModel then modelFrame:ClearModel() end

  if kind == "player" then
    if modelFrame.SetUnit then
      modelFrame:SetUnit("player")
    end
  elseif kind == "display" then
    local displayID = tonumber(id)
    if displayID and modelFrame.SetDisplayInfo then
      modelFrame:SetDisplayInfo(displayID)
    end
  elseif kind == "file" then
    local fileID = tonumber(id)
    if fileID and modelFrame.SetModelByFileID then
      modelFrame:SetModelByFileID(fileID)
    end
  elseif kind == "npc" or kind == "creature" then
    local npcID = tonumber(id)
    if npcID and modelFrame.SetCreature then
      modelFrame:SetCreature(npcID)
    end
  end

  local rotation = spec and tonumber(spec.rotation)
  if rotation then
    ModelSetRotation(modelFrame, rotation)
  end
  local zoom = spec and tonumber(spec.zoom)
  if zoom then
    ModelApplyZoom(modelFrame, zoom)
  end

  local anim = spec and tonumber(spec.anim)
  if anim ~= nil then
    ModelApplyAnimation(modelFrame, anim)
  end

  local a = DB and DB.mailNotify and DB.mailNotify.ui and tonumber(DB.mailNotify.ui.alpha)
  if a and modelFrame.SetAlpha then
    modelFrame:SetAlpha(Clamp(a, 0.10, 1.00))
  end
end

CreateMailNotifier = function()
  if MailNotifier then return MailNotifier end

  EnsureDB()
  DB.mailNotify = DB.mailNotify or {}
  DB.mailNotify.ui = DB.mailNotify.ui or {}
  local w = Clamp(DB.mailNotify.ui.w or 140, 40, 600)
  local h = Clamp(DB.mailNotify.ui.h or 140, 40, 600)
  local a = Clamp(DB.mailNotify.ui.alpha or 1, 0.10, 1.00)
  DB.mailNotify.ui.w, DB.mailNotify.ui.h, DB.mailNotify.ui.alpha = w, h, a

  -- Minimal notifier: just the model.
  local frame = CreateFrame("Frame", "fr0z3nUI_LootIt_MailNotifier", UIParent)
  frame:SetSize(w, h)
  frame:SetFrameStrata(DB.mailNotify.ui.strata or "HIGH")
  if frame.SetAlpha then frame:SetAlpha(1) end
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)

  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    if not IsMailEditorOpen() then return end
    self:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    EnsureDB()
    DB.mailNotify = DB.mailNotify or {}
    DB.mailNotify.ui = DB.mailNotify.ui or {}
    local point, _, _, x, y = self:GetPoint(1)
    DB.mailNotify.ui.point = point or "TOPRIGHT"
    DB.mailNotify.ui.x = x or 0
    DB.mailNotify.ui.y = y or 0
  end)

  local model = CreateFrame("DressUpModel", nil, frame)
  model:SetAllPoints(frame)
  if model.EnableMouse then model:EnableMouse(false) end
  ApplyMailModelToFrame(model)
  if model.SetAlpha then
    model:SetAlpha(a)
  end
  frame.model = model

  frame:SetScript("OnMouseUp", function(_, button)
    if not (IsShiftKeyDown and IsShiftKeyDown()) then return end
    if button == "LeftButton" then
      TryUseKatyStampwhistle()
    elseif button == "RightButton" then
      ToggleConfigUI()
    end
  end)

  frame:HookScript("OnShow", function(self)
    EnsureDB()
    if not (DB and DB.mailNotify) then return end
    if (DB.mailNotify.showInCombat == false) and InCombatLockdown and InCombatLockdown() then
      self:Hide()
    end
  end)

  frame:EnableMouseWheel(true)
  frame:SetScript("OnMouseWheel", function(self, delta)
    if not self.model then return end
    EnsureDB()
    DB.mailNotify = DB.mailNotify or {}
    DB.mailNotify.model = DB.mailNotify.model or {}

    if IsShiftKeyDown and IsShiftKeyDown() then
      local r = tonumber(DB.mailNotify.model.rotation) or ModelGetRotation(self.model) or 0
      r = r + (delta * 0.20)
      DB.mailNotify.model.rotation = r
      ModelSetRotation(self.model, r)
    else
      local z = tonumber(DB.mailNotify.model.zoom)
      if not z then z = 1.0 end
      z = Clamp(z + (delta * 0.08), 0.20, 3.00)
      DB.mailNotify.model.zoom = z
      ModelApplyZoom(self.model, z)
    end
  end)

  frame._lastShiftDown = nil
  frame._repeatElapsed = 0
  frame:SetScript("OnUpdate", function(self, elapsed)
    local s = (IsShiftKeyDown and IsShiftKeyDown()) and true or false
    if self._lastShiftDown ~= s then
      self._lastShiftDown = s
      ApplyMailNotifierInteractivity()
    end

    -- Repeat action tick (only when the editor is NOT open; editor drives repeat when open).
    if IsMailEditorOpen() then return end

    EnsureDB()
    if not (DB and DB.mailNotify and DB.mailNotify.model) then return end
    local spec = DB.mailNotify.model
    if not spec.animRepeat then return end

    local interval = tonumber(spec.animRepeatSec) or 10
    if interval < 0.5 then interval = 0.5 end
    if interval > 3600 then interval = 3600 end

    self._repeatElapsed = (self._repeatElapsed or 0) + (elapsed or 0)
    if self._repeatElapsed < interval then return end
    self._repeatElapsed = 0

    local anim = tonumber(spec.anim) or 0
    if self.model then
      ModelApplyAnimation(self.model, anim)
    end
  end)

  ApplyMailNotifierInteractivity()

  frame:Hide()
  MailNotifier = frame
  return frame
end

UpdateMailNotifier = function()
  EnsureDB()
  if not (DB and DB.mailNotify and DB.mailNotify.enabled) then
    if MailNotifier then MailNotifier:Hide() end
    return
  end

  local frame = CreateMailNotifier()
  if DB.mailNotify and DB.mailNotify.ui then
    frame:ClearAllPoints()
    frame:SetPoint(DB.mailNotify.ui.point or "TOPRIGHT", UIParent, DB.mailNotify.ui.point or "TOPRIGHT", DB.mailNotify.ui.x or 0, DB.mailNotify.ui.y or 0)
    local w = Clamp(DB.mailNotify.ui.w or frame:GetWidth() or 140, 40, 600)
    local h = Clamp(DB.mailNotify.ui.h or frame:GetHeight() or 140, 40, 600)
    local currentAlpha = (frame.model and frame.model.GetAlpha and frame.model:GetAlpha()) or 1
    local a = Clamp(DB.mailNotify.ui.alpha or currentAlpha, 0.10, 1.00)
    DB.mailNotify.ui.w, DB.mailNotify.ui.h, DB.mailNotify.ui.alpha = w, h, a
    frame:SetSize(w, h)
    if frame.model and frame.model.SetAlpha then
      frame.model:SetAlpha(a)
    end
    frame:SetFrameStrata(DB.mailNotify.ui.strata or frame:GetFrameStrata() or "HIGH")
  end

  ApplyMailNotifierInteractivity()

  if not (DB.mailNotify.showInCombat) and InCombatLockdown and InCombatLockdown() then
    frame:Hide()
    return
  end

  local has = false
  if HasNewMail then
    has = HasNewMail() and true or false
  end

  if has then
    -- If random action is enabled, roll only when mail first appears.
    frame._hadMail = (frame._hadMail == true)
    if not frame._hadMail then
      frame._hadMail = true
      if DB and DB.mailNotify and DB.mailNotify.model and DB.mailNotify.model.animRandom then
        DB.mailNotify.model.anim = math.random(0, 150)
      end
    end

    ApplyMailModelToFrame(frame.model)
    frame:Show()
  else
    frame._hadMail = false
    frame:Hide()
  end
end

OpenMailModelPicker = function()
  EnsureDB()

  if not MailModelPicker then
    local frame = CreateFrame("Frame", "fr0z3nUI_LootIt_MailModelPicker", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(560, 390)
    frame:SetFrameStrata("DIALOG")
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame.TitleText:SetText("LootIt Mail Model")

    local preview = CreateFrame("DressUpModel", nil, frame)
    preview:SetPoint("TOPLEFT", frame.InsetBg, "TOPLEFT", 10, -10)
    preview:SetSize(190, 270)
    frame.preview = preview

    local RefreshViewControls

    frame._repeatElapsed = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
      EnsureDB()
      if not (DB and DB.mailNotify and DB.mailNotify.model) then return end
      local spec = DB.mailNotify.model
      if not spec.animRepeat then return end

      local interval = tonumber(spec.animRepeatSec) or 10
      if interval < 0.5 then interval = 0.5 end
      if interval > 3600 then interval = 3600 end

      self._repeatElapsed = (self._repeatElapsed or 0) + (elapsed or 0)
      if self._repeatElapsed < interval then return end
      self._repeatElapsed = 0

      local anim = tonumber(spec.anim) or 0
      if preview then
        ModelApplyAnimation(preview, anim)
      end
      if MailNotifier and MailNotifier.model then
        ModelApplyAnimation(MailNotifier.model, anim)
      end
    end)

    preview:EnableMouseWheel(true)
    preview:SetScript("OnMouseWheel", function(self, delta)
      EnsureDB()
      DB.mailNotify = DB.mailNotify or {}
      DB.mailNotify.model = DB.mailNotify.model or {}

      if IsShiftKeyDown and IsShiftKeyDown() then
        local r = tonumber(DB.mailNotify.model.rotation) or ModelGetRotation(self) or 0
        r = r + (delta * 0.20)
        DB.mailNotify.model.rotation = r
        ModelSetRotation(self, r)
      else
        local z = tonumber(DB.mailNotify.model.zoom)
        if not z then z = 1.0 end
        z = Clamp(z + (delta * 0.08), 0.20, 3.00)
        DB.mailNotify.model.zoom = z
        ModelApplyZoom(self, z)
      end
    end)

    local function NewPresetButton(text, npcID)
      local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
      b:SetSize(110, 18)
      b:SetText(text)
      b:SetScript("OnClick", function()
        EnsureDB()
        DB.mailNotify = DB.mailNotify or {}
        DB.mailNotify.model = DB.mailNotify.model or {}
        DB.mailNotify.model.kind = "npc"
        DB.mailNotify.model.id = npcID
        frame.rPlayer:SetChecked(false)
        frame.rNPC:SetChecked(true)
        frame.rDisplay:SetChecked(false)
        frame.rFile:SetChecked(false)
        frame.idBox:SetEnabled(true)
        frame.idBox:SetText(tostring(npcID))
        ApplyMailModelToFrame(preview)
        UpdateMailNotifier()
      end)
      return b
    end

    -- Type + ID (left column) anchored next to the model.
    local kindLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    kindLabel:SetPoint("TOPLEFT", preview, "TOPRIGHT", 12, -4)
    kindLabel:SetText("Type")

    local function NewRadio(text)
      local r = CreateFrame("CheckButton", nil, frame, "UIRadioButtonTemplate")
      SetCheckBoxText(r, text)
      return r
    end

    local rPlayer = NewRadio("Player")
    rPlayer:SetPoint("TOPLEFT", kindLabel, "BOTTOMLEFT", -2, -8)
    local rNPC = NewRadio("NPCID")
    rNPC:SetPoint("TOPLEFT", rPlayer, "BOTTOMLEFT", 0, -6)
    local rDisplay = NewRadio("DisplayID")
    rDisplay:SetPoint("TOPLEFT", rNPC, "BOTTOMLEFT", 0, -6)
    local rFile = NewRadio("FileID")
    rFile:SetPoint("TOPLEFT", rDisplay, "BOTTOMLEFT", 0, -6)
    frame.rPlayer, frame.rNPC, frame.rDisplay, frame.rFile = rPlayer, rNPC, rDisplay, rFile

    -- ID box up next to Type label.
    local idLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    idLabel:SetPoint("LEFT", kindLabel, "RIGHT", 64, 0)
    idLabel:SetText("ID")

    local idBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    idBox:SetSize(110, 20)
    idBox:SetPoint("LEFT", idLabel, "RIGHT", 8, 0)
    idBox:SetAutoFocus(false)
    idBox:SetJustifyH("CENTER")
    frame.idBox = idBox

    -- Presets (no Defaults label): right column under the ID box.
    local presetKaty = NewPresetButton("Katy", 132969)
    presetKaty:SetPoint("TOPLEFT", idBox, "BOTTOMLEFT", 0, -6)
    local presetDalaran = NewPresetButton("Dalaran", 104230)
    presetDalaran:SetPoint("TOPLEFT", presetKaty, "BOTTOMLEFT", 0, -4)
    local presetPlagued = NewPresetButton("Plagued", 155971)
    presetPlagued:SetPoint("TOPLEFT", presetDalaran, "BOTTOMLEFT", 0, -4)

    local function GetKind()
      if rNPC:GetChecked() then return "npc" end
      if rDisplay:GetChecked() then return "display" end
      if rFile:GetChecked() then return "file" end
      return "player"
    end

    local function SetKind(kind)
      kind = tostring(kind or "player"):lower()
      rPlayer:SetChecked(kind == "player")
      rNPC:SetChecked(kind == "npc" or kind == "creature")
      rDisplay:SetChecked(kind == "display")
      rFile:SetChecked(kind == "file")
      idBox:SetEnabled(kind ~= "player")
      if kind == "player" then
        idBox:SetText("")
      end
    end

    local function Preview()
      EnsureDB()
      local spec = DB.mailNotify and DB.mailNotify.model or {}
      local kind = GetKind()
      local id = tonumber(idBox:GetText() or "")
      spec.kind = kind
      spec.id = (kind == "player") and nil or id
      DB.mailNotify.model = spec
      ApplyMailModelToFrame(preview)
    end

    -- Defaults list moved next to viewer.

    local function ApplyNotifierSizingAndAlpha()
      EnsureDB()
      DB.mailNotify = DB.mailNotify or {}
      DB.mailNotify.ui = DB.mailNotify.ui or {}

      local w = Clamp(DB.mailNotify.ui.w or 140, 40, 600)
      local h = Clamp(DB.mailNotify.ui.h or 140, 40, 600)
      local a = Clamp(DB.mailNotify.ui.alpha or 1, 0.10, 1.00)
      DB.mailNotify.ui.w, DB.mailNotify.ui.h, DB.mailNotify.ui.alpha = w, h, a

      local mn = MailNotifier or CreateMailNotifier()
      if mn then
        mn:SetSize(w, h)
        if mn.model and mn.model.SetAlpha then
          mn.model:SetAlpha(a)
        end
        if DB.mailNotify.ui and DB.mailNotify.ui.strata and mn.SetFrameStrata then
          mn:SetFrameStrata(DB.mailNotify.ui.strata)
        end
      end
    end

    local function OnRadioClick(self)
      rPlayer:SetChecked(self == rPlayer)
      rNPC:SetChecked(self == rNPC)
      rDisplay:SetChecked(self == rDisplay)
      rFile:SetChecked(self == rFile)
      SetKind(GetKind())
      Preview()
    end

    rPlayer:SetScript("OnClick", OnRadioClick)
    rNPC:SetScript("OnClick", OnRadioClick)
    rDisplay:SetScript("OnClick", OnRadioClick)
    rFile:SetScript("OnClick", OnRadioClick)
    idBox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      Preview()
    end)

    local apply = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    apply:SetSize(90, 22)
    apply:SetPoint("BOTTOMLEFT", frame.InsetBg, "BOTTOMLEFT", 10, 34)
    apply:SetText("Apply")
    apply:SetScript("OnClick", function()
      Preview()
      UpdateMailNotifier()
    end)

    local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    reset:SetSize(90, 22)
    reset:SetPoint("LEFT", apply, "RIGHT", 10, 0)
    reset:SetText("Reset")
    reset:SetScript("OnClick", function()
      EnsureDB()
      DB.mailNotify = DB.mailNotify or {}
      DB.mailNotify.model = DB.mailNotify.model or {}
      DB.mailNotify.model.kind = "player"
      DB.mailNotify.model.id = nil
      DB.mailNotify.model.anim = nil
      DB.mailNotify.model.rotation = 0
      DB.mailNotify.model.zoom = 1.0
      SetKind("player")
      ApplyMailModelToFrame(preview)
      UpdateMailNotifier()
      if RefreshViewControls then RefreshViewControls() end
    end)

    -- View controls live inside the window, right of the preview.
    local viewContent = CreateFrame("Frame", nil, frame)
    viewContent:SetPoint("TOPLEFT", rFile, "BOTTOMLEFT", -2, -14)
    viewContent:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", -10, 58)

    local viewLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    viewLabel:SetPoint("TOPLEFT", viewContent, "TOPLEFT", 6, -4)
    viewLabel:SetText("View")

    local wLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    wLabel:SetPoint("TOPLEFT", viewLabel, "BOTTOMLEFT", 0, -10)
    wLabel:SetText("Notifier W/H")

    local wBox = CreateFrame("EditBox", nil, viewContent, "InputBoxTemplate")
    wBox:SetSize(46, 20)
    wBox:SetPoint("LEFT", wLabel, "RIGHT", 10, 0)
    wBox:SetAutoFocus(false)
    wBox:SetJustifyH("CENTER")

    local hBox = CreateFrame("EditBox", nil, viewContent, "InputBoxTemplate")
    hBox:SetSize(46, 20)
    hBox:SetPoint("LEFT", wBox, "RIGHT", 10, 0)
    hBox:SetAutoFocus(false)
    hBox:SetJustifyH("CENTER")

    local applyWH = CreateFrame("Button", nil, viewContent, "UIPanelButtonTemplate")
    applyWH:SetSize(54, 20)
    applyWH:SetPoint("LEFT", hBox, "RIGHT", 10, 0)
    applyWH:SetText("Set")

    local alphaLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    alphaLabel:SetPoint("TOPLEFT", wLabel, "BOTTOMLEFT", 0, -12)
    alphaLabel:SetText("Alpha")

    local alphaSlider = CreateFrame("Slider", "fr0z3nUI_LootIt_MailModelPickerAlpha", viewContent, "OptionsSliderTemplate")
    alphaSlider:SetPoint("LEFT", alphaLabel, "RIGHT", 16, 0)
    alphaSlider:SetWidth(200)
    alphaSlider:SetMinMaxValues(0.10, 1.00)
    alphaSlider:SetValueStep(0.05)
    if alphaSlider.SetObeyStepOnDrag then alphaSlider:SetObeyStepOnDrag(true) end
    _G[alphaSlider:GetName() .. "Low"]:SetText("0.1")
    _G[alphaSlider:GetName() .. "High"]:SetText("1.0")
    _G[alphaSlider:GetName() .. "Text"]:SetText(" ")

    local strataLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    strataLabel:SetPoint("TOPLEFT", alphaLabel, "BOTTOMLEFT", 0, -18)
    strataLabel:SetText("Layer")

    local strataDD = CreateFrame("Frame", "fr0z3nUI_LootIt_MailModelPickerStrata", viewContent, "UIDropDownMenuTemplate")
    strataDD:SetPoint("LEFT", strataLabel, "RIGHT", -10, -2)
    UIDropDownMenu_SetWidth(strataDD, 160)

    local STRATA = {
      { key = "BACKGROUND", text = "Background" },
      { key = "LOW", text = "Low" },
      { key = "MEDIUM", text = "Medium" },
      { key = "HIGH", text = "High" },
      { key = "DIALOG", text = "Dialog" },
      { key = "FULLSCREEN", text = "Fullscreen" },
      { key = "FULLSCREEN_DIALOG", text = "Fullscreen Dialog" },
      { key = "TOOLTIP", text = "Tooltip" },
    }

    UIDropDownMenu_Initialize(strataDD, function(_, level)
      if level ~= 1 then return end
      for i, s in ipairs(STRATA) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = s.text
        info.func = function()
          EnsureDB()
          DB.mailNotify = DB.mailNotify or {}
          DB.mailNotify.ui = DB.mailNotify.ui or {}
          DB.mailNotify.ui.strata = s.key
          UIDropDownMenu_SetSelectedID(strataDD, i)
          ApplyNotifierSizingAndAlpha()
          UpdateMailNotifier()
        end
        UIDropDownMenu_AddButton(info, level)
      end
    end)

    local zoomLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    zoomLabel:SetPoint("TOPLEFT", strataLabel, "BOTTOMLEFT", 0, -18)
    zoomLabel:SetText("Zoom")

    local zoomSlider = CreateFrame("Slider", "fr0z3nUI_LootIt_MailModelPickerZoom", viewContent, "OptionsSliderTemplate")
    zoomSlider:SetPoint("LEFT", zoomLabel, "RIGHT", 18, 0)
    zoomSlider:SetWidth(200)
    zoomSlider:SetMinMaxValues(0.20, 3.00)
    zoomSlider:SetValueStep(0.05)
    if zoomSlider.SetObeyStepOnDrag then zoomSlider:SetObeyStepOnDrag(true) end
    _G[zoomSlider:GetName() .. "Low"]:SetText("0.2")
    _G[zoomSlider:GetName() .. "High"]:SetText("3.0")
    _G[zoomSlider:GetName() .. "Text"]:SetText(" ")

    local rotLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rotLabel:SetPoint("TOPLEFT", zoomLabel, "BOTTOMLEFT", 0, -18)
    rotLabel:SetText("Rotate")

    local rotLeft = CreateFrame("Button", nil, viewContent, "UIPanelButtonTemplate")
    rotLeft:SetSize(30, 20)
    rotLeft:SetPoint("LEFT", rotLabel, "RIGHT", 16, 0)
    rotLeft:SetText("<")

    local rotRight = CreateFrame("Button", nil, viewContent, "UIPanelButtonTemplate")
    rotRight:SetSize(30, 20)
    rotRight:SetPoint("LEFT", rotLeft, "RIGHT", 6, 0)
    rotRight:SetText(">")

    local rotReset = CreateFrame("Button", nil, viewContent, "UIPanelButtonTemplate")
    rotReset:SetSize(54, 20)
    rotReset:SetPoint("LEFT", rotRight, "RIGHT", 10, 0)
    rotReset:SetText("Reset")

    local actionLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    actionLabel:SetPoint("TOPLEFT", rotLabel, "BOTTOMLEFT", 0, -12)
    actionLabel:SetText("Action")

    local actionPrev = CreateFrame("Button", nil, viewContent, "UIPanelButtonTemplate")
    actionPrev:SetSize(30, 20)
    actionPrev:SetPoint("LEFT", actionLabel, "RIGHT", 16, 0)
    actionPrev:SetText("<")

    local actionBox = CreateFrame("EditBox", nil, viewContent, "InputBoxTemplate")
    actionBox:SetSize(46, 20)
    actionBox:SetPoint("LEFT", actionPrev, "RIGHT", 8, 0)
    actionBox:SetAutoFocus(false)
    actionBox:SetJustifyH("CENTER")
    actionBox:SetNumeric(true)
    actionBox:SetText("0")

    local actionNext = CreateFrame("Button", nil, viewContent, "UIPanelButtonTemplate")
    actionNext:SetSize(30, 20)
    actionNext:SetPoint("LEFT", actionBox, "RIGHT", 8, 0)
    actionNext:SetText(">")

    local actionRandom = CreateFrame("CheckButton", nil, viewContent, "UICheckButtonTemplate")
    SetCheckBoxText(actionRandom, "Random")
    actionRandom:SetPoint("LEFT", actionNext, "RIGHT", 12, 0)

    local repeatCB = CreateFrame("CheckButton", nil, viewContent, "UICheckButtonTemplate")
    SetCheckBoxText(repeatCB, "Repeat")
    repeatCB:SetPoint("TOPLEFT", actionRandom, "BOTTOMLEFT", 0, -8)

    local repeatSecBox = CreateFrame("EditBox", nil, viewContent, "InputBoxTemplate")
    repeatSecBox:SetSize(46, 20)
    repeatSecBox:SetPoint("TOPLEFT", actionBox, "BOTTOMLEFT", 0, -10)
    repeatSecBox:SetAutoFocus(false)
    repeatSecBox:SetJustifyH("CENTER")
    repeatSecBox:SetNumeric(true)
    repeatSecBox:SetText("10")

    local repeatSecLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    repeatSecLabel:SetPoint("LEFT", repeatSecBox, "RIGHT", 6, 0)
    repeatSecLabel:SetText("sec")

    RefreshViewControls = function()
      EnsureDB()
      DB.mailNotify = DB.mailNotify or {}
      DB.mailNotify.ui = DB.mailNotify.ui or {}
      DB.mailNotify.model = DB.mailNotify.model or {}

      local w = Clamp(DB.mailNotify.ui.w or 140, 40, 600)
      local h = Clamp(DB.mailNotify.ui.h or 140, 40, 600)
      local a = Clamp(DB.mailNotify.ui.alpha or 1, 0.10, 1.00)
      wBox:SetText(tostring(math.floor(w + 0.5)))
      hBox:SetText(tostring(math.floor(h + 0.5)))
      alphaSlider:SetValue(a)

      local want = tostring(DB.mailNotify.ui.strata or "HIGH")
      local selected = 4
      for i, s in ipairs(STRATA) do
        if s.key == want then selected = i break end
      end
      UIDropDownMenu_SetSelectedID(strataDD, selected)

      local z = Clamp(DB.mailNotify.model.zoom or 1.0, 0.20, 3.00)
      zoomSlider:SetValue(z)

      local anim = tonumber(DB.mailNotify.model.anim) or 0
      actionBox:SetText(tostring(anim))
      SetCheckBoxChecked(actionRandom, DB.mailNotify.model.animRandom)

      local repeatOn = (DB.mailNotify.model.animRepeat == true)
      local sec = tonumber(DB.mailNotify.model.animRepeatSec) or 10
      if sec < 1 then sec = 1 end
      if sec > 3600 then sec = 3600 end
      repeatSecBox:SetText(tostring(math.floor(sec + 0.5)))
      SetCheckBoxChecked(repeatCB, repeatOn)
      repeatSecBox:SetEnabled(repeatOn)

      local randomOn = (DB.mailNotify.model.animRandom == true)
      local allowManual = (not randomOn)
      actionBox:SetEnabled(allowManual)
      actionPrev:SetEnabled(allowManual)
      actionNext:SetEnabled(allowManual)
    end

    applyWH:SetScript("OnClick", function()
      EnsureDB()
      DB.mailNotify = DB.mailNotify or {}
      DB.mailNotify.ui = DB.mailNotify.ui or {}

      DB.mailNotify.ui.w = tonumber(wBox:GetText() or "") or DB.mailNotify.ui.w or 140
      DB.mailNotify.ui.h = tonumber(hBox:GetText() or "") or DB.mailNotify.ui.h or 140
      ApplyNotifierSizingAndAlpha()
      UpdateMailNotifier()
      RefreshViewControls()
    end)

    wBox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      applyWH:Click()
    end)
    hBox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      applyWH:Click()
    end)

    alphaSlider:SetScript("OnValueChanged", function(_, v)
      EnsureDB()
      DB.mailNotify = DB.mailNotify or {}
      DB.mailNotify.ui = DB.mailNotify.ui or {}
      DB.mailNotify.ui.alpha = Clamp(v, 0.10, 1.00)
      ApplyNotifierSizingAndAlpha()
      if preview and preview.SetAlpha then
        preview:SetAlpha(DB.mailNotify.ui.alpha)
      end
      UpdateMailNotifier()
    end)

    zoomSlider:SetScript("OnValueChanged", function(_, v)
      EnsureDB()
      DB.mailNotify = DB.mailNotify or {}
      DB.mailNotify.model = DB.mailNotify.model or {}
      DB.mailNotify.model.zoom = Clamp(v, 0.20, 3.00)
      ApplyMailModelToFrame(preview)
      UpdateMailNotifier()
    end)

    local function NudgeRotation(dir)
      EnsureDB()
      DB.mailNotify = DB.mailNotify or {}
      DB.mailNotify.model = DB.mailNotify.model or {}
      local r = tonumber(DB.mailNotify.model.rotation) or ModelGetRotation(preview) or 0
      r = r + (dir * 0.20)
      DB.mailNotify.model.rotation = r
      ModelSetRotation(preview, r)
      UpdateMailNotifier()
    end

    rotLeft:SetScript("OnClick", function() NudgeRotation(-1) end)
    rotRight:SetScript("OnClick", function() NudgeRotation(1) end)
    rotReset:SetScript("OnClick", function()
      EnsureDB()
      DB.mailNotify = DB.mailNotify or {}
      DB.mailNotify.model = DB.mailNotify.model or {}
      DB.mailNotify.model.rotation = 0
      ModelSetRotation(preview, 0)
      UpdateMailNotifier()
    end)

    local function SetAction(anim)
      EnsureDB()
      DB.mailNotify = DB.mailNotify or {}
      DB.mailNotify.model = DB.mailNotify.model or {}
      anim = tonumber(anim) or 0
      if anim < 0 then anim = 0 end
      if anim > 150 then anim = 0 end
      DB.mailNotify.model.animRandom = false
      DB.mailNotify.model.anim = anim
      actionBox:SetText(tostring(anim))
      SetCheckBoxChecked(actionRandom, false)
      actionBox:SetEnabled(true)
      actionPrev:SetEnabled(true)
      actionNext:SetEnabled(true)
      ModelApplyAnimation(preview, anim)
      UpdateMailNotifier()
    end

    actionPrev:SetScript("OnClick", function()
      EnsureDB()
      local anim = tonumber(DB.mailNotify and DB.mailNotify.model and DB.mailNotify.model.anim) or 0
      SetAction(anim - 1)
    end)

    actionNext:SetScript("OnClick", function()
      EnsureDB()
      local anim = tonumber(DB.mailNotify and DB.mailNotify.model and DB.mailNotify.model.anim) or 0
      SetAction(anim + 1)
    end)

    actionBox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      SetAction(tonumber(self:GetText()) or 0)
    end)

    actionRandom:SetScript("OnClick", function(self)
      EnsureDB()
      DB.mailNotify = DB.mailNotify or {}
      DB.mailNotify.model = DB.mailNotify.model or {}

      local on = self:GetChecked() and true or false
      DB.mailNotify.model.animRandom = on

      if on then
        DB.mailNotify.model.anim = math.random(0, 150)
        actionBox:SetEnabled(false)
        actionPrev:SetEnabled(false)
        actionNext:SetEnabled(false)
      else
        local repeatOn = (DB.mailNotify.model.animRepeat == true)
        actionBox:SetEnabled(not repeatOn)
        actionPrev:SetEnabled(not repeatOn)
        actionNext:SetEnabled(not repeatOn)
      end

      ApplyMailModelToFrame(preview)
      UpdateMailNotifier()
      RefreshViewControls()
    end)

    repeatCB:SetScript("OnClick", function(self)
      EnsureDB()
      DB.mailNotify = DB.mailNotify or {}
      DB.mailNotify.model = DB.mailNotify.model or {}

      local on = self:GetChecked() and true or false
      DB.mailNotify.model.animRepeat = on
      if DB.mailNotify.model.animRepeatSec == nil then
        DB.mailNotify.model.animRepeatSec = 10
      end

      repeatSecBox:SetEnabled(on)

      -- Repeat does not affect Random; it just re-applies the current action.
      RefreshViewControls()
    end)

    repeatSecBox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      EnsureDB()
      DB.mailNotify = DB.mailNotify or {}
      DB.mailNotify.model = DB.mailNotify.model or {}

      local sec = tonumber(self:GetText() or "") or 10
      if sec < 1 then sec = 1 end
      if sec > 3600 then sec = 3600 end
      DB.mailNotify.model.animRepeatSec = sec
      RefreshViewControls()
    end)

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMLEFT", frame.InsetBg, "BOTTOMLEFT", 10, 12)
    hint:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", -10, 12)
    hint:SetJustifyH("LEFT")
    hint:SetText("Shift-click uses Katy's Stampwhistle.")

    frame:SetScript("OnShow", function(self)
      EnsureDB()
      local spec = DB.mailNotify and DB.mailNotify.model or {}
      SetKind(spec.kind or "player")
      if spec.id then idBox:SetText(tostring(spec.id)) end
      ApplyMailModelToFrame(preview)
      ApplyNotifierSizingAndAlpha()
      RefreshViewControls()
      ApplyMailNotifierInteractivity()
    end)

    frame:SetScript("OnHide", function()
      ApplyMailNotifierInteractivity()
    end)

    frame:Hide()
    MailModelPicker = frame
  end

  if MailModelPicker:IsShown() then
    MailModelPicker:Hide()
  else
    if MailModelPicker.ClearAllPoints and ConfigUI and ConfigUI.IsShown and ConfigUI:IsShown() then
      MailModelPicker:ClearAllPoints()
      MailModelPicker:SetPoint("TOPLEFT", ConfigUI, "TOPRIGHT", 12, -20)
    end
    MailModelPicker:Show()
    if MailModelPicker.Raise then MailModelPicker:Raise() end
    if ConfigUI and ConfigUI.GetFrameLevel and MailModelPicker.SetFrameLevel then
      MailModelPicker:SetFrameLevel(ConfigUI:GetFrameLevel() + 20)
    end
  end

  ApplyMailNotifierInteractivity()
end

SLASH_FR0Z3NUI_LOOTIT1 = "/fli"
SLASH_FR0Z3NUI_LOOTIT2 = "/lootit"
SlashCmdList.FR0Z3NUI_LOOTIT = function(msg)
  EnsureDB()
  msg = tostring(msg or "")
  local cmd, rest = msg:match("^(%S+)%s*(.-)$")
  cmd = (cmd and cmd:lower()) or ""

  local function Status()
    local mode
    if CHARDB and CHARDB.enabledOverride == true then
      mode = "on"
    elseif CHARDB and CHARDB.enabledOverride == false then
      mode = "off"
    elseif DB and DB.enabled then
      mode = "acc"
    else
      mode = "off"
    end
    local e = (IsEnabled() and "on" or "off")
    local h = (DB.hideLootText and "on" or "off")
    local x = (DB.echoItem and "on" or "off")
    Print(string.format("enabled=%s (%s), hide=%s, echo=%s", e, (mode == "acc") and "acc" or "char", h, x))
  end

  if cmd == "" then
    ToggleConfigUI()
    return
  end

  if cmd == "?" or cmd == "help" then
    Print("/fli - open options")
    Print("/fli on|off|toggle")
    Print("/fli hide on|off")
    Print("/fli echo on|off")
    Print("/fli selfname on|off")
    Print("/fli prefix <text>|default (leave blank to clear)")
    Print("/fli mail on|off|toggle|test")
    Print("/fli mail model player")
    Print("/fli mail model katy")
    Print("/fli mail model dalaran")
    Print("/fli mail model plagued")
    Print("/fli mail model npc <id>")
    Print("/fli mail model display <id>")
    Print("/fli mail model file <id>")
    Print("/fli alias set [acc|char] <itemID> <text>")
    Print("/fli alias del [acc|char] <itemID>")
    Print("/fli alias list")
    Print("/fli status")
    return
  end
  if cmd == "alias" then
    local parts = {}
    for w in tostring(rest or ""):gmatch("%S+") do
      parts[#parts + 1] = w
    end

    local sub = (parts[1] and parts[1]:lower()) or ""
    local function NormalizeScope(s)
      s = (s and s:lower()) or ""
      if s == "acc" or s == "account" then return "acc" end
      if s == "char" or s == "character" then return "char" end
      return nil
    end

    local function AliasStatusLine(scopeLabel)
      local a = 0
      local t
      if scopeLabel == "char" then
        t = (CHARDB and type(CHARDB.linkAliases) == "table") and CHARDB.linkAliases or {}
      else
        t = (DB and type(DB.linkAliases) == "table") and DB.linkAliases or {}
      end
      for _ in pairs(t) do a = a + 1 end
      Print(string.format("Aliases (%s): %d", scopeLabel == "char" and "Character" or "Account", a))
      for id, text in pairs(t) do
        Print(string.format("  %d = %s", tonumber(id) or 0, tostring(text or "")))
      end
    end

    if sub == "" or sub == "list" then
      AliasStatusLine("acc")
      AliasStatusLine("char")
      return
    end

    if sub == "set" or sub == "add" then
      local scope = NormalizeScope(parts[2]) or "acc"
      local idIndex = (NormalizeScope(parts[2]) and 3) or 2
      local id = tonumber(parts[idIndex])
      local text = table.concat(parts, " ", idIndex + 1)
      if not id or id <= 0 or text == "" then
        Print("Usage: /fli alias set [acc|char] <itemID> <text>")
        return
      end

      if scope == "char" then
        CHARDB.linkAliases = (type(CHARDB.linkAliases) == "table") and CHARDB.linkAliases or {}
        CHARDB.linkAliasDisabledChar = (type(CHARDB.linkAliasDisabledChar) == "table") and CHARDB.linkAliasDisabledChar or {}
        CHARDB.linkAliases[id] = text
        CHARDB.linkAliasDisabledChar[id] = nil
        Print(string.format("Alias set (Character): %d -> %s", id, text))
      else
        DB.linkAliases = (type(DB.linkAliases) == "table") and DB.linkAliases or {}
        DB.linkAliasDisabledAccount = (type(DB.linkAliasDisabledAccount) == "table") and DB.linkAliasDisabledAccount or {}
        DB.linkAliases[id] = text
        DB.linkAliasDisabledAccount[id] = nil
        Print(string.format("Alias set (Account): %d -> %s", id, text))
      end
      return
    end

    if sub == "del" or sub == "remove" or sub == "clear" then
      local scope = NormalizeScope(parts[2]) or "acc"
      local idIndex = (NormalizeScope(parts[2]) and 3) or 2
      local id = tonumber(parts[idIndex])
      if not id or id <= 0 then
        Print("Usage: /fli alias del [acc|char] <itemID>")
        return
      end

      if scope == "char" then
        CHARDB.linkAliases = (type(CHARDB.linkAliases) == "table") and CHARDB.linkAliases or {}
        CHARDB.linkAliasDisabledChar = (type(CHARDB.linkAliasDisabledChar) == "table") and CHARDB.linkAliasDisabledChar or {}
        CHARDB.linkAliases[id] = nil
        CHARDB.linkAliasDisabledChar[id] = nil
        Print("Alias removed (Character): " .. id)
      else
        DB.linkAliases = (type(DB.linkAliases) == "table") and DB.linkAliases or {}
        DB.linkAliasDisabledAccount = (type(DB.linkAliasDisabledAccount) == "table") and DB.linkAliasDisabledAccount or {}
        DB.linkAliases[id] = nil
        DB.linkAliasDisabledAccount[id] = nil
        Print("Alias removed (Account): " .. id)
      end
      return
    end

    Print("Usage: /fli alias set|del|list")
    Print("  /fli alias set [acc|char] <itemID> <text>")
    Print("  /fli alias del [acc|char] <itemID>")
    return
  end


  if cmd == "status" then
    Status()
    return
  end

  if cmd == "repair" or cmd == "reapply" then
    ApplyFilters()
    Print(string.format("reapplied filters (enabled=%s, hide=%s, echo=%s, combine=%s)", IsEnabled() and "on" or "off", (DB and DB.hideLootText) and "on" or "off", (DB and DB.echoItem) and "on" or "off", LootCombineEnabled() and "on" or "off"))
    return
  end

  if cmd == "debugfilters" or cmd == "debug" then
    local add = _G and rawget(_G, "ChatFrame_AddMessageEventFilter")
    local rem = _G and rawget(_G, "ChatFrame_RemoveMessageEventFilter")
    Print(string.format("enabled=%s, hide=%s, echo=%s, combine=%s", IsEnabled() and "on" or "off", (DB and DB.hideLootText) and "on" or "off", (DB and DB.echoItem) and "on" or "off", LootCombineEnabled() and "on" or "off"))
    Print(string.format("ChatFrame_AddMessageEventFilter=%s", type(add)))
    Print(string.format("ChatFrame_RemoveMessageEventFilter=%s", type(rem)))
    Print("(If those are nil, chat filters cannot install yet.)")
    return
  end

  if cmd == "ui" or cmd == "config" or cmd == "options" then
    ToggleConfigUI()
    return
  end

  if cmd == "on" or cmd == "enable" then
    -- Keep slash commands account-wide (matches old behavior).
    CHARDB.enabledOverride = nil
    DB.enabled = true
    ApplyFilters()
    Status()
    return
  end

  if cmd == "off" or cmd == "disable" then
    CHARDB.enabledOverride = nil
    DB.enabled = false
    ApplyFilters()
    Status()
    return
  end

  if cmd == "toggle" then
    CHARDB.enabledOverride = nil
    DB.enabled = not DB.enabled
    ApplyFilters()
    Status()
    return
  end

  if cmd == "hide" then
    local v = (rest or ""):lower()
    DB.hideLootText = (v ~= "off" and v ~= "0" and v ~= "false")
    Status()
    return
  end

  if cmd == "echo" then
    local v = (rest or ""):lower()
    DB.echoItem = (v ~= "off" and v ~= "0" and v ~= "false")
    Status()
    return
  end

  if cmd == "selfname" then
    local v = (rest or ""):lower()
    DB.showSelfNameAlways = (v ~= "off" and v ~= "0" and v ~= "false")
    Status()
    return
  end

  if cmd == "prefix" then
    local p = tostring(rest or "")
    if p == "" then
      DB.echoPrefix = ""
    elseif p:lower() == "default" then
      DB.echoPrefix = PREFIX
    else
      DB.echoPrefix = p
    end
    Status()
    return
  end

  if cmd == "mail" then
    local v = (rest or ""):lower()
    DB.mailNotify = DB.mailNotify or {}

    if v:match("^model") then
      local _, kind, id = v:match("^(model)%s*(%S*)%s*(%S*)")
      kind = tostring(kind or ""):lower()

      if kind == "" then
        local ui = CreateConfigUI()
        ui:Show()
        if ui.SelectTab then ui.SelectTab("mail") end
        return
      end

      DB.mailNotify.model = DB.mailNotify.model or {}
      if kind == "picker" then
        local ui = CreateConfigUI()
        ui:Show()
        if ui.SelectTab then ui.SelectTab("mail") end
        return
      elseif kind == "katy" then
        DB.mailNotify.model.kind = "npc"
        DB.mailNotify.model.id = 132969
        UpdateMailNotifier()
        Print("Mail model: Katy Stampwhistle (132969)")
        return
      elseif kind == "dalaran" then
        DB.mailNotify.model.kind = "npc"
        DB.mailNotify.model.id = 104230
        UpdateMailNotifier()
        Print("Mail model: Dalaran Mailemental (104230)")
        return
      elseif kind == "plagued" then
        DB.mailNotify.model.kind = "npc"
        DB.mailNotify.model.id = 155971
        UpdateMailNotifier()
        Print("Mail model: Plagued Mailemental (155971)")
        return
      elseif kind == "player" then
        DB.mailNotify.model.kind = "player"
        DB.mailNotify.model.id = nil
        UpdateMailNotifier()
        Print("Mail model: player")
        return
      elseif kind == "display" then
        local n = tonumber(id)
        if not n then
          Print("Usage: /fli mail model display <id>")
          return
        end
        DB.mailNotify.model.kind = "display"
        DB.mailNotify.model.id = n
        UpdateMailNotifier()
        Print("Mail model: display " .. n)
        return
      elseif kind == "npc" or kind == "creature" then
        local n = tonumber(id)
        if not n then
          Print("Usage: /fli mail model npc <id>")
          return
        end
        DB.mailNotify.model.kind = "npc"
        DB.mailNotify.model.id = n
        UpdateMailNotifier()
        Print("Mail model: npc " .. n)
        return
      elseif kind == "file" then
        local n = tonumber(id)
        if not n then
          Print("Usage: /fli mail model file <id>")
          return
        end
        DB.mailNotify.model.kind = "file"
        DB.mailNotify.model.id = n
        UpdateMailNotifier()
        Print("Mail model: file " .. n)
        return
      else
        Print("Usage: /fli mail model [player|npc <id>|display <id>|file <id>]")
        return
      end
    end

    if v == "" or v == "toggle" then
      DB.mailNotify.enabled = not DB.mailNotify.enabled
      UpdateMailNotifier()
      Print("Mail notifier: " .. (DB.mailNotify.enabled and "on" or "off"))
      return
    end
    if v == "on" or v == "1" or v == "true" then
      DB.mailNotify.enabled = true
      UpdateMailNotifier()
      Print("Mail notifier: on")
      return
    end
    if v == "off" or v == "0" or v == "false" then
      DB.mailNotify.enabled = false
      UpdateMailNotifier()
      Print("Mail notifier: off")
      return
    end
    if v == "test" then
      DB.mailNotify.enabled = true
      local mf = CreateMailNotifier()
      if DB.mailNotify and DB.mailNotify.ui then
        mf:ClearAllPoints()
        mf:SetPoint(DB.mailNotify.ui.point or "TOPRIGHT", UIParent, DB.mailNotify.ui.point or "TOPRIGHT", DB.mailNotify.ui.x or 0, DB.mailNotify.ui.y or 0)
      end
      if (DB.mailNotify.showInCombat == false) and InCombatLockdown and InCombatLockdown() then
        mf:Hide()
        Print("Mail notifier: hidden in combat.")
        return
      end
      ApplyMailModelToFrame(mf.model)
      mf:Show()
      Print("Mail notifier: shown (test).")
      return
    end

    Print("Usage: /fli mail on|off|toggle|test")
    return
  end

  Print("Unknown command. Try /fli ?")
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UPDATE_PENDING_MAIL")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("LOOT_OPENED")
f:RegisterEvent("LOOT_CLOSED")
f:RegisterEvent("LOOT_READY")
f:SetScript("OnEvent", function(_, event)
  EnsureDB()
  if event == "PLAYER_LOGIN" then
    ApplyFilters()
    ApplyFiltersSoon(1)
    C_Timer.After(1, UpdateMailNotifier)
  elseif event == "PLAYER_ENTERING_WORLD" then
    ApplyFiltersSoon(0.5)
    C_Timer.After(1, UpdateMailNotifier)
  elseif event == "UPDATE_PENDING_MAIL" then
    C_Timer.After(0.5, UpdateMailNotifier)
  elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    UpdateMailNotifier()
  elseif event == "LOOT_OPENED" or event == "LOOT_READY" then
    -- Other addons can remove chat filters at runtime; re-apply here so loot lines are still rewritten.
    ApplyFilters()
    LootCombineWindowStart()
  elseif event == "LOOT_CLOSED" then
    LootCombineWindowEnd()
  end
end)
