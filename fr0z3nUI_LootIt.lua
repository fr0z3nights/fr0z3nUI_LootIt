local ADDON = ...

local PREFIX = "|cff00ccff[LI]|r "

local DEFAULTS = {
  enabled = false,
  hideLootText = true, -- suppress the default "You receive loot:" chat line
  echoItem = true, -- re-print a simplified line with just the item link
  echoPrefix = "", -- optional; leave blank for no prefix
  outputChatFrame = 1,
  showSelfNameInGroup = true,
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
}

fr0z3nUI_LootItDB = fr0z3nUI_LootItDB or nil
local DB

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
  DB = CopyDefaults(fr0z3nUI_LootItDB, DEFAULTS)
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
  if IsInRaid and IsInRaid() then return true end
  if IsInGroup and IsInGroup() then return true end
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

  local ilvl
  if C_Item and C_Item.GetDetailedItemLevelInfo then
    ilvl = C_Item.GetDetailedItemLevelInfo(link)
  end

  if type(ilvl) == "number" and ilvl > 0 then
    return string.format(" (ilvl %d)", ilvl)
  end

  return nil
end

local function ExtractCurrencyLinkFallback(msg)
  if type(msg) ~= "string" then return nil end
  return msg:match("(|c%x+|Hcurrency:.-|h%[.-%]|h|r)")
    or msg:match("(|Hcurrency:.-|h%[.-%]|h)")
end

