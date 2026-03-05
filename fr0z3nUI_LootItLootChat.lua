---@diagnostic disable: undefined-global
local LI = fr0z3nUI_LootIt or {}
fr0z3nUI_LootIt = LI

LI.LootChat = LI.LootChat or {}
local LootChat = LI.LootChat

local env = nil
local DB
local CHARDB

-- Forward declarations used by AddMessage hook (must be declared before the hook is defined).
local LOOT_PATTERNS, LOOT_PREFIXES, LOOT_GROUP_PATTERNS, RECEIVE_ITEM_PATTERNS
local BuildLootPatterns
local MessageStartsWithLootPrefix

-- Forward declarations for helpers used by AddMessage hook.
local ParseCoinsFromMoneyMessage
local FormatMoney
local IsLikelyMoneyMessage

function LootChat.SetEnv(e)
  env = e or {}
end

local function EnsureRefs()
  if env and env.EnsureDB then
    env.EnsureDB()
  end
  if env and env.GetDB then
    DB = env.GetDB()
  end
  if env and env.GetCharDB then
    CHARDB = env.GetCharDB()
  end
end

local function IsSecretString(v)
  return type(issecretvalue) == "function" and issecretvalue(v)
end

local function IsNonEmptyPublicString(v)
  -- IMPORTANT: Secret string values cannot be compared (even to "") and will throw.
  -- Always check issecretvalue() BEFORE any string comparisons or string operations.
  if type(v) ~= "string" then return false end
  if IsSecretString(v) then return false end
  return v ~= ""
end

local function IsEnabled()
  return (env and env.IsEnabled and env.IsEnabled()) and true or false
end

local function IsIgnoredItemID(itemID)
  if env and env.IsIgnoredItemID then
    return env.IsIgnoredItemID(itemID) and true or false
  end
  return false
end

local function IsItemLevelEnabled()
  if env and env.IsItemLevelEnabled then
    return env.IsItemLevelEnabled() and true or false
  end
  return false
end

local function Print(msg)
  if env and env.Print then
    return env.Print(msg)
  end
end

local function PrintToChatFrame(msg, chatFrameID)
  if env and env.PrintToChatFrame then
    return env.PrintToChatFrame(msg, chatFrameID)
  end
  return Print(msg)
end

local function GetChatWindowName(id)
  id = tonumber(id)
  if not id then return nil end
  if type(GetChatWindowInfo) ~= "function" then return nil end
  local ok, name = pcall(GetChatWindowInfo, id)
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

local function DebugChatSetupEnabled()
  EnsureRefs()
  return (DB and DB.debugChatSetup) == true
end

local function DebugPrint(line)
  if not DebugChatSetupEnabled() then return end
  local outFrame = (DB and DB.outputChatFrame) or 1
  PrintToChatFrame("[LootIt ChatDebug] " .. tostring(line or ""), outFrame)
end

local addMessageHooks = nil
local addMessageInHook = false

-- Some loot-related messages bypass chat event filters and are printed directly to frames.
-- We use localized global strings to build safe prefix checks for money/currency lines.
local DIRECT_MONEY_PREFIXES
local DIRECT_CURRENCY_PREFIXES

local function BuildDirectPrefixes(keys)
  local out = {}
  for _, k in ipairs(keys or {}) do
    local gs = _G and rawget(_G, k)
    if type(gs) == "string" and gs ~= "" then
      local prefix = gs:match("^(.-)%%[sd]")
      if prefix and prefix ~= "" then
        out[#out + 1] = prefix
      end
    end
  end
  return out
end

local function MessageStartsWithAnyPrefix(msg, prefixes)
  if type(msg) ~= "string" then return false end
  if IsSecretString(msg) then return false end
  if msg == "" then return false end
  if type(prefixes) ~= "table" or #prefixes == 0 then return false end
  -- Minimal normalization: trim leading whitespace.
  local s = msg:gsub("^%s+", "")
  for _, p in ipairs(prefixes) do
    if type(p) == "string" and p ~= "" then
      local tp = p:gsub("^%s+", "")
      if tp ~= "" and s:sub(1, #tp) == tp then
        return true
      end
    end
  end
  return false
end

local function HookChatFrameAddMessage(frame)
  if not frame or type(frame.AddMessage) ~= "function" then return end

  local key = tostring(frame)
  if not addMessageHooks then addMessageHooks = {} end
  if addMessageHooks[key] then return end

  local orig = frame.AddMessage
  addMessageHooks[key] = orig

  frame.AddMessage = function(self, text, ...)
    if addMessageInHook then
      return orig(self, text, ...)
    end

    EnsureRefs()
    if not (IsEnabled() and DB and DB.hideLootText) then
      return orig(self, text, ...)
    end
    if not IsNonEmptyPublicString(text) then
      return orig(self, text, ...)
    end

    -- Catch messages that bypass chat event filters and are directly printed to frames.
    if not LOOT_PREFIXES then BuildLootPatterns() end
    if not DIRECT_MONEY_PREFIXES then
      DIRECT_MONEY_PREFIXES = BuildDirectPrefixes({ "LOOT_MONEY", "LOOT_MONEY_SPLIT" })
    end
    if not DIRECT_CURRENCY_PREFIXES then
      DIRECT_CURRENCY_PREFIXES = BuildDirectPrefixes({
        "CURRENCY_GAINED",
        "CURRENCY_GAINED_MULTIPLE",
        "CURRENCY_GAINED_SELF",
        "CURRENCY_GAINED_SELF_MULTIPLE",
      })
    end

    local startsLoot = MessageStartsWithLootPrefix(text)
    local startsMoney = MessageStartsWithAnyPrefix(text, DIRECT_MONEY_PREFIXES)
    local startsCurrency = MessageStartsWithAnyPrefix(text, DIRECT_CURRENCY_PREFIXES)

    if startsLoot or startsMoney or startsCurrency then
      local hasItem = (string.find(text, "|Hitem:", 1, true) ~= nil)
      local hasCurrency = (string.find(text, "|Hcurrency:", 1, true) ~= nil)
      local hasBracket = (string.match(text, "%b[]") ~= nil)
      local isMoney = (IsLikelyMoneyMessage and IsLikelyMoneyMessage(text)) and true or false

      if hasItem or hasCurrency or hasBracket or isMoney then
        local outFrame = (DB and DB.outputChatFrame) or 1

        local function GetPlayerColoredName()
          local name = (UnitName and UnitName("player")) or "You"
          if not (UnitClass and name) then
            return tostring(name)
          end

          local _, classFile = UnitClass("player")
          if C_ClassColor and C_ClassColor.GetClassColor and classFile then
            local color = C_ClassColor.GetClassColor(classFile)
            if color and color.WrapTextInColorCode then
              return color:WrapTextInColorCode(name)
            end
          end
          local rc = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
          if rc and rc.colorStr then
            return "|c" .. rc.colorStr .. name .. "|r"
          end
          return tostring(name)
        end

        -- Reprint (if configured) so the loot isn't lost.
        if DB and DB.echoItem then
          local display = nil

          if isMoney and ParseCoinsFromMoneyMessage and FormatMoney then
            local coins = ParseCoinsFromMoneyMessage(text)
            display = FormatMoney(coins)
          else
            local link = string.match(text, "(|c%x%x%x%x%x%x%x%x|Hitem:%d+.-|h.-|h|r)")
              or string.match(text, "(|Hitem:%d+.-|h.-|h|r)")
              or string.match(text, "(|Hitem:%d+.-|h.-|h)")
              or string.match(text, "(|c%x+|Hitem:%d+.-|h.-|h|r)")
              or string.match(text, "(|c%x%x%x%x%x%x%x%x|Hcurrency:%d+.-|h.-|h|r)")
              or string.match(text, "(|Hcurrency:%d+.-|h.-|h)")

            -- If we captured an uncolored item link, try to upgrade to the full colored item link.
            if link and type(link) == "string" and string.len(link) > 0 and not string.match(link, "^|c%x%x%x%x%x%x%x%x|Hitem:") and string.find(link, "|Hitem:", 1, true) then
              if C_Item and C_Item.GetItemInfo then
                local _, itemLink = C_Item.GetItemInfo(link)
                if type(itemLink) == "string" and string.len(itemLink) > 0 then
                  link = itemLink
                end
              end
            end

            if link then
              -- Remove brackets in the displayed portion: |h[Name]|h -> |hName|h
              display = string.gsub(link, "|h%[([^%]]+)%]|h", "|h%1|h")
            else
              -- Fallback: use the shown [Name]
              display = string.match(text, "%b[]")
            end
          end

          if type(display) == "string" and string.len(display) > 0 then
            local meColored = GetPlayerColoredName()
            local out = tostring(meColored) .. ": " .. tostring(display)
            addMessageInHook = true
            PrintToChatFrame(out, outFrame)
            addMessageInHook = false
          end
        end

        if DebugChatSetupEnabled() then
          addMessageInHook = true
          DebugPrint(string.format(
            "AddMessage: suppressed direct print (loot=%s money=%s currency=%s hasItem=%s hasCur=%s hasBracket=%s isMoney=%s echo=%s) text=%s",
            tostring(startsLoot),
            tostring(startsMoney),
            tostring(startsCurrency),
            tostring(hasItem),
            tostring(hasCurrency),
            tostring(hasBracket),
            tostring(isMoney),
            tostring((DB and DB.echoItem) and true or false),
            tostring(text)
          ))
          addMessageInHook = false
        end
        return
      end
    end

    return orig(self, text, ...)
  end
end

local function HookAllChatFramesAddMessage()
  -- Prefer CHAT_FRAMES if present; otherwise fall back to numbered frames.
  if type(CHAT_FRAMES) == "table" then
    for _, frameName in ipairs(CHAT_FRAMES) do
      local f = _G and rawget(_G, frameName)
      if f then
        HookChatFrameAddMessage(f)
      end
    end
  else
    local n = tonumber(NUM_CHAT_WINDOWS) or 10
    for i = 1, n do
      local f = _G and rawget(_G, "ChatFrame" .. tostring(i))
      if f then
        HookChatFrameAddMessage(f)
      end
    end
  end
end

local function GetDefaultMoneyConfig()
  local d = env and env.DEFAULTS
  if type(d) == "table" and type(d.money) == "table" then
    return d.money
  end
  return { gold = true, silver = true, copper = true }
end

local function GetAddonLinkAliases()
  local t = env and env.ADDON_LINK_ALIASES
  return (type(t) == "table") and t or {}
end

local function GetAddonCurrencyAliases()
  local t = env and env.ADDON_CURRENCY_ALIASES
  return (type(t) == "table") and t or {}
end

function LootChat.CaptureEnabled()
  EnsureRefs()
  return (DB and DB.debugCapture) == true
end

function LootChat.CaptureGetLog()
  EnsureRefs()
  if not CHARDB then return nil end
  if type(CHARDB.debugCaptureLog) ~= "table" then
    CHARDB.debugCaptureLog = {}
  end
  return CHARDB.debugCaptureLog
end

local function CaptureNowString()
  if type(date) == "function" then
    return date("%H:%M:%S")
  end
  if type(time) == "function" then
    return tostring(time())
  end
  return ""
end

local function CaptureExtractLink(msg)
  if type(msg) ~= "string" then return nil end
  return msg:match("(|c%x%x%x%x%x%x%x%x|Hitem:.-|h%[.-%]|h|r)")
    or msg:match("(|Hitem:.-|h%[.-%]|h)")
    or msg:match("(|c%x%x%x%x%x%x%x%x|Hcurrency:.-|h%[.-%]|h|r)")
    or msg:match("(|Hcurrency:.-|h%[.-%]|h)")
end

local function CaptureItemIDFromLink(link)
  if type(link) ~= "string" then return nil end
  local id = link:match("Hitem:(%d+):")
  return id and tonumber(id) or nil
end

function LootChat.CaptureAppend(kind, data)
  if not LootChat.CaptureEnabled() then return end
  local log = LootChat.CaptureGetLog()
  if not log then return end

  local entry = (type(data) == "table") and data or { msg = tostring(data or "") }
  entry.t = entry.t or CaptureNowString()
  entry.kind = tostring(kind or entry.kind or "CAP")
  log[#log + 1] = entry

  EnsureRefs()
  local maxN = tonumber(DB and DB.debugCaptureMax) or 200
  if maxN < 20 then maxN = 20 end
  if maxN > 500 then maxN = 500 end
  while #log > maxN do
    table.remove(log, 1)
  end
end

function LootChat.CaptureChatIn(eventName, msg, author)
  if not LootChat.CaptureEnabled() then return end
  local link = CaptureExtractLink(msg)
  LootChat.CaptureAppend("CHAT_IN", {
    event = tostring(eventName or ""),
    author = (type(author) == "string") and author or nil,
    msg = msg,
    hasItemLink = (type(msg) == "string" and msg:find("|Hitem:", 1, true) ~= nil) or false,
    hasCurrencyLink = (type(msg) == "string" and msg:find("|Hcurrency:", 1, true) ~= nil) or false,
    link = link,
    itemID = CaptureItemIDFromLink(link),
  })
end

function LootChat.CaptureChatOut(eventName, out, meta)
  if not LootChat.CaptureEnabled() then return end
  local entry = (type(meta) == "table") and meta or {}
  entry.event = tostring(eventName or "")
  entry.out = out
  LootChat.CaptureAppend("CHAT_OUT", entry)
end

-- Loot patterns
LOOT_PATTERNS = nil
LOOT_PREFIXES = nil
LOOT_GROUP_PATTERNS = nil
RECEIVE_ITEM_PATTERNS = nil

local LOOT_PATTERN_KEYS
local LOOT_GROUP_PATTERN_KEYS

local function EscapeLuaPattern(text)
  text = tostring(text or "")
  return (text:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1"))
end

local function GlobalStringToPattern(globalString)
  if type(globalString) ~= "string" or globalString == "" then return nil end

  local s = globalString
  s = s:gsub("%%s", "\0S\0")
  s = s:gsub("%%d", "\0D\0")

  s = EscapeLuaPattern(s)

  s = s:gsub("\0S\0", "(.-)")
  s = s:gsub("\0D\0", "(%d+)")

  return "^" .. s .. "$"
end

LOOT_PATTERN_KEYS = {
  "LOOT_ITEM_SELF",
  "LOOT_ITEM_SELF_MULTIPLE",
  "LOOT_ITEM_PUSHED_SELF",
  "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
  "LOOT_ITEM_CREATED_SELF",
  "LOOT_ITEM_CREATED_SELF_MULTIPLE",
  "YOU_RECEIVE_ITEM",
  "YOU_RECEIVE_ITEM_MULTIPLE",
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

BuildLootPatterns = function()
  local patterns = {}
  local prefixes = {}
  local groupPatterns = {}
  local receiveItemPatterns = {}

  local keys = {
    "LOOT_ITEM_SELF",
    "LOOT_ITEM_SELF_MULTIPLE",
    "LOOT_ITEM_PUSHED_SELF",
    "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
    "LOOT_ITEM_CREATED_SELF",
    "LOOT_ITEM_CREATED_SELF_MULTIPLE",
    "YOU_RECEIVE_ITEM",
    "YOU_RECEIVE_ITEM_MULTIPLE",
    "LOOT_ITEM_BONUS_ROLL_SELF",
    "LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE",
  }

  for _, k in ipairs(keys) do
    local gs = _G and rawget(_G, k)
    local pat = GlobalStringToPattern(gs)
    if pat then
      patterns[#patterns + 1] = pat

      if k == "YOU_RECEIVE_ITEM" or k == "YOU_RECEIVE_ITEM_MULTIPLE" then
        receiveItemPatterns[#receiveItemPatterns + 1] = pat
      end

      -- Some chat lines omit the trailing '.' (or localization differs). Allow optional period for all patterns.
      do
        local alt = pat:gsub("%%%.%$", "%%.?$")
        if alt ~= pat then
          patterns[#patterns + 1] = alt
          if k == "YOU_RECEIVE_ITEM" or k == "YOU_RECEIVE_ITEM_MULTIPLE" then
            receiveItemPatterns[#receiveItemPatterns + 1] = alt
          end
        end
      end
    end

    if type(gs) == "string" and gs ~= "" then
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
  RECEIVE_ITEM_PATTERNS = receiveItemPatterns
end

local function NormalizeForPrefixMatch(s)
  if not IsNonEmptyPublicString(s) then return "" end
  -- Some client strings use non-breaking spaces; normalize them to regular spaces.
  -- NBSP (U+00A0) in UTF-8 is \194\160, narrow NBSP (U+202F) is \226\128\175.
  s = string.gsub(s, "\194\160", " ")
  s = string.gsub(s, "\226\128\175", " ")
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  -- collapse any whitespace runs (including NBSP-ish) to a single space
  s = string.gsub(s, "%s+", " ")
  return s
end

MessageStartsWithLootPrefix = function(msg)
  if not IsNonEmptyPublicString(msg) then return false end
  if not (LOOT_PREFIXES and #LOOT_PREFIXES > 0) then return false end
  local tmsg = NormalizeForPrefixMatch(msg)
  for _, prefix in ipairs(LOOT_PREFIXES) do
    if type(prefix) == "string" and string.len(prefix) > 0 then
      local tp = NormalizeForPrefixMatch(prefix)
      if string.len(tp) > 0 and string.find(tmsg, tp, 1, true) == 1 then
        return true
      end
    end
  end
  return false
end

local function StripRealmFromName(name)
  if type(name) ~= "string" then return name end
  return string.match(name, "^([^%-]+)") or name
end

local function IsItemLink(text)
  return type(text) == "string" and string.find(text, "|Hitem:", 1, true) ~= nil
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
  return string.match(msg, "(|c%x+|Hitem:.-|h%[.-%]|h|r)")
    or string.match(msg, "(|c%x+|Hitem:.-|h.-|h|r)")
    or string.match(msg, "(|Hitem:.-|h%[.-%]|h)")
    or string.match(msg, "(|Hitem:.-|h.-|h)")
end

local function ExtractItemLinkRobust(msg)
  if not IsNonEmptyPublicString(msg) then return nil end
  -- Try to match the most common (and some uncommon) hyperlink forms.
  return string.match(msg, "(|c%x%x%x%x%x%x%x%x|Hitem:%d+.-|h.-|h|r)")
    or string.match(msg, "(|c%x%x%x%x%x%x%x%x|Hitem:%d+.-|h.-|h)")
    or string.match(msg, "(|Hitem:%d+.-|h.-|h|r)")
    or string.match(msg, "(|Hitem:%d+.-|h.-|h)")
    or ExtractLinkFallback(msg)
end

local function NormalizeItemLink(link)
  if type(link) ~= "string" or string.len(link) == 0 then return link end
  if string.match(link, "^|c%x%x%x%x%x%x%x%x|Hitem:") then
    return link
  end

  do
    local name = link
    local bracketName = string.match(link, "^%[([^%]]+)%]$")
    if bracketName and string.len(bracketName) > 0 then
      name = bracketName
    end

    if name and not string.match(name, "|Hitem:") then
      if C_Item and C_Item.GetItemInfo then
        local _, itemLink = C_Item.GetItemInfo(name)
        if type(itemLink) == "string" and string.len(itemLink) > 0 then
          return itemLink
        end
      end
    end
  end

  if string.match(link, "|Hitem:") then
    if C_Item and C_Item.GetItemInfo then
      local _, itemLink = C_Item.GetItemInfo(link)
      if type(itemLink) == "string" and string.len(itemLink) > 0 then
        return itemLink
      end
    end
  end

  return link
end

local function StripDisplayedLinkBrackets(link)
  if type(link) ~= "string" or string.len(link) == 0 then return link end
  return string.gsub(link, "|h%[([^%]]+)%]|h", "|h%1|h")
end

local function GetItemIDFromLink(link)
  if type(link) ~= "string" or string.len(link) == 0 then return nil end
  local id = string.match(link, "|Hitem:(%d+)")
  if not id then return nil end
  return tonumber(id)
end

local function GetCurrencyIDFromLink(link)
  if type(link) ~= "string" or string.len(link) == 0 then return nil end
  local id = string.match(link, "|Hcurrency:(%d+)")
  if not id then return nil end
  return tonumber(id)
end

local function ApplyItemLinkAlias(link)
  EnsureRefs()
  if type(link) ~= "string" or string.len(link) == 0 then return link end
  local id = GetItemIDFromLink(link)
  if not id then return link end

  local alias

  local charDisabled = (CHARDB and type(CHARDB.linkAliasDisabledChar) == "table" and CHARDB.linkAliasDisabledChar[id] == true)
  local acctDisabled = (DB and type(DB.linkAliasDisabledAccount) == "table" and DB.linkAliasDisabledAccount[id] == true)
  local addonDisabled = (DB and type(DB.linkAliasDisabledAddon) == "table" and DB.linkAliasDisabledAddon[id] == true)

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
    alias = GetAddonLinkAliases()[id]
  end
  if type(alias) ~= "string" or alias == "" then
    return link
  end

  local out = link
  out = out:gsub("(|Hitem:[^|]+|h)%[([^%]]+)%](|h)", "%1" .. alias .. "%3", 1)
  out = out:gsub("(|Hitem:[^|]+|h)([^|]+)(|h)", "%1" .. alias .. "%3", 1)
  return out
end

local function ApplyCurrencyLinkAlias(link)
  EnsureRefs()
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
    alias = GetAddonCurrencyAliases()[id]
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
  return string.match(msg, "(|c%x+|Hcurrency:.-|h%[.-%]|h|r)")
    or string.match(msg, "(|Hcurrency:.-|h%[.-%]|h)")
end

local function ExtractAchievementLinkFallback(msg)
  if type(msg) ~= "string" then return nil end
  return string.match(msg, "(|c%x+|Hachievement:.-|h%[.-%]|h|r)")
    or string.match(msg, "(|Hachievement:.-|h%[.-%]|h)")
end

local function AppendSuffixInsideColorReset(text, suffix)
  if type(text) ~= "string" then
    text = tostring(text or "")
  end
  suffix = tostring(suffix or "")
  if suffix == "" then
    return text
  end
  if text:sub(-2) == "|r" then
    return text:sub(1, -3) .. suffix .. "|r"
  end
  return text .. suffix
end

local function FormatSelfLine(text)
  EnsureRefs()
  if IsInAnyGroup() or (DB and DB.showSelfNameAlways) then
    local me = GetClassColoredName(UnitName and UnitName("player"))
    if me and me ~= "" then
      return string.format("%s %s", AppendSuffixInsideColorReset(me, ":"), text)
    end
  end
  return text
end

-- Loot combine
local LOOT_COMBINE_DELAY = 0.25
local lootCombineParts
local lootCombineGen = 0
local lootCombineLootOpen = false

function LootChat.LootCombineEnabled()
  EnsureRefs()
  local n = DB and tonumber(DB.lootCombineCount) or 1
  return (n and n > 1)
end

local function LootCombineMode()
  EnsureRefs()
  local mode = DB and tostring(DB.lootCombineMode or "loot") or "loot"
  mode = mode:lower()
  if mode ~= "loot" and mode ~= "timer" then
    mode = "loot"
  end
  return mode
end

function LootChat.LootCombineFlush()
  EnsureRefs()
  if not lootCombineParts or #lootCombineParts == 0 then return end
  local msg = table.concat(lootCombineParts, "|cff15AB0D,|r ")
  for i = #lootCombineParts, 1, -1 do
    lootCombineParts[i] = nil
  end
  Print(FormatSelfLine(msg))
end

function LootChat.LootCombineCancelTimers()
  lootCombineGen = (lootCombineGen or 0) + 1
end

function LootChat.LootCombineWindowStart()
  if not LootChat.LootCombineEnabled() then return end
  if LootCombineMode() ~= "loot" then return end
  lootCombineLootOpen = true
  LootChat.LootCombineCancelTimers()
end

function LootChat.LootCombineWindowEnd()
  if not lootCombineLootOpen then return end
  lootCombineLootOpen = false
  LootChat.LootCombineCancelTimers()
  LootChat.LootCombineFlush()
end

local function LootCombineAdd(part)
  if not LootChat.LootCombineEnabled() then
    Print(FormatSelfLine(part))
    return
  end

  EnsureRefs()
  local maxN = tonumber(DB and DB.lootCombineCount) or 1
  if maxN < 2 then
    Print(FormatSelfLine(part))
    return
  end
  if maxN > 25 then maxN = 25 end

  if not lootCombineParts then lootCombineParts = {} end
  lootCombineParts[#lootCombineParts + 1] = part

  if #lootCombineParts >= maxN then
    LootChat.LootCombineFlush()
    return
  end

  local mode = LootCombineMode()
  if mode == "timer" then
    LootChat.LootCombineCancelTimers()
    local gen = lootCombineGen
    if C_Timer and C_Timer.After then
      C_Timer.After(LOOT_COMBINE_DELAY, function()
        if gen ~= lootCombineGen then return end
        LootChat.LootCombineFlush()
      end)
    end
  else
    if not lootCombineLootOpen then
      LootChat.LootCombineCancelTimers()
      local gen = lootCombineGen
      if C_Timer and C_Timer.After then
        C_Timer.After(1.25, function()
          if gen ~= lootCombineGen then return end
          LootChat.LootCombineFlush()
        end)
      end
    end
  end
end

-- Delay-print aggregation
local delayPrintBuckets

local function GetDelayPrintSecondsForItemID(itemID)
  EnsureRefs()
  if not (DB and DB.delayPrint and DB.delayPrint.enabled) then return nil end
  if not (itemID and itemID > 0) then return nil end
  local t = DB.delayPrint.itemSeconds
  if type(t) ~= "table" then return nil end
  local sec = tonumber(t[itemID])
  if not sec or sec <= 0 then return nil end
  if sec > 3600 then sec = 3600 end
  return sec
end

local function FormatLootItemPartFromLink(link, totalQty)
  if type(link) ~= "string" or link == "" then return nil end
  link = NormalizeItemLink(link)
  link = ApplyItemLinkAlias(link)

  local displayLink = StripDisplayedLinkBrackets(link)
  local out = displayLink
  local n = tonumber(totalQty)
  if n and n > 1 then
    out = string.format("%s x%d", displayLink, n)
  end

  if IsItemLevelEnabled() then
    local ilvl = GetEquippableItemLevelSuffix(link)
    if ilvl then
      local color = link:match("^(|c%x%x%x%x%x%x%x%x)")
      local ilvlText = color and (color .. tostring(ilvl) .. "|r") or tostring(ilvl)
      out = out .. " " .. ilvlText
    end
  end

  return out
end

local function DelayPrintFlushBucket(secKey)
  EnsureRefs()
  if not delayPrintBuckets then return end
  local b = delayPrintBuckets[secKey]
  if not (b and b.order and b.items) then return end
  if #b.order == 0 then return end

  local parts = {}
  for i = 1, #b.order do
    local id = b.order[i]
    local it = b.items[id]
    if it and it.link and it.qty and it.qty > 0 then
      local part = FormatLootItemPartFromLink(it.link, it.qty)
      if part then
        parts[#parts + 1] = part
      end
    end
  end

  b.items = {}
  b.order = {}
  b.gen = (b.gen or 0) + 1

  if #parts > 0 then
    local msg = table.concat(parts, "|cff15AB0D,|r ")
    Print(FormatSelfLine(msg))
  end
end

function LootChat.DelayPrintFlushAll()
  EnsureRefs()
  if not delayPrintBuckets then return end
  for secKey in pairs(delayPrintBuckets) do
    DelayPrintFlushBucket(secKey)
  end
end

local function DelayPrintAddItem(itemID, link, qty, sec)
  EnsureRefs()
  if not (sec and sec > 0) then return false end
  if not (C_Timer and C_Timer.After) then
    local part = FormatLootItemPartFromLink(link, qty)
    if part then
      Print(FormatSelfLine(part))
      return true
    end
    return false
  end

  local secKey = tostring(sec)
  if not delayPrintBuckets then delayPrintBuckets = {} end
  if not delayPrintBuckets[secKey] then
    delayPrintBuckets[secKey] = { items = {}, order = {}, gen = 0 }
  end
  local b = delayPrintBuckets[secKey]
  b.gen = (b.gen or 0) + 1
  local myGen = b.gen

  local n = tonumber(qty) or 1
  if n < 1 then n = 1 end

  local it = b.items[itemID]
  if not it then
    it = { link = link, qty = 0 }
    b.items[itemID] = it
    b.order[#b.order + 1] = itemID
  else
    it.link = link or it.link
  end
  it.qty = (tonumber(it.qty) or 0) + n

  C_Timer.After(sec, function()
    EnsureRefs()
    if not delayPrintBuckets then return end
    local cur = delayPrintBuckets[secKey]
    if not cur then return end
    if cur.gen ~= myGen then return end
    DelayPrintFlushBucket(secKey)
  end)

  return true
end

local function FormatOtherLine(name, text)
  local colored = GetClassColoredName(name or "")
  if colored and colored ~= "" then
    return string.format("%s %s", AppendSuffixInsideColorReset(colored, ":"), text)
  end
  return text
end

-- Currency patterns
local CURRENCY_PATTERNS
local CURRENCY_PREFIXES

local CURRENCY_PATTERN_KEYS = {
  "CURRENCY_GAINED",
  "CURRENCY_GAINED_MULTIPLE",
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
  EnsureRefs()
  if not IsEnabled() then return false end
  if not IsNonEmptyPublicString(msg) then return false end

  LootChat.CaptureChatIn("CHAT_MSG_CURRENCY", msg)

  if not CURRENCY_PATTERNS then BuildCurrencyPatterns() end

  local link, qty
  for _, pat in ipairs(CURRENCY_PATTERNS or {}) do
    local a, b = string.match(msg, pat)
    if a then
      if b then
        local aIsLink = type(a) == "string" and string.find(a, "|Hcurrency:", 1, true) ~= nil
        local bIsLink = type(b) == "string" and string.find(b, "|Hcurrency:", 1, true) ~= nil

        if aIsLink and not bIsLink then
          link, qty = a, b
        elseif bIsLink and not aIsLink then
          link, qty = b, a
        else
          -- Neither capture looks like a currency hyperlink.
          -- Prefer any real link embedded in the message; otherwise treat the non-numeric capture as the currency name.
          local aNum = tonumber(a)
          local bNum = tonumber(b)
          if aNum and not bNum then
            qty = a
            link = ExtractCurrencyLinkFallback(msg) or b
          elseif bNum and not aNum then
            qty = b
            link = ExtractCurrencyLinkFallback(msg) or a
          else
            link = ExtractCurrencyLinkFallback(msg) or a
            qty = qty or b
          end
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

  -- Guard: never allow a bare number to become the "link" (this produces outputs like "16").
  if type(link) == "string" and tonumber(link) ~= nil and string.find(link, "|Hcurrency:", 1, true) == nil then
    qty = qty or link
    link = ExtractCurrencyLinkFallback(msg) or msg:match("%b[]")
    if not link then
      -- Nothing useful to show; still allow suppression via hideLootText.
      return (DB and DB.hideLootText) and true or false
    end
  end

  if not qty then
    local escaped = EscapeLuaPattern(link)
    qty = string.match(msg, escaped .. "%s*[x×]%s*(%d+)")
      or string.match(msg, escaped .. "[\r\n ]*[x×]%s*(%d+)")
      or string.match(msg, "%s*[x×]%s*(%d+)%s*%.?$")
  end

  local n = tonumber(qty)
  local currencyID = GetCurrencyIDFromLink(link)
  if currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyLink then
    local built = C_CurrencyInfo.GetCurrencyLink(currencyID, (n and n > 0) and n or 0)
    if type(built) == "string" and string.len(built) > 0 then
      link = built
    end
  end

  local handled = false
  if DB and DB.echoItem then
    local out = ApplyCurrencyLinkAlias(link)
    out = StripDisplayedLinkBrackets(out)
    if n and n > 1 then
      out = string.format("%s x%d", out, n)
    end
    if LootChat.LootCombineEnabled() then
      if DB and DB.lootCombineIncludeCurrency then
        LootCombineAdd(out)
        handled = true
      end
    else
      Print(FormatSelfLine(out))
      handled = true
    end

    LootChat.CaptureChatOut("CHAT_MSG_CURRENCY", out, {
      handled = handled,
      combine = LootChat.LootCombineEnabled() and true or false,
      includeCurrency = (DB and DB.lootCombineIncludeCurrency) and true or false,
      qty = n,
      currencyID = currencyID,
    })
  end

  -- Even when we choose not to echo/combine currency, still suppress the default line if configured.
  return (DB and DB.hideLootText) and true or false
end

-- Money patterns
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

ParseCoinsFromMoneyMessage = function(msg)
  if not IsNonEmptyPublicString(msg) then return nil end

  local function numBeforeTexture(textureNeedle)
    local s = string.match(msg, "([%d,]+)%s*|T.-" .. textureNeedle .. ".-|t")
    if not s then return nil end
    s = string.gsub(s, ",", "")
    return tonumber(s)
  end

  local gold = numBeforeTexture("UI%-GoldIcon")
  local silver = numBeforeTexture("UI%-SilverIcon")
  local copper = numBeforeTexture("UI%-CopperIcon")

  if not (gold or silver or copper) then
    local lower = string.lower(msg)

    local function numBeforeToken(token)
      if type(token) ~= "string" or token == "" then return nil end
      local n = string.match(lower, "([%d,]+)%s*" .. EscapeLuaPattern(string.lower(token)))
      if not n then return nil end
      n = string.gsub(n, ",", "")
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

FormatMoney = function(coins)
  if type(coins) ~= "table" then return nil end
  EnsureRefs()
  local m = (DB and type(DB.money) == "table") and DB.money or GetDefaultMoneyConfig()

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

IsLikelyMoneyMessage = function(msg)
  if not IsNonEmptyPublicString(msg) then return false end

  if string.find(msg, "UI%-GoldIcon") or string.find(msg, "UI%-SilverIcon") or string.find(msg, "UI%-CopperIcon") then
    return true
  end

  local lower = string.lower(msg)

  if not MONEY_PATTERNS then BuildMoneyPatterns() end

  for _, pat in ipairs(MONEY_PATTERNS or {}) do
    if string.match(msg, pat) then
      return true
    end
  end

  for _, prefix in ipairs(MONEY_PREFIXES or {}) do
    if type(prefix) == "string" and string.len(prefix) > 0 and string.find(msg, prefix, 1, true) == 1 then
      return true
    end
  end

  local function hasToken(token)
    if type(token) ~= "string" or token == "" then return false end
    return string.find(lower, string.lower(token), 1, true) ~= nil
  end
  if hasToken((_G and rawget(_G, "GOLD")) or "gold")
    or hasToken((_G and rawget(_G, "SILVER")) or "silver")
    or hasToken((_G and rawget(_G, "COPPER")) or "copper") then
    return true
  end

  local function hasNumberBeforeToken(token)
    if type(token) ~= "string" or token == "" then return false end
    return string.match(lower, "[%d,]+%s*" .. EscapeLuaPattern(string.lower(token))) ~= nil
  end
  if hasNumberBeforeToken((_G and rawget(_G, "GOLD_AMOUNT_SYMBOL")) or "g")
    or hasNumberBeforeToken((_G and rawget(_G, "SILVER_AMOUNT_SYMBOL")) or "s")
    or hasNumberBeforeToken((_G and rawget(_G, "COPPER_AMOUNT_SYMBOL")) or "c") then
    return true
  end

  return false
end

-- Public: shared money parsing for other LootIt modules (e.g., Tax).
LootChat.IsLikelyMoneyMessage = IsLikelyMoneyMessage
LootChat.ParseCoinsFromMoneyMessage = ParseCoinsFromMoneyMessage

local function OnMoneyChat(_, _, msg, ...)
  EnsureRefs()
  if not IsEnabled() then return false end
  if not IsNonEmptyPublicString(msg) then return false end

  LootChat.CaptureChatIn("CHAT_MSG_MONEY", msg)

  if not IsLikelyMoneyMessage(msg) then return false end

  local handled = false
  if DB and DB.echoItem then
    local coins = ParseCoinsFromMoneyMessage(msg)
    local out = FormatMoney(coins)
    if out then
      if LootChat.LootCombineEnabled() then
        if DB and DB.lootCombineIncludeGold then
          LootCombineAdd(out)
          handled = true
        end
      else
        Print(FormatSelfLine(out))
        handled = true
      end

      LootChat.CaptureChatOut("CHAT_MSG_MONEY", out, {
        handled = handled,
        combine = LootChat.LootCombineEnabled() and true or false,
        includeGold = (DB and DB.lootCombineIncludeGold) and true or false,
        gold = coins and coins.gold or nil,
        silver = coins and coins.silver or nil,
        copper = coins and coins.copper or nil,
      })
    end
  end

  -- Even when we choose not to echo/combine money, still suppress the default line if configured.
  return (DB and DB.hideLootText) and true or false
end

local function OnSystemChat(_, eventName, msg, ...)
  EnsureRefs()
  if not IsEnabled() then return false end
  if not IsNonEmptyPublicString(msg) then return false end

  local ev = (type(eventName) == "string" and eventName ~= "") and eventName or "CHAT_MSG_SYSTEM"
  LootChat.CaptureChatIn(ev, msg)

  if IsLikelyMoneyMessage(msg) then
    local handled = false
    if DB and DB.echoItem then
      local coins = ParseCoinsFromMoneyMessage(msg)
      local out = FormatMoney(coins)
      if out then
        if LootChat.LootCombineEnabled() then
          if DB and DB.lootCombineIncludeGold then
            LootCombineAdd(out)
            handled = true
          end
        else
          Print(FormatSelfLine(out))
          handled = true
        end

        LootChat.CaptureChatOut("CHAT_MSG_SYSTEM", out, {
          handled = handled,
          rewrittenMoney = true,
          combine = LootChat.LootCombineEnabled() and true or false,
          includeGold = (DB and DB.lootCombineIncludeGold) and true or false,
          gold = coins and coins.gold or nil,
          silver = coins and coins.silver or nil,
          copper = coins and coins.copper or nil,
        })
      end
    end

    -- Even when we choose not to echo/combine money, still suppress the default line if configured.
    return (DB and DB.hideLootText) and true or false
  end

  if not LOOT_PATTERNS then BuildLootPatterns() end

  -- Some loot lines (notably fishing) can show up as CHAT_MSG_SYSTEM instead of CHAT_MSG_LOOT.
  -- If the message begins with a known loot prefix, treat it as self loot and rewrite/suppress it.
  do
    local prefixMatched = false
    if LOOT_PREFIXES and #LOOT_PREFIXES > 0 then
      local tmsg = msg:gsub("^%s+", "")
      for _, prefix in ipairs(LOOT_PREFIXES) do
        if type(prefix) == "string" and prefix ~= "" then
          local tp = prefix:gsub("^%s+", "")
          if tp ~= "" and tmsg:sub(1, #tp) == tp then
            prefixMatched = true
            break
          end
        end
      end
    end

    if prefixMatched then
      local link = ExtractLinkFallback(msg)
      if not link then
        link = msg:match("%b[]")
      end

      if not link then
        if DebugChatSetupEnabled and DebugChatSetupEnabled() then
          DebugPrint(string.format(
            "OnSystemChat: loot-prefix but no link (event=%s hide=%s echo=%s) msg=%s",
            tostring(ev),
            tostring((DB and DB.hideLootText) and true or false),
            tostring((DB and DB.echoItem) and true or false),
            tostring(msg)
          ))
        end
        return false
      end

      local qty
      do
        local escaped = EscapeLuaPattern(link)
        qty = msg:match(escaped .. "%s*[x×]%s*(%d+)")
          or msg:match(escaped .. "[\r\n ]*[x×]%s*(%d+)")
          or msg:match("%s*[x×]%s*(%d+)%s*%.?$")
      end

      local handled = false
      if DB and DB.echoItem then
        link = NormalizeItemLink(link)

        local itemID = CaptureItemIDFromLink(link)
        if itemID and IsIgnoredItemID(itemID) then
          LootChat.CaptureChatOut(ev, link, { handled = true, ignored = true, qty = tonumber(qty), itemID = itemID, rewrittenLoot = true })
          return true
        end

        do
          local n = tonumber(qty)
          local delaySec = itemID and GetDelayPrintSecondsForItemID(itemID) or nil
          if delaySec then
            if DelayPrintAddItem(itemID, link, n, delaySec) then
              LootChat.CaptureChatOut("CHAT_MSG_SYSTEM", link, { handled = true, delayed = true, delaySec = delaySec, qty = n, itemID = itemID, rewrittenLoot = true })
              return true
            end
          end
        end

        link = ApplyItemLinkAlias(link)
        local displayLink = StripDisplayedLinkBrackets(link)
        local out = displayLink
        local n = tonumber(qty)
        if n and n > 1 then
          out = string.format("%s x%d", displayLink, n)
        end

        if IsItemLevelEnabled() and type(link) == "string" and link:find("|Hitem:", 1, true) then
          local ilvl = GetEquippableItemLevelSuffix(link)
          if ilvl then
            local color = link:match("^(|c%x%x%x%x%x%x%x%x)")
            local ilvlText = color and (color .. tostring(ilvl) .. "|r") or tostring(ilvl)
            out = out .. " " .. ilvlText
          end
        end

        LootCombineAdd(out)
        handled = true
        LootChat.CaptureChatOut(ev, out, {
          handled = handled,
          rewrittenLoot = true,
          combine = LootChat.LootCombineEnabled() and true or false,
          qty = tonumber(qty),
          itemID = CaptureItemIDFromLink(link),
        })
      end

      return (handled and DB and DB.hideLootText) and true or false
    end
  end

  local link, qty
  for _, pat in ipairs(RECEIVE_ITEM_PATTERNS or {}) do
    local a, b = msg:match(pat)
    if a then
      link = a
      qty = b
      break
    end
  end

  if LootChat.CaptureEnabled() then
    LootChat.CaptureAppend("MATCH", {
      event = ev,
      link = link,
      qty = qty,
      hasItemLink = (msg:find("|Hitem:", 1, true) ~= nil) or false,
    })
  end

  if not link then
    link = ExtractLinkFallback(msg)
  end
  if not link then
    return false
  end

  if DB and DB.echoItem then
    link = NormalizeItemLink(link)
    local ignoredID = CaptureItemIDFromLink(link)
    if ignoredID and IsIgnoredItemID(ignoredID) then
      LootChat.CaptureChatOut("CHAT_MSG_SYSTEM", link, {
        handled = true,
        ignored = true,
        qty = tonumber(qty),
        itemID = ignoredID,
      })
      return true
    end

    do
      local n = tonumber(qty)
      local delaySec = GetDelayPrintSecondsForItemID(ignoredID)
      if delaySec then
        if DelayPrintAddItem(ignoredID, link, n, delaySec) then
          LootChat.CaptureChatOut("CHAT_MSG_SYSTEM", link, {
            handled = true,
            delayed = true,
            delaySec = delaySec,
            qty = n,
            itemID = ignoredID,
          })
          return true
        end
      end
    end

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

    LootCombineAdd(out)

    LootChat.CaptureChatOut("CHAT_MSG_SYSTEM", out, {
      handled = true,
      combine = LootChat.LootCombineEnabled() and true or false,
      qty = tonumber(qty),
      itemID = CaptureItemIDFromLink(link),
    })
  end

  return (DB and DB.hideLootText) and true or false
end

local pendingAsyncLoot = {}

local function OnLootChat(_, _, msg, author, ...)
  EnsureRefs()
  if not IsEnabled() then return false end
  if not IsNonEmptyPublicString(msg) then return false end

  LootChat.CaptureChatIn("CHAT_MSG_LOOT", msg, author)

  if not LOOT_PATTERNS then BuildLootPatterns() end

  if string.find(msg, "|Hcurrency:", 1, true) then
    local handled = false

    local link = (ExtractCurrencyLinkFallback and ExtractCurrencyLinkFallback(msg))
      or string.match(msg, "(|Hcurrency:%d+.-|h.-|h)")
      or string.match(msg, "(|c%x%x%x%x%x%x%x%x|Hcurrency:%d+.-|h.-|h|r)")

    if link and DB and DB.echoItem then
      local qty
      local escaped = EscapeLuaPattern(link)
      qty = string.match(msg, escaped .. "%s*[x×]%s*(%d+)")
        or string.match(msg, escaped .. "[\r\n ]*[x×]%s*(%d+)")
        or string.match(msg, "%s*[x×]%s*(%d+)%s*%.?$")

      local n = tonumber(qty)
      local currencyID = (GetCurrencyIDFromLink and GetCurrencyIDFromLink(link)) or nil
      if currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyLink then
        local built = C_CurrencyInfo.GetCurrencyLink(currencyID, (n and n > 0) and n or 0)
        if type(built) == "string" and string.len(built) > 0 then
          link = built
        end
      end

      local out = (ApplyCurrencyLinkAlias and ApplyCurrencyLinkAlias(link)) or link
      out = StripDisplayedLinkBrackets(out)
      if n and n > 1 then
        out = string.format("%s x%d", out, n)
      end

      if LootChat.LootCombineEnabled() then
        if DB and DB.lootCombineIncludeCurrency then
          LootCombineAdd(out)
          handled = true
        end
      else
        Print(FormatSelfLine(out))
        handled = true
      end

      LootChat.CaptureChatOut("CHAT_MSG_LOOT", out, {
        handled = handled,
        rewrittenCurrency = true,
        combine = LootChat.LootCombineEnabled() and true or false,
        includeCurrency = (DB and DB.lootCombineIncludeCurrency) and true or false,
        qty = n,
        currencyID = currencyID,
      })
    end

    -- Even when we choose not to echo/combine currency, still suppress the default line if configured.
    return (DB and DB.hideLootText) and true or false
  end

  if (DB and DB.hideLootText) and (LOOT_PREFIXES and #LOOT_PREFIXES > 0) then
    local hasItem = string.find(msg, "|Hitem:", 1, true) ~= nil
    local hasCurrency = string.find(msg, "|Hcurrency:", 1, true) ~= nil
    if (not hasItem) and (not hasCurrency) and (not IsLikelyMoneyMessage(msg)) then
      local tmsg = NormalizeForPrefixMatch(msg)
      for _, prefix in ipairs(LOOT_PREFIXES) do
        if type(prefix) == "string" and string.len(prefix) > 0 then
          local tp = NormalizeForPrefixMatch(prefix)
          if string.len(tp) > 0 and string.find(tmsg, tp, 1, true) == 1 and string.len(tmsg) == string.len(tp) then
            return true
          end
        end
      end
    end
  end

  if IsLikelyMoneyMessage(msg) then
    local handled = false
    if DB and DB.echoItem then
      local coins = ParseCoinsFromMoneyMessage(msg)
      local out = FormatMoney(coins)
      if out then
        if LootChat.LootCombineEnabled() and (DB and DB.lootCombineIncludeGold) then
          LootCombineAdd(out)
          handled = true
        else
          Print(FormatSelfLine(out))
          handled = true
        end

        LootChat.CaptureChatOut("CHAT_MSG_LOOT", out, {
          handled = handled,
          rewrittenMoney = true,
          combine = LootChat.LootCombineEnabled() and true or false,
          includeGold = (DB and DB.lootCombineIncludeGold) and true or false,
          gold = coins and coins.gold or nil,
          silver = coins and coins.silver or nil,
          copper = coins and coins.copper or nil,
        })
      end
    end
    -- Even when we choose not to echo/combine money, still suppress the default line if configured.
    return (DB and DB.hideLootText) and true or false
  end

  local isSelfLoot = false
  local playerName
  local link, qty
  local matchedByPattern = false
  local handled = false

  local dbgLootPrefixLine = (DebugChatSetupEnabled and DebugChatSetupEnabled()) and MessageStartsWithLootPrefix(msg) or false

  -- Prefer the chat event author for self-detection; some localized/variant loot lines don't match patterns.
  do
    local me = (UnitName and UnitName("player")) or nil
    if type(author) == "string" and author ~= "" and type(me) == "string" and me ~= "" then
      local a = StripRealmFromName(author)
      local m = StripRealmFromName(me)
      if a ~= "" and m ~= "" and a == m then
        isSelfLoot = true
      end
    end
  end

  for _, pat in ipairs(LOOT_PATTERNS or {}) do
    local a, b = msg:match(pat)
    if a then
      isSelfLoot = true
      matchedByPattern = true
      if b then
        link, qty = a, b
      else
        link = a
      end
      break
    end
  end

  -- Fallback: if patterns miss but the message starts with a known loot prefix and contains an item hyperlink,
  -- extract the first item link and optional quantity.
  if (not matchedByPattern) and (not link) and (LOOT_PREFIXES and #LOOT_PREFIXES > 0) then
    local hasItem = (msg:find("|Hitem:", 1, true) ~= nil) and true or false
    if hasItem then
      if MessageStartsWithLootPrefix(msg) then
        local extracted = ExtractItemLinkRobust(msg) or ExtractLinkFallback(msg)
        if extracted then
          isSelfLoot = true
          matchedByPattern = true
          link = extracted
          do
            local escaped = EscapeLuaPattern(extracted)
            qty = msg:match(escaped .. "%s*[x×]%s*(%d+)")
              or msg:match(escaped .. "[\r\n ]*[x×]%s*(%d+)")
              or msg:match("%s*[x×]%s*(%d+)%s*%.?$")
          end
        else
          -- As a last resort, use the displayed [Item Name] token.
          local bracket = msg:match("%b[]")
          if bracket then
            isSelfLoot = true
            matchedByPattern = true
            link = bracket
          end
        end
      end
    end
  end

  if not link then
    for _, pat in ipairs(LOOT_GROUP_PATTERNS or {}) do
      local a, b, c = msg:match(pat)
      if a and b then
        matchedByPattern = true
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

    if (not playerName or playerName == "") and type(author) == "string" and author ~= "" then
      playerName = author
    end
  end

  if not link then
    link = ExtractLinkFallback(msg)
  end

  -- If the message contains an item hyperlink but our normal matcher couldn't extract it,
  -- fall back to a very permissive hyperlink extractor.
  if not link then
    if msg:find("|Hitem:", 1, true) then
      link = ExtractItemLinkRobust(msg)
      if link then
        isSelfLoot = true
        matchedByPattern = true
      end
    end
  end

  if DebugChatSetupEnabled and DebugChatSetupEnabled() and (not matchedByPattern) then
    local hasItem = (msg:find("|Hitem:", 1, true) ~= nil) and true or false
    local hasCurrency = (msg:find("|Hcurrency:", 1, true) ~= nil) and true or false
    DebugPrint(string.format(
      "OnLootChat: pattern miss (hide=%s echo=%s hasItem=%s hasCurrency=%s author=%s) msg=%s",
      tostring((DB and DB.hideLootText) and true or false),
      tostring((DB and DB.echoItem) and true or false),
      tostring(hasItem),
      tostring(hasCurrency),
      tostring(author),
      tostring(msg)
    ))
  end

  if LootChat.CaptureEnabled() then
    LootChat.CaptureAppend("MATCH", {
      event = "CHAT_MSG_LOOT",
      isSelfLoot = isSelfLoot and true or false,
      link = link,
      qty = qty,
      hasItemLink = (msg:find("|Hitem:", 1, true) ~= nil) or false,
    })
  end
  if not link then
    if DebugChatSetupEnabled and DebugChatSetupEnabled() then
      local hasItem = (msg:find("|Hitem:", 1, true) ~= nil) and true or false
      local hasCurrency = (msg:find("|Hcurrency:", 1, true) ~= nil) and true or false
      local raw = tostring(msg):gsub("|", "||")
      DebugPrint(string.format(
        "OnLootChat: NO LINK (hasItem=%s hasCurrency=%s) msg=%s",
        tostring(hasItem), tostring(hasCurrency), tostring(msg)
      ))
      -- Print a raw form (escaped pipes) so we can see the hyperlink codes in chat.
      DebugPrint("OnLootChat: NO LINK raw=" .. raw)
    end
    return false
  end

  do
    local ignoredID = CaptureItemIDFromLink(link)
    if ignoredID and IsIgnoredItemID(ignoredID) then
      LootChat.CaptureChatOut("CHAT_MSG_LOOT", link, {
        handled = true,
        ignored = true,
        isSelfLoot = isSelfLoot and true or false,
        player = (not isSelfLoot) and playerName or nil,
        qty = tonumber(qty),
        itemID = ignoredID,
      })
      return true
    end
  end

  do
    local bracketName = (type(link) == "string") and link:match("^%[([^%]]+)%]$") or nil
    if bracketName and not link:find("|Hitem:", 1, true) then
      local knownItemID = nil
      if bracketName == "Chest of Gold" then
        knownItemID = 226814
      end

      if knownItemID and IsIgnoredItemID(knownItemID) then
        LootChat.CaptureChatOut("CHAT_MSG_LOOT", "[" .. bracketName .. "]", { handled = true, ignored = true, async = true, itemID = knownItemID, from = bracketName })
        return true
      end

      if knownItemID and Item and (Item.CreateFromItemID or Item.createFromItemID) then
        local n = tonumber(qty)
        if not n or n < 1 then n = 1 end

        local key = tostring(knownItemID) .. ":" .. tostring(n)
        if not pendingAsyncLoot[key] then
          pendingAsyncLoot[key] = true

          local itemObj = (Item.CreateFromItemID and Item:CreateFromItemID(knownItemID))
            or (Item.createFromItemID and Item:createFromItemID(knownItemID))

          local function finalize(withLink)
            pendingAsyncLoot[key] = nil
            EnsureRefs()
            if not (IsEnabled() and DB and DB.echoItem) then return end

            if IsIgnoredItemID(knownItemID) then
              LootChat.CaptureChatOut("CHAT_MSG_LOOT", "[" .. bracketName .. "]", { handled = true, ignored = true, async = true, itemID = knownItemID, from = bracketName })
              return
            end

            local resolved = withLink
            if type(resolved) ~= "string" or resolved == "" then
              resolved = "[" .. bracketName .. "]"
            end

            resolved = NormalizeItemLink(resolved)
            resolved = ApplyItemLinkAlias(resolved)
            local displayLink = StripDisplayedLinkBrackets(resolved)
            local out = displayLink
            if n and n > 1 then
              out = string.format("%s x%d", displayLink, n)
            end

            if IsItemLevelEnabled() then
              local ilvl = GetEquippableItemLevelSuffix(resolved)
              if ilvl then
                local color = resolved:match("^(|c%x%x%x%x%x%x%x%x)")
                local ilvlText = color and (color .. tostring(ilvl) .. "|r") or tostring(ilvl)
                out = out .. " " .. ilvlText
              end
            end

            LootCombineAdd(out)
            LootChat.CaptureChatOut("CHAT_MSG_LOOT", out, { handled = true, async = true, itemID = knownItemID, from = bracketName })
          end

          if itemObj and itemObj.ContinueOnItemLoad then
            itemObj:ContinueOnItemLoad(function()
              local itemLink = (itemObj.GetItemLink and itemObj:GetItemLink()) or nil
              finalize(itemLink)
            end)

            if C_Timer and C_Timer.After then
              C_Timer.After(1.0, function()
                if pendingAsyncLoot[key] then
                  finalize(nil)
                end
              end)
            end

            return (DB and DB.hideLootText) and true or false
          end
        end
      end
    end
  end

  if DB and DB.echoItem then
    link = NormalizeItemLink(link)
    local n = tonumber(qty)
    do
      local ignoredID = CaptureItemIDFromLink(link)
      if ignoredID and IsIgnoredItemID(ignoredID) then
        LootChat.CaptureChatOut("CHAT_MSG_LOOT", link, {
          handled = true,
          ignored = true,
          isSelfLoot = isSelfLoot and true or false,
          player = (not isSelfLoot) and playerName or nil,
          qty = tonumber(qty),
          itemID = ignoredID,
          combine = LootChat.LootCombineEnabled() and true or false,
        })
        return true
      end
    end

    if isSelfLoot then
      local itemID = CaptureItemIDFromLink(link)
      local delaySec = GetDelayPrintSecondsForItemID(itemID)
      if delaySec then
        if DelayPrintAddItem(itemID, link, n, delaySec) then
          LootChat.CaptureChatOut("CHAT_MSG_LOOT", link, {
            handled = true,
            delayed = true,
            delaySec = delaySec,
            isSelfLoot = true,
            qty = n,
            itemID = itemID,
          })
          return true
        end
      end
    end

    link = ApplyItemLinkAlias(link)
    local displayLink = StripDisplayedLinkBrackets(link)
    local out = displayLink
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
      handled = true
    else
      Print(FormatOtherLine(playerName, out))
      handled = true
    end

    LootChat.CaptureChatOut("CHAT_MSG_LOOT", out, {
      handled = true,
      isSelfLoot = isSelfLoot and true or false,
      player = (not isSelfLoot) and playerName or nil,
      qty = tonumber(qty),
      itemID = CaptureItemIDFromLink(link),
      combine = LootChat.LootCombineEnabled() and true or false,
    })
  end

  local suppress = (handled and DB and DB.hideLootText) and true or false
  if dbgLootPrefixLine then
    DebugPrint(string.format(
      "OnLootChat(prefix): handled=%s suppress=%s isSelfLoot=%s link=%s qty=%s hasItem=%s",
      tostring(handled and true or false),
      tostring(suppress),
      tostring(isSelfLoot and true or false),
      tostring(link),
      tostring(qty),
      tostring(string.find(msg, "|Hitem:", 1, true) ~= nil)
    ))
  end
  return suppress
end

local function OnAchievementChat(_, _, msg, author, ...)
  EnsureRefs()
  if not (DB and DB.other and DB.other.achievement and DB.other.achievement.enabled) then
    return false
  end
  if not IsNonEmptyPublicString(msg) then
    return false
  end

  local link = ExtractAchievementLinkFallback(msg)
  if not link then
    return false
  end

  local name = StripRealmFromName(author)
  if not IsNonEmptyPublicString(name) then
    name = "Character"
  end

  local displayLink = StripDisplayedLinkBrackets(link)
  local out = string.format("%s: earned %s!", name, displayLink)

  local outFrame = (DB.other and DB.other.outputChatFrame) or (DB and DB.outputChatFrame) or 1
  PrintToChatFrame(out, outFrame)

  return true
end

function LootChat.ApplyFilters()
  EnsureRefs()

  -- Install direct-print suppression once; only activates when enabled+hideLootText.
  HookAllChatFramesAddMessage()

  local dbg = (DB and DB.debugChatSetup) == true
  local function D(s)
    if not dbg then return end
    local outFrame = (DB and DB.outputChatFrame) or 1
    PrintToChatFrame("[LootIt ChatDebug] " .. tostring(s or ""), outFrame)
  end

  if dbg then
    local outFrame = (DB and DB.outputChatFrame) or 1
    local otherFrame = (DB and DB.other and DB.other.outputChatFrame) or nil
    local outName = GetChatWindowName(outFrame) or "?"
    local otherName = otherFrame and (GetChatWindowName(otherFrame) or "?") or "(nil)"
    local ach = (DB and DB.other and DB.other.achievement and DB.other.achievement.enabled) and true or false
    D(string.format(
      "ApplyFilters begin enabled=%s output=%s('%s') other=%s('%s') achievement=%s",
      tostring(IsEnabled()), tostring(outFrame), tostring(outName), tostring(otherFrame), tostring(otherName), tostring(ach)
    ))
  end

  if not ChatFrame_AddMessageEventFilter then
    ChatFrame_AddMessageEventFilter = _G and rawget(_G, "ChatFrame_AddMessageEventFilter")
  end
  if not ChatFrame_RemoveMessageEventFilter then
    ChatFrame_RemoveMessageEventFilter = _G and rawget(_G, "ChatFrame_RemoveMessageEventFilter")
  end
  if not (ChatFrame_AddMessageEventFilter and ChatFrame_RemoveMessageEventFilter) then return end

  if dbg then
    D(string.format("ChatFrame_AddMessageEventFilter=%s Remove=%s", type(ChatFrame_AddMessageEventFilter), type(ChatFrame_RemoveMessageEventFilter)))
  end

  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_LOOT", OnLootChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_CURRENCY", OnCurrencyChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONEY", OnMoneyChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", OnSystemChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_COMBAT_MISC_INFO", OnSystemChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SKILL", OnSystemChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_TRADESKILLS", OnSystemChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_ACHIEVEMENT", OnAchievementChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_GUILD_ACHIEVEMENT", OnAchievementChat)
  if IsEnabled() then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", OnLootChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CURRENCY", OnCurrencyChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_MONEY", OnMoneyChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", OnSystemChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_MISC_INFO", OnSystemChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SKILL", OnSystemChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_TRADESKILLS", OnSystemChat)
  end
  if DB and DB.other and DB.other.achievement and DB.other.achievement.enabled then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_ACHIEVEMENT", OnAchievementChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD_ACHIEVEMENT", OnAchievementChat)
  end

  if dbg then
    local enabled = IsEnabled() and true or false
    local ach = (DB and DB.other and DB.other.achievement and DB.other.achievement.enabled) and true or false
    D(string.format("ApplyFilters done (enabled=%s, achievement=%s)", tostring(enabled), tostring(ach)))
  end
end

function LootChat.ApplyFiltersSoon(delaySeconds)
  if not (C_Timer and C_Timer.After) then return end
  local d = tonumber(delaySeconds) or 0
  if d < 0 then d = 0 end
  C_Timer.After(d, function()
    EnsureRefs()
    LootChat.ApplyFilters()
  end)
end

function LootChat.GetSupportedMessageLines()
  local lines = {}
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

  lines[#lines + 1] = ""
  lines[#lines + 1] = "CHAT_MSG_SYSTEM"
  lines[#lines + 1] = "  - Filters 'You receive item: ...' reward lines when they show up as system messages"
  lines[#lines + 1] = "  - GlobalString keys:"
  lines[#lines + 1] = "    - YOU_RECEIVE_ITEM"
  lines[#lines + 1] = "    - YOU_RECEIVE_ITEM_MULTIPLE"
  return lines
end