local function FormatSelfLine(text)
  if DB and DB.showSelfNameInGroup and IsInAnyGroup() then
    local me = GetClassColoredName(UnitName and UnitName("player"))
    if me and me ~= "" then
      return string.format("%s: %s", me, text)
    end
  end
  return text
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
  if not (DB and DB.enabled) then return false end
  if type(msg) ~= "string" or msg == "" then return false end

  if not CURRENCY_PATTERNS then BuildCurrencyPatterns() end

  local isSelf = false
  if CURRENCY_PREFIXES and #CURRENCY_PREFIXES > 0 then
    for _, prefix in ipairs(CURRENCY_PREFIXES) do
      if msg:sub(1, #prefix) == prefix then
        isSelf = true
        break
      end
    end
  end
  if not isSelf then
    return false
  end

  local link, qty
  for _, pat in ipairs(CURRENCY_PATTERNS or {}) do
    local a, b = msg:match(pat)
    if a then
      if b then
        link, qty = a, b
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

  if DB.echoItem then
    local out = link
    local n = tonumber(qty)
    if n and n > 1 then
      out = string.format("%s x%d", link, n)
    end
    Print(FormatSelfLine(out))
  end

  return DB.hideLootText and true or false
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

  -- Fallback: money words/symbols (best-effort, localized when possible).
  local lower = msg:lower()
  local function hasToken(token)
    if type(token) ~= "string" or token == "" then return false end
    return lower:find(token:lower(), 1, true) ~= nil
  end
  if hasToken((_G and rawget(_G, "GOLD")) or "gold") or hasToken((_G and rawget(_G, "SILVER")) or "silver") or hasToken((_G and rawget(_G, "COPPER")) or "copper") then
    return true
  end
  if hasToken((_G and rawget(_G, "GOLD_AMOUNT_SYMBOL")) or "g") and hasToken((_G and rawget(_G, "SILVER_AMOUNT_SYMBOL")) or "s") then
    return true
  end

  if not MONEY_PATTERNS then BuildMoneyPatterns() end

  -- Prefer matching the full localized string, but keep prefix fallback too.
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

  return false
end

local function OnMoneyChat(_, _, msg, ...)
  if not (DB and DB.enabled) then return false end
  if type(msg) ~= "string" or msg == "" then return false end

  if not IsLikelyMoneyMessage(msg) then return false end

  if DB.echoItem then
    local coins = ParseCoinsFromMoneyMessage(msg)
    local out = FormatMoney(coins)
    if out then
      Print(FormatSelfLine(out))
    end
  end

  -- Hide the original even if we can't parse/reprint it.
  return DB.hideLootText and true or false
end

local function OnLootChat(_, _, msg, author, ...)
  if not (DB and DB.enabled) then return false end
  if type(msg) ~= "string" or msg == "" then return false end

  if not LOOT_PATTERNS then BuildLootPatterns() end

  -- Some clients/sources emit coin loot via CHAT_MSG_LOOT instead of CHAT_MSG_MONEY.
  -- Catch and filter it here so "You loot X gold/silver/copper" doesn't leak through.
  if IsLikelyMoneyMessage(msg) then
    if DB.echoItem then
      local coins = ParseCoinsFromMoneyMessage(msg)
      local out = FormatMoney(coins)
      if out then
        Print(FormatSelfLine(out))
      end
    end
    return DB.hideLootText and true or false
  end

  local isSelfLoot = false
  local playerName
  local link, qty

  -- Detect self loot via localized prefixes.
  if LOOT_PREFIXES and #LOOT_PREFIXES > 0 then
    for _, prefix in ipairs(LOOT_PREFIXES) do
      if msg:sub(1, #prefix) == prefix then
        isSelfLoot = true
        break
      end
    end
  end

  if isSelfLoot then
    for _, pat in ipairs(LOOT_PATTERNS or {}) do
      local a, b = msg:match(pat)
      if a then
        if b then
          link, qty = a, b
        else
          link = a
        end
        break
      end
    end
  else
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
    local out = link
    local n = tonumber(qty)
    if n and n > 1 then
      out = string.format("%s x%d", link, n)
    else
      out = NormalizeItemLink(ExtractLinkFallback(msg) or link)
    end

    local suffix = GetEquippableItemLevelSuffix(link)
    if suffix then
      out = out .. suffix
    end

    if isSelfLoot then
      Print(FormatSelfLine(out))
    else
      Print(FormatOtherLine(playerName, out))
    end
  end

  return DB.hideLootText and true or false
end

local function ApplyFilters()
  if not ChatFrame_AddMessageEventFilter then return end
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_LOOT", OnLootChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_CURRENCY", OnCurrencyChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONEY", OnMoneyChat)
  if DB and DB.enabled then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", OnLootChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CURRENCY", OnCurrencyChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_MONEY", OnMoneyChat)
  end
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

  frame:SetSize(420, 430)
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

  frame.TitleText:SetText("fr0z3nUI LootIt")

  local sub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  sub:SetPoint("TOPLEFT", frame.InsetBg, "TOPLEFT", 10, -10)
  sub:SetJustifyH("LEFT")
  sub:SetText("Filters loot chat lines and can re-print clean output.")

  local enabled = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  enabled:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", -2, -10)
  SetCheckBoxText(enabled, "Enable LootIt")
  enabled:SetScript("OnClick", function(self)
    EnsureDB()
    DB.enabled = self:GetChecked() and true or false
    ApplyFilters()
  end)

  local hide = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  hide:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -6)
  SetCheckBoxText(hide, "Hide default loot chat line")
  hide:SetScript("OnClick", function(self)
    EnsureDB()
    DB.hideLootText = self:GetChecked() and true or false
  end)

  local outputLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  outputLabel:SetPoint("TOPLEFT", hide, "BOTTOMLEFT", 2, -12)
  outputLabel:SetText("Output to")

  local outputDD = CreateFrame("Frame", "fr0z3nUI_LootIt_OutputDropDown", frame, "UIDropDownMenuTemplate")
  outputDD:SetPoint("LEFT", outputLabel, "RIGHT", -8, -2)
  UIDropDownMenu_SetWidth(outputDD, 230)

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
        if CloseDropDownMenus then CloseDropDownMenus() end
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  local echo = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  echo:SetPoint("TOPLEFT", outputLabel, "BOTTOMLEFT", -2, -10)
  SetCheckBoxText(echo, "Echo simplified item-only line")
  echo:SetScript("OnClick", function(self)
    EnsureDB()
    DB.echoItem = self:GetChecked() and true or false
  end)

  local selfName = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  selfName:SetPoint("TOPLEFT", echo, "BOTTOMLEFT", 0, -6)
  SetCheckBoxText(selfName, "In groups, show my name too")
  selfName:SetScript("OnClick", function(self)
    EnsureDB()
    DB.showSelfNameInGroup = self:GetChecked() and true or false
  end)

  local moneyLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  moneyLabel:SetPoint("TOPLEFT", selfName, "BOTTOMLEFT", 2, -12)
  moneyLabel:SetText("Money output")

  local moneyGold = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  moneyGold:SetPoint("TOPLEFT", moneyLabel, "BOTTOMLEFT", -2, -6)
  SetCheckBoxText(moneyGold, "Gold")
  moneyGold:SetScript("OnClick", function(self)
    EnsureDB()
    DB.money = DB.money or {}
    DB.money.gold = self:GetChecked() and true or false
  end)

  local moneySilver = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  moneySilver:SetPoint("TOPLEFT", moneyGold, "BOTTOMLEFT", 0, -4)
  SetCheckBoxText(moneySilver, "Silver")
  moneySilver:SetScript("OnClick", function(self)
    EnsureDB()
    DB.money = DB.money or {}
    DB.money.silver = self:GetChecked() and true or false
  end)

  local moneyCopper = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  moneyCopper:SetPoint("TOPLEFT", moneySilver, "BOTTOMLEFT", 0, -4)
  SetCheckBoxText(moneyCopper, "Copper")
  moneyCopper:SetScript("OnClick", function(self)
    EnsureDB()
    DB.money = DB.money or {}
    DB.money.copper = self:GetChecked() and true or false
  end)

  local prefixLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  prefixLabel:SetPoint("TOPLEFT", moneyCopper, "BOTTOMLEFT", 2, -12)
  prefixLabel:SetText("Prefix (optional)")

  local prefixBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  prefixBox:SetSize(280, 20)
  prefixBox:SetPoint("LEFT", prefixLabel, "RIGHT", 10, 0)
  prefixBox:SetAutoFocus(false)
  prefixBox:SetScript("OnEnterPressed", function(self)
    EnsureDB()
    DB.echoPrefix = tostring(self:GetText() or "")
    self:ClearFocus()
  end)
  prefixBox:SetScript("OnEscapePressed", function(self)
    self:SetText(DB and DB.echoPrefix or PREFIX)
    self:ClearFocus()
  end)

  local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  reset:SetSize(120, 22)
  reset:SetPoint("TOPLEFT", prefixLabel, "BOTTOMLEFT", 0, -12)
  reset:SetText("Reset Defaults")
  reset:SetScript("OnClick", function()
    fr0z3nUI_LootItDB = {}
    EnsureDB()
    ApplyFilters()
    SetCheckBoxChecked(enabled, DB.enabled)
    SetCheckBoxChecked(hide, DB.hideLootText)
    SetCheckBoxChecked(echo, DB.echoItem)
    prefixBox:SetText(DB.echoPrefix or "")
  end)

  local supportedLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  supportedLabel:SetPoint("TOPLEFT", reset, "BOTTOMLEFT", 0, -18)
  supportedLabel:SetText("Messages it can handle")

  local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", supportedLabel, "BOTTOMLEFT", 0, -8)
  scroll:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", -28, 10)

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

  frame:SetScript("OnShow", function(self)
    EnsureDB()
    SetCheckBoxChecked(enabled, DB.enabled)
    SetCheckBoxChecked(hide, DB.hideLootText)
    SetCheckBoxChecked(echo, DB.echoItem)
    SetCheckBoxChecked(selfName, DB.showSelfNameInGroup)
    DB.money = DB.money or {}
    SetCheckBoxChecked(moneyGold, DB.money.gold ~= false)
    SetCheckBoxChecked(moneySilver, DB.money.silver == true)
    SetCheckBoxChecked(moneyCopper, DB.money.copper == true)
    UIDropDownMenu_SetSelectedID(outputDD, DB.outputChatFrame or 1)
    prefixBox:SetText(DB.echoPrefix or "")
    if DB.ui then
      self:ClearAllPoints()
      self:SetPoint(DB.ui.point or "CENTER", UIParent, DB.ui.point or "CENTER", DB.ui.x or 0, DB.ui.y or 0)
    end
    RefreshSupportedList()
  end)

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

SLASH_FR0Z3NUI_LOOTIT1 = "/fli"
SLASH_FR0Z3NUI_LOOTIT2 = "/lootit"
SlashCmdList.FR0Z3NUI_LOOTIT = function(msg)
  EnsureDB()
  msg = tostring(msg or "")
  local cmd, rest = msg:match("^(%S+)%s*(.-)$")
  cmd = (cmd and cmd:lower()) or ""

  local function Status()
    local e = (DB.enabled and "on" or "off")
    local h = (DB.hideLootText and "on" or "off")
    local x = (DB.echoItem and "on" or "off")
    Print(string.format("enabled=%s, hide=%s, echo=%s", e, h, x))
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
    Print("/fli status")
    return
  end

  if cmd == "status" then
    Status()
    return
  end

  if cmd == "ui" or cmd == "config" or cmd == "options" then
    ToggleConfigUI()
    return
  end

  if cmd == "on" or cmd == "enable" then
    DB.enabled = true
    ApplyFilters()
    Status()
    return
  end

  if cmd == "off" or cmd == "disable" then
    DB.enabled = false
    Status()
    return
  end

  if cmd == "toggle" then
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
    DB.showSelfNameInGroup = (v ~= "off" and v ~= "0" and v ~= "false")
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

  Print("Unknown command. Try /fli ?")
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  EnsureDB()
  ApplyFilters()
end)
