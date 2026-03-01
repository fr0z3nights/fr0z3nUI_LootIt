local ADDON = ...

local PREFIX = "|cff00ccff[LI]|r "

local SANITY_VERSION = "260301-002"

local LI = fr0z3nUI_LootIt or {}
fr0z3nUI_LootIt = LI
LI.PREFIX = PREFIX
LI.SANITY_VERSION = SANITY_VERSION

local function Print(msg)
  local frame = DEFAULT_CHAT_FRAME
  if frame and frame.AddMessage then
    frame:AddMessage(PREFIX .. tostring(msg or ""))
  end
end

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

LI.AddonLinkAliases = ADDON_LINK_ALIASES
LI.AddonCurrencyAliases = ADDON_CURRENCY_ALIASES

local DEFAULTS = {
  enabled = true,
  hideLootText = true, -- suppress the default "You receive loot:" chat line
  echoItem = true, -- re-print a simplified line with just the item link
  showItemLevel = true, -- append (ilvl N) for equippable items
  ignoredItemIDs = {}, -- [itemID] = true hides the item from chat (suppresses both original + LootIt output)
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

  -- Delay-print: aggregate spammy items and print once after a delay.
  -- Configured per itemID via the Alias tab.
  delayPrint = {
    enabled = true,
    itemSeconds = {
      -- Darkmoon:
      [71083] = 30, -- Darkmoon Game Token
      -- Sack/Pouch o' Tokens variants:
      [78910] = 2,
      [78909] = 2,
      [78908] = 2,
      [78907] = 2,
      [78906] = 2,
      [78905] = 2,
      [78904] = 2,
    },
    flushOnMerchantClose = true,
  },

  mailNotify = {
    enabled = true,
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

  -- Debug capture: stores recent raw chat events and LootIt output decisions.
  -- Use via: /fli capture on|off|status|dump|clear|max|stacks
  debugCapture = false,
  debugCaptureMax = 200,
  debugCaptureStacks = false,

  -- Debug: print chat filter setup & ChatFrame mapping hints.
  -- Use via: /fli chatdebug on|off|toggle|status|dump
  debugChatSetup = false,

  tax = {
    enabled = false,
    rate = 0, -- percent (0..100)
    quiet = false,
    due = 0, -- copper
    paidToDate = 0, -- copper
    sources = {
      vendor = true,
      questLoot = true, -- CHAT_MSG_MONEY
      systemMoney = false, -- CHAT_MSG_SYSTEM (off by default)
      mail = true,
    },
    autoPayOnGuildBankOpen = false,
  },

  -- Deposit helper (bank open + command/button pressed).
  deposit = {
    tradeMode = "deposit", -- deposit | buy | sell
    target = "bank", -- bank | guild | warbank
    guildTab = 0, -- legacy fallback; 0=current tab; 1..8 specific tab
    guildTabByRealm = {}, -- [realm] = 0..8
    showButton = true,
    sellFoodEnabled = false,
    sellFoodEnabledAcc = false,
    sellFoodLevelDiff = 10,
    itemsAcc = {}, -- [itemID] = true
    itemsRealm = {}, -- [realm] = { [itemID] = true }

    -- Vendor buy/sell rules (stored as: [itemID] = { count=<number>, restock=<bool?> } )
    buyItemsAcc = {},
    buyItemsRealm = {}, -- [realm] = { [itemID] = rule }
    sellItemsAcc = {},
    sellItemsRealm = {}, -- [realm] = { [itemID] = rule }
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
  if type(DB.ignoredItemIDs) ~= "table" then DB.ignoredItemIDs = {} end
  if type(CHARDB.linkAliases) ~= "table" then CHARDB.linkAliases = {} end
  if type(CHARDB.linkAliasDisabledChar) ~= "table" then CHARDB.linkAliasDisabledChar = {} end

  if type(CHARDB.currencyAliases) ~= "table" then CHARDB.currencyAliases = {} end
  if type(CHARDB.currencyAliasDisabledChar) ~= "table" then CHARDB.currencyAliasDisabledChar = {} end

  -- Deposit config (account list + per-character list/overrides).
  if type(DB.deposit) ~= "table" then DB.deposit = {} end
  if DB.deposit.tradeMode == nil then DB.deposit.tradeMode = "deposit" end
  if type(DB.deposit.itemsAcc) ~= "table" then DB.deposit.itemsAcc = {} end
  if type(DB.deposit.itemsRealm) ~= "table" then DB.deposit.itemsRealm = {} end
  if type(DB.deposit.guildTabByRealm) ~= "table" then DB.deposit.guildTabByRealm = {} end
  if type(DB.deposit.buyItemsAcc) ~= "table" then DB.deposit.buyItemsAcc = {} end
  if type(DB.deposit.buyItemsRealm) ~= "table" then DB.deposit.buyItemsRealm = {} end
  if type(DB.deposit.sellItemsAcc) ~= "table" then DB.deposit.sellItemsAcc = {} end
  if type(DB.deposit.sellItemsRealm) ~= "table" then DB.deposit.sellItemsRealm = {} end
  if DB.deposit.sellFoodEnabled == nil then DB.deposit.sellFoodEnabled = false end
  if DB.deposit.sellFoodEnabledAcc == nil then
    -- Migration: older builds only had DB.deposit.sellFoodEnabled.
    DB.deposit.sellFoodEnabledAcc = (DB.deposit.sellFoodEnabled == true) and true or false
  end
  if DB.deposit.sellFoodLevelDiff == nil then DB.deposit.sellFoodLevelDiff = 10 end
  if DB.deposit.target == nil then DB.deposit.target = "bank" end
  if DB.deposit.guildTab == nil then DB.deposit.guildTab = 0 end
  if DB.deposit.showButton == nil then DB.deposit.showButton = true end

  -- Guild enable/disable (account-wide). Tracks guilds seen on any character.
  if type(DB.deposit.guildsSeen) ~= "table" then DB.deposit.guildsSeen = {} end
  if type(DB.deposit.guildEnabled) ~= "table" then DB.deposit.guildEnabled = {} end

  do
    local d = tonumber(DB.deposit.sellFoodLevelDiff)
    d = d and math.floor(d) or 10
    if d < 1 then d = 1 end
    if d > 80 then d = 80 end
    DB.deposit.sellFoodLevelDiff = d
  end

  -- The config UI no longer exposes toggling this; keep the on-screen button on.
  DB.deposit.showButton = true

  do
    local m = tostring(DB.deposit.tradeMode or ""):lower():gsub("%s+", "")
    if m ~= "deposit" and m ~= "buy" and m ~= "sell" then
      m = "deposit"
    end
    DB.deposit.tradeMode = m
  end

  -- Migration: previous targets were guild|warband|either.
  do
    local t = tostring(DB.deposit.target or "")
    t = t:lower():gsub("%s+", "")
    if t == "either" then t = "bank" end
    if t == "warband" then t = "warbank" end
    if t == "warbank" or t == "guild" or t == "bank" then
      DB.deposit.target = t
    else
      DB.deposit.target = "bank"
    end
  end

  if type(CHARDB.deposit) ~= "table" then CHARDB.deposit = {} end
  if type(CHARDB.deposit.itemsChar) ~= "table" then CHARDB.deposit.itemsChar = {} end
  if type(CHARDB.deposit.disableAcc) ~= "table" then CHARDB.deposit.disableAcc = {} end
  if type(CHARDB.deposit.buyItemsChar) ~= "table" then CHARDB.deposit.buyItemsChar = {} end
  if type(CHARDB.deposit.buyDisableAcc) ~= "table" then CHARDB.deposit.buyDisableAcc = {} end
  if type(CHARDB.deposit.sellItemsChar) ~= "table" then CHARDB.deposit.sellItemsChar = {} end
  if type(CHARDB.deposit.sellDisableAcc) ~= "table" then CHARDB.deposit.sellDisableAcc = {} end
  if CHARDB.deposit.sellFoodEnabledChar == nil then CHARDB.deposit.sellFoodEnabledChar = false end

  if DB and type(DB.other) ~= "table" then
    DB.other = {}
  end
  if DB and DB.other and DB.other.outputChatFrame == nil then
    DB.other.outputChatFrame = DB.outputChatFrame or 1
  end

  if DB then
    if type(DB.delayPrint) ~= "table" then DB.delayPrint = {} end
    if type(DB.delayPrint.itemSeconds) ~= "table" then DB.delayPrint.itemSeconds = {} end
    if DB.delayPrint.enabled == nil then DB.delayPrint.enabled = true end
    if DB.delayPrint.flushOnMerchantClose == nil then DB.delayPrint.flushOnMerchantClose = true end
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

  -- Mail notifier config is per-character (enabled remains account-wide + char override).
  do
    -- Migration (2026-02-12): reset per-character mail settings to defaults on next load.
    -- IMPORTANT: Older versions stored mail notifier config account-wide; we must ensure
    -- the reset is not immediately overwritten by that legacy migration.
    if CHARDB then
      -- First-time reset.
      if CHARDB._m20260212_mailReset ~= true then
        CHARDB.mailNotifyEnabledOverride = nil
        CHARDB.mailNotify = { _migratedFromAcc = true, _resetToDefaults = true }
        CHARDB._m20260212_mailReset = true
      end

      -- Repair: earlier builds cleared mailNotify, then re-imported from account DB.
      -- If that happened, apply the intended reset once.
      if CHARDB._m20260212_mailReset == true then
        if type(CHARDB.mailNotify) ~= "table" or CHARDB.mailNotify._resetToDefaults ~= true then
          CHARDB.mailNotifyEnabledOverride = nil
          CHARDB.mailNotify = { _migratedFromAcc = true, _resetToDefaults = true }
        end
      end
    end

    if type(CHARDB.mailNotify) ~= "table" then
      CHARDB.mailNotify = {}
    end

    -- Migration: older versions stored mail notifier config account-wide.
    if type(fr0z3nUI_LootItDB.mailNotify) == "table" and not CHARDB.mailNotify._migratedFromAcc then
      local acc = fr0z3nUI_LootItDB.mailNotify
      local ch = CHARDB.mailNotify
      if ch.showInCombat == nil and acc.showInCombat ~= nil then
        ch.showInCombat = (acc.showInCombat ~= false)
      end
      if type(ch.model) ~= "table" and type(acc.model) == "table" then
        ch.model = CopyDefaults({}, acc.model)
      end
      if type(ch.ui) ~= "table" and type(acc.ui) == "table" then
        ch.ui = CopyDefaults({}, acc.ui)
      end
      ch._migratedFromAcc = true
    end

    local mn = CHARDB.mailNotify
    if mn.showInCombat == nil then mn.showInCombat = true end

    if type(mn.model) ~= "table" then mn.model = {} end
    if mn.model.kind == nil then mn.model.kind = "npc" end
    if mn.model.id == nil then mn.model.id = 104230 end -- Dalaran Mailemental
    if mn.model.rotation == nil then mn.model.rotation = 0.15 end
    if mn.model.zoom == nil then mn.model.zoom = 0.9 end
    if mn.model.anim == nil then mn.model.anim = 0 end
    if mn.model.animRandom == nil then mn.model.animRandom = false end
    if mn.model.animRepeat == nil then mn.model.animRepeat = false end
    if mn.model.animRepeatSec == nil then mn.model.animRepeatSec = 10 end

    if type(mn.ui) ~= "table" then mn.ui = {} end
    if mn.ui.point == nil then mn.ui.point = "TOPRIGHT" end
    if mn.ui.x == nil then mn.ui.x = -260 end
    if mn.ui.y == nil then mn.ui.y = -220 end
    if mn.ui.w == nil then mn.ui.w = 200 end
    if mn.ui.h == nil then mn.ui.h = 220 end
    if mn.ui.alpha == nil then mn.ui.alpha = 0.5 end
    if mn.ui.strata == nil then mn.ui.strata = "BACKGROUND" end
  end
end

local function GetCurrentGuildKey()
  if type(IsInGuild) == "function" then
    local ok, inGuild = pcall(IsInGuild)
    if ok and inGuild ~= true then
      return nil
    end
  end
  if type(GetGuildInfo) ~= "function" then
    return nil
  end
  local ok, guildName = pcall(GetGuildInfo, "player")
  guildName = ok and guildName or nil
  if type(guildName) ~= "string" or guildName == "" then
    return nil
  end
  local realm = (type(GetRealmName) == "function") and GetRealmName() or nil
  realm = (type(realm) == "string" and realm ~= "") and realm or ""
  return realm .. "::" .. guildName, guildName, realm
end

local function UpdateSeenGuilds()
  EnsureDB()
  if not (DB and DB.deposit) then return end
  local key, guildName, realm = GetCurrentGuildKey()
  if not key then return end

  DB.deposit.guildsSeen = (type(DB.deposit.guildsSeen) == "table") and DB.deposit.guildsSeen or {}
  DB.deposit.guildEnabled = (type(DB.deposit.guildEnabled) == "table") and DB.deposit.guildEnabled or {}

  DB.deposit.guildsSeen[key] = DB.deposit.guildsSeen[key] or {}
  local rec = DB.deposit.guildsSeen[key]
  rec.name = guildName
  rec.realm = realm
  if type(GetServerTime) == "function" then
    local okT, t = pcall(GetServerTime)
    if okT and tonumber(t) then rec.lastSeen = tonumber(t) end
  elseif type(time) == "function" then
    local okT, t = pcall(time)
    if okT and tonumber(t) then rec.lastSeen = tonumber(t) end
  end

  if DB.deposit.guildEnabled[key] == nil then
    DB.deposit.guildEnabled[key] = true
  end
end

LI.EnsureDB = EnsureDB
LI.GetDB = function()
  EnsureDB()
  return DB
end
LI.GetCharDB = function()
  EnsureDB()
  return CHARDB
end

local function IsIgnoredItemID(itemID)
  return (DB and type(DB.ignoredItemIDs) == "table" and DB.ignoredItemIDs[itemID] == true) and true or false
end

local function IsItemLevelEnabled()
  if CHARDB and CHARDB.showItemLevel ~= nil then
    return (CHARDB.showItemLevel == true)
  end
  return (DB and DB.showItemLevel ~= false) and true or false
end

-- Deposit helpers
local function DepositCfgAcc()
  EnsureDB()
  DB.deposit = (type(DB.deposit) == "table") and DB.deposit or {}
  if DB.deposit.tradeMode == nil then DB.deposit.tradeMode = "deposit" end
  if DB.deposit.keepAmount == nil then DB.deposit.keepAmount = 0 end
  if DB.deposit.stackPull == nil then DB.deposit.stackPull = false end -- legacy; replaced by stackPullByItem
  DB.deposit.stackPullByItem = (type(DB.deposit.stackPullByItem) == "table") and DB.deposit.stackPullByItem or {}
  DB.deposit.keepByItem = (type(DB.deposit.keepByItem) == "table") and DB.deposit.keepByItem or {}
  DB.deposit.keepScopeByItem = (type(DB.deposit.keepScopeByItem) == "table") and DB.deposit.keepScopeByItem or {}
  DB.deposit.itemsAcc = (type(DB.deposit.itemsAcc) == "table") and DB.deposit.itemsAcc or {}
  DB.deposit.itemsAccDisabled = (type(DB.deposit.itemsAccDisabled) == "table") and DB.deposit.itemsAccDisabled or {}
  DB.deposit.itemsAccDisableRealm = (type(DB.deposit.itemsAccDisableRealm) == "table") and DB.deposit.itemsAccDisableRealm or {}
  DB.deposit.itemsRealm = (type(DB.deposit.itemsRealm) == "table") and DB.deposit.itemsRealm or {}
  DB.deposit.itemsRealmDisabled = (type(DB.deposit.itemsRealmDisabled) == "table") and DB.deposit.itemsRealmDisabled or {}
  DB.deposit.guildTabByRealm = (type(DB.deposit.guildTabByRealm) == "table") and DB.deposit.guildTabByRealm or {}
  DB.deposit.guildTabRandomByRealm = (type(DB.deposit.guildTabRandomByRealm) == "table") and DB.deposit.guildTabRandomByRealm or {}
  if DB.deposit.guildTabRandom == nil then DB.deposit.guildTabRandom = false end
  DB.deposit.buyItemsAcc = (type(DB.deposit.buyItemsAcc) == "table") and DB.deposit.buyItemsAcc or {}
  DB.deposit.buyItemsAccDisabled = (type(DB.deposit.buyItemsAccDisabled) == "table") and DB.deposit.buyItemsAccDisabled or {}
  DB.deposit.buyItemsAccDisableRealm = (type(DB.deposit.buyItemsAccDisableRealm) == "table") and DB.deposit.buyItemsAccDisableRealm or {}
  DB.deposit.buyItemsRealm = (type(DB.deposit.buyItemsRealm) == "table") and DB.deposit.buyItemsRealm or {}
  DB.deposit.buyItemsRealmDisabled = (type(DB.deposit.buyItemsRealmDisabled) == "table") and DB.deposit.buyItemsRealmDisabled or {}
  DB.deposit.sellItemsAcc = (type(DB.deposit.sellItemsAcc) == "table") and DB.deposit.sellItemsAcc or {}
  DB.deposit.sellItemsAccDisabled = (type(DB.deposit.sellItemsAccDisabled) == "table") and DB.deposit.sellItemsAccDisabled or {}
  DB.deposit.sellItemsAccDisableRealm = (type(DB.deposit.sellItemsAccDisableRealm) == "table") and DB.deposit.sellItemsAccDisableRealm or {}
  DB.deposit.sellItemsRealm = (type(DB.deposit.sellItemsRealm) == "table") and DB.deposit.sellItemsRealm or {}
  DB.deposit.sellItemsRealmDisabled = (type(DB.deposit.sellItemsRealmDisabled) == "table") and DB.deposit.sellItemsRealmDisabled or {}

  -- One-time migration (stage 1): old global keepAmount -> per-item keepByItem for
  -- account/realm Deposit items. Character items are migrated in DepositCfgChar
  -- (stage 2) after CHARDB tables are initialized.
  if DB.deposit._keepMigratedAcc ~= true then
    local legacy = tonumber(DB.deposit.keepAmount) or 0
    legacy = legacy and math.floor(legacy) or 0
    if legacy < 1 then legacy = 0 end
    if legacy > 9999 then legacy = 9999 end

    DB.deposit._keepLegacyValue = (legacy > 0) and legacy or nil

    if legacy > 0 then
      local function applyTo(tbl)
        if type(tbl) ~= "table" then return end
        for k, v in pairs(tbl) do
          if v == true then
            local id = tonumber(k)
            if id and id > 0 and DB.deposit.keepByItem[id] == nil then
              DB.deposit.keepByItem[id] = legacy
            end
          end
        end
      end

      applyTo(DB.deposit.itemsAcc)
      if type(DB.deposit.itemsRealm) == "table" then
        for _, realmTbl in pairs(DB.deposit.itemsRealm) do
          applyTo(realmTbl)
        end
      end
    end

    -- Clear legacy value to avoid UI confusion.
    DB.deposit.keepAmount = 0
    DB.deposit._keepMigratedAcc = true
  end
  return DB.deposit
end

LI.DepositCfgAcc = DepositCfgAcc

local function GetCurrentRealmKey()
  local rn = (type(GetRealmName) == "function") and GetRealmName() or nil
  rn = (type(rn) == "string" and rn ~= "") and rn or ""
  return rn
end

local function DepositCfgRealm()
  local cfg = DepositCfgAcc()
  local rk = GetCurrentRealmKey()
  if rk == "" then
    return nil, nil
  end
  cfg.itemsRealm = (type(cfg.itemsRealm) == "table") and cfg.itemsRealm or {}
  cfg.itemsRealm[rk] = (type(cfg.itemsRealm[rk]) == "table") and cfg.itemsRealm[rk] or {}
  return cfg.itemsRealm[rk], rk
end

local function DepositCfgChar()
  EnsureDB()
  CHARDB.deposit = (type(CHARDB.deposit) == "table") and CHARDB.deposit or {}
  CHARDB.deposit.itemsChar = (type(CHARDB.deposit.itemsChar) == "table") and CHARDB.deposit.itemsChar or {}
  CHARDB.deposit.itemsCharDisabled = (type(CHARDB.deposit.itemsCharDisabled) == "table") and CHARDB.deposit.itemsCharDisabled or {}
  CHARDB.deposit.disableAcc = (type(CHARDB.deposit.disableAcc) == "table") and CHARDB.deposit.disableAcc or {}
  CHARDB.deposit.disableRealm = (type(CHARDB.deposit.disableRealm) == "table") and CHARDB.deposit.disableRealm or {}
  CHARDB.deposit.buyDisableRealm = (type(CHARDB.deposit.buyDisableRealm) == "table") and CHARDB.deposit.buyDisableRealm or {}
  CHARDB.deposit.sellItemsChar = (type(CHARDB.deposit.sellItemsChar) == "table") and CHARDB.deposit.sellItemsChar or {}
  CHARDB.deposit.sellItemsCharDisabled = (type(CHARDB.deposit.sellItemsCharDisabled) == "table") and CHARDB.deposit.sellItemsCharDisabled or {}
  CHARDB.deposit.sellDisableAcc = (type(CHARDB.deposit.sellDisableAcc) == "table") and CHARDB.deposit.sellDisableAcc or {}
  CHARDB.deposit.sellDisableRealm = (type(CHARDB.deposit.sellDisableRealm) == "table") and CHARDB.deposit.sellDisableRealm or {}

  -- One-time migration (stage 2): apply legacy keepAmount to character-scoped Deposit items.
  do
    local acc = DepositCfgAcc()
    if acc and acc._keepMigratedChar ~= true then
      local legacy = tonumber(acc._keepLegacyValue) or 0
      legacy = legacy and math.floor(legacy) or 0
      if legacy < 1 then legacy = 0 end
      if legacy > 9999 then legacy = 9999 end

      if legacy > 0 and type(acc.keepByItem) == "table" then
        for k, v in pairs(CHARDB.deposit.itemsChar or {}) do
          if v == true then
            local id = tonumber(k)
            if id and id > 0 and acc.keepByItem[id] == nil then
              acc.keepByItem[id] = legacy
            end
          end
        end
      end

      acc._keepMigratedChar = true
      if acc._keepMigratedAcc == true and acc._keepMigratedChar == true then
        acc._keepLegacyValue = nil
        acc._keepMigrated = true
      end
    end
  end
  return CHARDB.deposit
end

LI.DepositCfgChar = DepositCfgChar

local function GetEffectiveDepositItemIDs()
  local acc = DepositCfgAcc()
  local ch = DepositCfgChar()
  local out = {}
  local rk = GetCurrentRealmKey()
  local accDisableRealm = (rk ~= "" and type(acc.itemsAccDisableRealm) == "table") and acc.itemsAccDisableRealm[rk] or nil
  for id, on in pairs(acc.itemsAcc or {}) do
    id = tonumber(id)
    if id and id > 0 and on == true
      and not (acc.itemsAccDisabled and acc.itemsAccDisabled[id] == true)
      and not (type(accDisableRealm) == "table" and accDisableRealm[id] == true)
      and not (ch.disableAcc and ch.disableAcc[id] == true)
    then
      out[id] = true
    end
  end
  for id, on in pairs(ch.itemsChar or {}) do
    id = tonumber(id)
    if id and id > 0 and on == true and not (ch.itemsCharDisabled and ch.itemsCharDisabled[id] == true) then
      out[id] = true
    end
  end

  do
    local realmItems = (type(acc.itemsRealm) == "table") and acc.itemsRealm[rk] or nil
    local realmDisabled = (type(acc.itemsRealmDisabled) == "table") and acc.itemsRealmDisabled[rk] or nil
    if type(realmItems) == "table" then
      for id, on in pairs(realmItems) do
        id = tonumber(id)
        if id and id > 0 and on == true
          and not (type(realmDisabled) == "table" and realmDisabled[id] == true)
          and not (ch.disableRealm and ch.disableRealm[id] == true)
        then
          out[id] = true
        end
      end
    end
  end
  return out
end

local _bankInteractionOpen = false
local _warbankInteractionOpen = false
local _guildbankInteractionOpen = false

local function IsGuildBankOpen()
  if _guildbankInteractionOpen == true then
    return true
  end
  local f = _G and rawget(_G, "GuildBankFrame")
  if f and f.IsShown and f:IsShown() then
    return true
  end
  return false
end

local function GetBankPanel()
  local p = _G and rawget(_G, "BankPanel")
  if p then return p end
  local bank = _G and rawget(_G, "BankFrame")
  if bank and bank.BankPanel then return bank.BankPanel end
  return nil
end

local function GetSelectedBankType()
  local p = GetBankPanel()
  if p and p.bankType ~= nil then
    return p.bankType
  end
  return nil
end

local function TryAutoSortBankPanel()
  local p = GetBankPanel()
  local btn = p and p.AutoSortButton or nil
  if btn and btn.IsEnabled and btn:IsEnabled() and btn.Click then
    local ok = pcall(btn.Click, btn)
    return ok == true
  end

  -- Fallbacks (older APIs/builds)
  if C_Container and type(C_Container.SortBankBags) == "function" then
    local ok = pcall(C_Container.SortBankBags)
    return ok == true
  end
  local f = _G and rawget(_G, "SortBankBags")
  if type(f) == "function" then
    local ok = pcall(f)
    return ok == true
  end
  return false
end

local function TryAutoSortGuildBank()
  local f = _G and rawget(_G, "SortGuildBankItems")
  if type(f) == "function" then
    local ok = pcall(f)
    return ok == true
  end
  local frame = _G and rawget(_G, "GuildBankFrame")
  local btn = frame and (frame.SortButton or frame.AutoSortButton) or nil
  if btn and btn.IsEnabled and btn:IsEnabled() and btn.Click then
    local ok = pcall(btn.Click, btn)
    return ok == true
  end
  return false
end

local _liGuildBankScanTip
local function GetGuildBankItemLinkSafe(tab, slot)
  tab = tonumber(tab)
  slot = tonumber(slot)
  if not tab or tab <= 0 then return nil end
  if not slot or slot <= 0 then return nil end

  if type(GetGuildBankItemLink) == "function" then
    local ok, link = pcall(GetGuildBankItemLink, tab, slot)
    link = ok and link or nil
    if type(link) == "string" and link ~= "" then
      return link
    end
  end

  if not (CreateFrame and UIParent) then return nil end
  if not _liGuildBankScanTip then
    _liGuildBankScanTip = CreateFrame("GameTooltip", "fr0z3nUI_LootIt_GuildBankScanTip", UIParent, "GameTooltipTemplate")
    _liGuildBankScanTip:SetOwner(UIParent, "ANCHOR_NONE")
  end

  if not (_liGuildBankScanTip and _liGuildBankScanTip.SetGuildBankItem and _liGuildBankScanTip.GetItem) then
    return nil
  end

  _liGuildBankScanTip:ClearLines()
  local okSet = pcall(_liGuildBankScanTip.SetGuildBankItem, _liGuildBankScanTip, tab, slot)
  if not okSet then
    return nil
  end
  local _, link = _liGuildBankScanTip:GetItem()
  if type(link) == "string" and link ~= "" then
    return link
  end
  return nil
end

local function CountItemInGuildBankTab(tab, itemID)
  if not IsGuildBankOpen() then return 0 end
  tab = tonumber(tab)
  itemID = tonumber(itemID)
  if not tab or tab <= 0 then return 0 end
  if not itemID or itemID <= 0 then return 0 end

  if QueryGuildBankTabIfNeeded then
    QueryGuildBankTabIfNeeded(tab)
  end

  local maxSlots = _G and rawget(_G, "MAX_GUILDBANK_SLOTS_PER_TAB")
  maxSlots = tonumber(maxSlots) or 98

  local total = 0
  for slot = 1, maxSlots do
    local link = GetGuildBankItemLinkSafe(tab, slot)
    if type(link) == "string" then
      local id = tonumber(string.match(link, "item:(%d+)"))
      if id and id == itemID then
        local okI, _, count = false, nil, nil
        if type(GetGuildBankItemInfo) == "function" then
          okI, _, count = pcall(GetGuildBankItemInfo, tab, slot)
        end
        count = okI and tonumber(count) or nil
        if count and count > 0 then
          total = total + count
        end
      end
    end
  end
  return total
end

local function GetResetToken(resetKind)
  resetKind = tostring(resetKind or "daily")
  local now = nil
  if type(GetServerTime) == "function" then
    local ok, v = pcall(GetServerTime)
    now = ok and tonumber(v) or nil
  end
  if not now and type(time) == "function" then
    local ok, v = pcall(time)
    now = ok and tonumber(v) or nil
  end
  if not now then return nil end

  if C_DateAndTime and type(C_DateAndTime.GetSecondsUntilWeeklyReset) == "function" and resetKind == "weekly" then
    local ok, sec = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
    sec = ok and tonumber(sec) or nil
    if sec and sec > 0 and sec < 2000000 then
      local resetAt = now + sec
      return math.floor(resetAt / 60)
    end
  end

  if C_DateAndTime and type(C_DateAndTime.GetSecondsUntilDailyReset) == "function" and resetKind == "daily" then
    local ok, sec = pcall(C_DateAndTime.GetSecondsUntilDailyReset)
    sec = ok and tonumber(sec) or nil
    if sec and sec > 0 and sec < 200000 then
      local resetAt = now + sec
      return math.floor(resetAt / 60)
    end
  end

  if type(GetQuestResetTime) == "function" and resetKind == "daily" then
    local ok, sec = pcall(GetQuestResetTime)
    sec = ok and tonumber(sec) or nil
    if sec and sec > 0 and sec < 200000 then
      -- Tokenize by the next reset moment; this stays stable throughout the day.
      local resetAt = now + sec
      return math.floor(resetAt / 60)
    end
  end

  if type(date) == "function" then
    local fmt = (resetKind == "weekly") and "%Y%W" or "%Y%m%d"
    local ok, s = pcall(date, fmt)
    if ok and type(s) == "string" then
      return tonumber(s)
    end
    return nil
  end

  return nil
end

local function RunDepositCleanupOncePerReset(bankKey, fn, scope, resetKind)
  if type(fn) ~= "function" then return false end
  EnsureDB()
  scope = tostring(scope or "account")

  local cfg
  if scope == "char" then
    cfg = DepositCfgChar()
  else
    cfg = DepositCfgAcc()
  end

  if type(cfg) ~= "table" then return fn() == true end

  cfg.cleanupOncePerReset = (type(cfg.cleanupOncePerReset) == "table") and cfg.cleanupOncePerReset or {}
  local token = GetResetToken(resetKind or "daily")
  if not token then
    return fn() == true
  end

  bankKey = tostring(bankKey or "")
  if bankKey == "" then
    bankKey = "bank"
  end

  if cfg.cleanupOncePerReset[bankKey] == token then
    return false
  end

  cfg.cleanupOncePerReset[bankKey] = token
  return fn() == true
end

local function IsPersonalBankOpen()
  -- New bank UI: single window with Character/Account tabs.
  local bankType = GetSelectedBankType()
  local charType = (Enum and Enum.BankType) and Enum.BankType.Character or nil
  local acctType = (Enum and Enum.BankType) and Enum.BankType.Account or nil
  if bankType ~= nil then
    if charType ~= nil then
      return bankType == charType
    end
    -- If we can't resolve Character constant, avoid treating Account as personal.
    if acctType ~= nil and bankType == acctType then
      return false
    end
  end

  -- Fallbacks for older UI.
  if _bankInteractionOpen == true then
    return true
  end
  local f = _G and rawget(_G, "BankFrame")
  if f and f.IsShown and f:IsShown() then
    return true
  end
  return false
end

local function IsAccountBankBagID(bagID)
  bagID = tonumber(bagID)
  if not bagID then return false end
  if not (Enum and Enum.BagIndex) then return false end
  local e = Enum.BagIndex
  return (bagID == e.AccountBankTab_1)
    or (bagID == e.AccountBankTab_2)
    or (bagID == e.AccountBankTab_3)
    or (bagID == e.AccountBankTab_4)
    or (bagID == e.AccountBankTab_5)
end

local function GetSelectedAccountBankTabBagID()
  local p = _G and rawget(_G, "AccountBankPanel")
  if not (p and p.IsVisible and p:IsVisible()) then return nil end
  if type(p.GetSelectedTabID) ~= "function" then return nil end
  local ok, tab = pcall(p.GetSelectedTabID, p)
  tab = ok and tab or nil
  if IsAccountBankBagID(tab) then
    return tab
  end
  return nil
end

local function FindShownChildByNamePattern(root, patterns)
  if not (root and root.GetChildren and type(patterns) == "table") then return nil end

  local q = { root }
  local qi = 1
  local visited = 0
  local maxNodes = 200

  while q[qi] do
    local node = q[qi]
    qi = qi + 1
    visited = visited + 1
    if visited > maxNodes then break end

    local okShown, isShown = pcall(function()
      return node.IsShown and node:IsShown()
    end)
    if okShown and isShown then
      local name = nil
      if node.GetName then
        local okName, v = pcall(node.GetName, node)
        if okName then name = v end
      end
      if type(name) == "string" and name ~= "" then
        for _, p in ipairs(patterns) do
          if type(p) == "string" and p ~= "" and name:find(p, 1, true) then
            return node
          end
        end
      end
    end

    if node.GetChildren then
      local okKids, kids = pcall(function() return { node:GetChildren() } end)
      if okKids and type(kids) == "table" then
        for i = 1, #kids do
          local child = kids[i]
          if child then q[#q + 1] = child end
        end
      end
    end
  end
  return nil
end

local function GetWarbankFrame()
  local candidates = {
    "AccountBankFrame",
    "AccountBankPanel",
    "WarbandBankFrame",
    "WarbandBankPanel",
    "WarbandBank",
  }
  for _, k in ipairs(candidates) do
    local f = _G and rawget(_G, k)
    if f and f.IsVisible and f:IsVisible() then
      return f
    end
    if f and f.IsShown and f:IsShown() then
      return f
    end
  end

  -- If the Blizzard panel exists and a valid tab is selected, treat as open.
  if GetSelectedAccountBankTabBagID() ~= nil then
    local p = _G and rawget(_G, "AccountBankPanel")
    if p then return p end
  end

  -- Some builds embed the Warband/AccountBank panel inside BankFrame.
  local bank = _G and rawget(_G, "BankFrame")
  if bank and bank.IsShown and bank:IsShown() then
    -- Common field names (best-effort).
    local direct = { bank.AccountBankPanel, bank.AccountBankFrame, bank.WarbandBankPanel, bank.WarbandBankFrame }
    for i = 1, #direct do
      local f = direct[i]
      if f and f.IsShown and f:IsShown() then
        return f
      end
    end

    local found = FindShownChildByNamePattern(bank, { "AccountBank", "WarbandBank" })
    if found then
      return found
    end
  end

  return nil
end

local function IsWarbankOpen()
  if _warbankInteractionOpen == true then
    return true
  end
  local bankType = GetSelectedBankType()
  local acctType = (Enum and Enum.BankType) and Enum.BankType.Account or nil
  if acctType ~= nil and bankType == acctType then
    return true
  end
  if GetSelectedAccountBankTabBagID() ~= nil then
    return true
  end
  return (GetWarbankFrame() ~= nil)
end

local _depositScanTip
local function ScanItemTooltipText(link, scanText)
  if type(link) ~= "string" or link == "" then return end
  if not (CreateFrame and UIParent) then return end
  if type(scanText) ~= "function" then return end

  if not _depositScanTip then
    _depositScanTip = CreateFrame("GameTooltip", "fr0z3nUI_LootIt_DepositScanTip", UIParent, "GameTooltipTemplate")
    _depositScanTip:SetOwner(UIParent, "ANCHOR_NONE")
  end

  _depositScanTip:ClearLines()
  _depositScanTip:SetHyperlink(link)
  local n = _depositScanTip:NumLines() or 0
  for i = 1, n do
    local left = _G and _G["fr0z3nUI_LootIt_DepositScanTipTextLeft" .. i]
    local right = _G and _G["fr0z3nUI_LootIt_DepositScanTipTextRight" .. i]
    if left and left.GetText then scanText(left:GetText()) end
    if right and right.GetText then scanText(right:GetText()) end
  end
end

local function GetDepositItemFlagsFromLink(link)
  local out = {
    soulbound = false,
    warbound = false,
  }

  local function scanText(s)
    if type(s) ~= "string" or s == "" then return end
    local low = s:lower()
    if low:find("soulbound", 1, true) then
      out.soulbound = true
    end
    if low:find("bind on pickup", 1, true) then
      out.soulbound = true
    end
    if low:find("warbound", 1, true) then
      out.warbound = true
    end

    if (not out.warbound) and low:find("account bound", 1, true) then
      out.warbound = true
    end
    if (not out.warbound) and low:find("bound to warband", 1, true) then
      out.warbound = true
    end
    if (not out.warbound) and low:find("warband", 1, true) and low:find("bound", 1, true) then
      out.warbound = true
    end
    if (not out.warbound) and low:find("binds", 1, true) and low:find("warband", 1, true) then
      out.warbound = true
    end
    if (not out.warbound) and low:find("bound", 1, true) and low:find("warband", 1, true) then
      out.warbound = true
    end
  end

  if C_TooltipInfo and type(C_TooltipInfo.GetHyperlink) == "function" then
    local ok, tip = pcall(C_TooltipInfo.GetHyperlink, link)
    if ok and type(tip) == "table" and type(tip.lines) == "table" then
      for _, line in ipairs(tip.lines) do
        if type(line) == "table" then
          scanText(line.leftText)
          scanText(line.rightText)
        end
      end
    end
  end

  if (not out.warbound) or (not out.soulbound) then
    ScanItemTooltipText(link, scanText)
  end

  return out
end

local function GetConfiguredGuildBankTab()
  local cfg = DepositCfgAcc()
  local want = nil
  do
    local rk = GetCurrentRealmKey()
    local tbr = (type(cfg.guildTabByRealm) == "table") and cfg.guildTabByRealm or nil
    want = (rk ~= "" and tbr and tonumber(tbr[rk])) or nil
  end
  if want == nil then
    want = tonumber(cfg.guildTab) or 0
  end
  if want and want > 0 then
    return math.floor(want)
  end
  if type(GetCurrentGuildBankTab) == "function" then
    local ok, t = pcall(GetCurrentGuildBankTab)
    t = ok and tonumber(t) or nil
    if t and t > 0 then
      return math.floor(t)
    end
  end
  return 1
end

local GuildBankTabCanDeposit

local function IsGuildTabRandomEnabled(cfg)
  cfg = cfg or DepositCfgAcc()
  local rk = GetCurrentRealmKey()
  if rk ~= "" and type(cfg.guildTabRandomByRealm) == "table" and cfg.guildTabRandomByRealm[rk] ~= nil then
    return cfg.guildTabRandomByRealm[rk] == true
  end
  return cfg.guildTabRandom == true
end

local function GetGuildBankTabCount()
  local n = (GetNumGuildBankTabs and GetNumGuildBankTabs()) or 8
  n = tonumber(n) or 8
  n = math.floor(n)
  if n < 1 then n = 1 end
  if n > 8 then n = 8 end
  return n
end

local function PickRandomGuildBankDepositTab()
  local n = GetGuildBankTabCount()
  local allowed = {}
  for t = 1, n do
    local ok = false
    if GuildBankTabCanDeposit then
      ok = GuildBankTabCanDeposit(t)
    else
      ok = true
    end
    if ok == true then
      allowed[#allowed + 1] = t
    end
  end
  if #allowed < 1 then
    return nil
  end
  local idx = math.random(1, #allowed)
  return allowed[idx]
end

local CreateItemLocationFromBagSlot

local function FindBestGuildBankSlot(tab, itemID)
  tab = tonumber(tab)
  if not tab or tab <= 0 then return nil end
  local maxSlots = _G and rawget(_G, "MAX_GUILDBANK_SLOTS_PER_TAB")
  maxSlots = tonumber(maxSlots) or 98
  if type(GetGuildBankItemLink) ~= "function" then
    return nil
  end

  local wantID = tonumber(itemID)
  local maxStack = 1
  if wantID and type(GetItemInfo) == "function" then
    local okS, s = pcall(function() return select(8, GetItemInfo(wantID)) end)
    maxStack = (okS and tonumber(s)) or 1
  end

  local firstEmpty = nil
  for slot = 1, maxSlots do
    local ok, link = pcall(GetGuildBankItemLink, tab, slot)
    link = ok and link or nil
    if link then
      if wantID and maxStack and maxStack > 1 and type(GetGuildBankItemInfo) == "function" then
        local id = tonumber(string.match(link, "item:(%d+)"))
        if id and id == wantID then
          local okI, _, count, locked = pcall(GetGuildBankItemInfo, tab, slot)
          count = okI and tonumber(count) or nil
          locked = okI and locked or nil
          if count and count > 0 and count < maxStack and locked ~= true then
            return slot
          end
        end
      end
    else
      if not firstEmpty then firstEmpty = slot end
    end
  end
  return firstEmpty
end

-- Forward declarations (avoid analyzer 'undefined global' when referenced earlier)
local GetItemMaxStack
local WithdrawFromGuildBankToBags
local WithdrawFromContainerBagsToBags
local GetPersonalBankBagIDs

-- Guild bank data must be queried per open-session.
-- Caching across close/reopen can leave tabs unqueried and make withdraw/deposit look "broken".
local _guildBankQuerySession = 0
local _guildTabQueriedSession = {}

local function ResetGuildBankQuerySession()
  _guildBankQuerySession = (_guildBankQuerySession or 0) + 1
  _guildTabQueriedSession = {}
end

local function QueryGuildBankTabIfNeeded(tab)
  tab = tonumber(tab)
  if not tab or tab <= 0 then return end
  if _guildTabQueriedSession[tab] == _guildBankQuerySession then return end
  if type(QueryGuildBankTab) ~= "function" then return end
  pcall(QueryGuildBankTab, tab)
  _guildTabQueriedSession[tab] = _guildBankQuerySession
end

local function GuildBankTabCanView(tab)
  tab = tonumber(tab)
  if not tab or tab <= 0 then
    return false, "invalid tab"
  end
  if type(GetGuildBankTabInfo) ~= "function" then
    return true
  end
  QueryGuildBankTabIfNeeded(tab)
  local ok, name, _, canView = pcall(GetGuildBankTabInfo, tab)
  if not ok then
    return false, "tab info unavailable"
  end
  if not name or canView ~= true then
    return false, "no view permission"
  end
  return true
end

GuildBankTabCanDeposit = function(tab)
  tab = tonumber(tab)
  if not tab or tab <= 0 then
    return false, "invalid tab"
  end
  if type(GetGuildBankTabInfo) ~= "function" then
    return true
  end
  QueryGuildBankTabIfNeeded(tab)
  local ok, name, _, canView, canDeposit = pcall(GetGuildBankTabInfo, tab)
  if not ok then
    return false, "tab info unavailable"
  end
  if not name or canView ~= true then
    return false, "no view permission"
  end
  if canDeposit ~= true then
    return false, "no deposit permission"
  end
  return true
end

local function SplitPickupContainerItemSafe(bag, slot, amount)
  if not (C_Container and type(C_Container.PickupContainerItem) == "function") then
    return false, "No container pickup API"
  end
  amount = tonumber(amount)
  if amount and amount > 0 then
    if C_Container and type(C_Container.SplitContainerItem) == "function" then
      local ok, err = pcall(C_Container.SplitContainerItem, bag, slot, amount)
      if ok then return true end
      return false, tostring(err)
    end
    local split = _G and rawget(_G, "SplitContainerItem")
    if type(split) == "function" then
      local ok, err = pcall(split, bag, slot, amount)
      if ok then return true end
      return false, tostring(err)
    end
  end
  local ok, err = pcall(C_Container.PickupContainerItem, bag, slot)
  if ok then return true end
  return false, tostring(err)
end

local function DepositToGuildBankOnce(bag, slot, tab, bankSlot, amount)
  if not (C_Container and type(C_Container.PickupContainerItem) == "function") then
    return false, "No container pickup API"
  end
  if type(PickupGuildBankItem) ~= "function" then
    return false, "No guild bank pickup API"
  end

  local clear = _G and rawget(_G, "ClearCursor")

  local function cursorHasItem()
    if type(GetCursorInfo) == "function" then
      local ok, kind = pcall(GetCursorInfo)
      return ok and kind == "item"
    end
    local cursorHas = _G and rawget(_G, "CursorHasItem")
    if type(cursorHas) == "function" then
      local ok, has = pcall(cursorHas)
      return ok and has == true
    end
    return false
  end

  if type(clear) == "function" then pcall(clear) end

  local okPick, errPick = SplitPickupContainerItemSafe(bag, slot, amount)
  if not okPick then
    if type(clear) == "function" then pcall(clear) end
    return false, "Pickup failed: " .. tostring(errPick)
  end
  if not cursorHasItem() then
    if type(clear) == "function" then pcall(clear) end
    return false, "Pickup did not put item on cursor"
  end

  QueryGuildBankTabIfNeeded(tab)
  local okDrop, errDrop = pcall(PickupGuildBankItem, tab, bankSlot)
  if not okDrop then
    if type(clear) == "function" then pcall(clear) end
    return false, "Place failed: " .. tostring(errDrop)
  end

  -- Cursor still holding item => place was blocked.
  if cursorHasItem() then
    if type(clear) == "function" then pcall(clear) end
    return false, "Place was blocked"
  end

  if type(clear) == "function" then pcall(clear) end
  return true
end

local function GetEffectiveKeepAmount(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return 0 end
  local cfg = DepositCfgAcc()
  local v = 0
  if cfg and type(cfg.keepByItem) == "table" then
    v = tonumber(cfg.keepByItem[itemID]) or 0
  end
  v = v and math.floor(v) or 0
  if v < 1 then return 0 end
  if v > 9999 then v = 9999 end
  return v
end

local function GetEffectiveKeepScope(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return "K" end
  local cfg = DepositCfgAcc()
  local v = (cfg and type(cfg.keepScopeByItem) == "table") and cfg.keepScopeByItem[itemID] or nil
  if v == "S" then return "S" end
  return "K"
end

local function IsStackPullEnabledForItem(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return false end
  local cfg = DepositCfgAcc()
  return (cfg and type(cfg.stackPullByItem) == "table" and cfg.stackPullByItem[itemID] == true) and true or false
end

local function CountItemInPlayerBags(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return 0 end
  if not (C_Container and type(C_Container.GetContainerNumSlots) == "function") then return 0 end
  local total = 0
  for bag = 0, 6 do
    local okN, n = pcall(C_Container.GetContainerNumSlots, bag)
    n = okN and tonumber(n) or 0
    if n and n > 0 then
      for slot = 1, n do
        local info = nil
        if type(C_Container.GetContainerItemInfo) == "function" then
          local ok, v = pcall(C_Container.GetContainerItemInfo, bag, slot)
          info = ok and v or nil
        end
        if info and tonumber(info.itemID) == itemID then
          local stack = tonumber(info.stackCount)
          total = total + (stack or 1)
        end
      end
    end
  end
  return total
end

local function CountItemInContainerBags(sourceBags, itemID)
  if type(sourceBags) ~= "table" then return 0 end
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return 0 end
  if not (C_Container and type(C_Container.GetContainerNumSlots) == "function") then return 0 end

  local total = 0
  for i = 1, #sourceBags do
    local bag = sourceBags[i]
    local okN, n = pcall(C_Container.GetContainerNumSlots, bag)
    n = okN and tonumber(n) or 0
    if n and n > 0 then
      for slot = 1, n do
        local info = nil
        if type(C_Container.GetContainerItemInfo) == "function" then
          local ok, v = pcall(C_Container.GetContainerItemInfo, bag, slot)
          info = ok and v or nil
        end
        if info and tonumber(info.itemID) == itemID then
          local stack = tonumber(info.stackCount)
          total = total + (stack or 1)
        end
      end
    end
  end
  return total
end

local function RunDepositGuild()
  if not IsGuildBankOpen() then
    return false
  end

  do
    local key, guildName, realm = GetCurrentGuildKey()
    if key and DB and DB.deposit and type(DB.deposit.guildEnabled) == "table" and DB.deposit.guildEnabled[key] == false then
      local display = guildName or "Guild"
      if type(realm) == "string" and realm ~= "" then
        display = display .. " (" .. realm .. ")"
      end
      Print("Guild deposit disabled: " .. display)
      return false
    end
  end

  local targets = GetEffectiveDepositItemIDs()
  local hasAny = false
  for _ in pairs(targets) do hasAny = true break end
  if not hasAny then
    Print("Deposit list is empty.")
    return false
  end

  local cfg = DepositCfgAcc()
  local tab = nil
  if IsGuildTabRandomEnabled(cfg) then
    tab = PickRandomGuildBankDepositTab()
  end
  if not tab then
    tab = GetConfiguredGuildBankTab()
  end
  if type(SetCurrentGuildBankTab) == "function" and tab and tab > 0 then
    pcall(SetCurrentGuildBankTab, tab)
  end
  local okPerm, whyPerm = GuildBankTabCanDeposit(tab)
  if not okPerm then
    Print("Deposit blocked (guild): " .. tostring(whyPerm or "no permission"))
    return false
  end
  QueryGuildBankTabIfNeeded(tab)

  -- Optional Stack Pull: if this guild tab already has a partial stack (count < max stack)
  -- for an SP-enabled item, withdraw that partial stack to bags first (only if bags have
  -- enough to fill it), then proceed with deposit.
  do
    local maxSlots = _G and rawget(_G, "MAX_GUILDBANK_SLOTS_PER_TAB")
    maxSlots = tonumber(maxSlots) or 98
    local touched = {}

    if type(GetGuildBankItemLink) == "function" and type(GetGuildBankItemInfo) == "function" then
      for itemID in pairs(targets) do
        itemID = tonumber(itemID)
        if itemID and itemID > 0 and IsStackPullEnabledForItem(itemID) and not touched[itemID] then
          local maxStack = GetItemMaxStack(itemID)
          if maxStack and maxStack > 1 then
            local inBags = CountItemInPlayerBags(itemID)
            if inBags and inBags > 0 then
              local partialCount = nil
              for slot = 1, maxSlots do
                local link = GetGuildBankItemLinkSafe(tab, slot)
                if type(link) == "string" then
                  local id = tonumber(string.match(link, "item:(%d+)"))
                  if id and id == itemID then
                    local okI, _, count, locked = pcall(GetGuildBankItemInfo, tab, slot)
                    count = okI and tonumber(count) or nil
                    locked = okI and locked or nil
                    if count and count > 0 and count < maxStack and locked ~= true then
                      partialCount = count
                      break
                    end
                  end
                end
              end

              if partialCount and partialCount > 0 and partialCount < maxStack then
                local needToFill = maxStack - partialCount
                if needToFill > 0 and inBags >= needToFill then
                  touched[itemID] = true
                  local movedW, whyW = WithdrawFromGuildBankToBags(tab, itemID, partialCount)
                  if whyW then
                    Print("Withdraw blocked (guild): " .. tostring(whyW))
                    return false
                  end
                  if not movedW or movedW <= 0 then
                    -- If we couldn't withdraw, just continue without the pre-pass.
                    touched[itemID] = true
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  -- Store scope (S): keep amount in this guild tab; deposit up to Keep, withdraw excess.
  local storeHave = {}
  do
    for itemID in pairs(targets) do
      itemID = tonumber(itemID)
      if itemID and itemID > 0 then
        local keep = GetEffectiveKeepAmount(itemID)
        if keep > 0 and GetEffectiveKeepScope(itemID) == "S" then
          storeHave[itemID] = CountItemInGuildBankTab(tab, itemID)
        end
      end
    end
  end

  local moved = 0
  local movedLines = {}
  local skippedSoulbound = 0
  local skippedWarbound = 0
  local maxMoves = 200

  for bag = 0, 6 do
    local n = 0
    if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
      local ok, v = pcall(C_Container.GetContainerNumSlots, bag)
      n = ok and tonumber(v) or 0
    end
    if n and n > 0 then
      for slot = 1, n do
        if moved >= maxMoves then break end

        local info = nil
        if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
          local ok, v = pcall(C_Container.GetContainerItemInfo, bag, slot)
          info = ok and v or nil
        end
        local itemID = info and tonumber(info.itemID) or nil
        if itemID and targets[itemID] == true then
          local stack = (info and tonumber(info.stackCount)) or 1
          local depositCount = stack
          local keep = GetEffectiveKeepAmount(itemID)
          if keep > 0 then
            local scope = GetEffectiveKeepScope(itemID)
            if scope == "S" then
              local have = tonumber(storeHave[itemID]) or 0
              local need = keep - have
              if need <= 0 then
                depositCount = 0
              elseif need < depositCount then
                depositCount = need
              end
            else
              local current = CountItemInPlayerBags(itemID)
              local excess = (current or 0) - keep
              if excess <= 0 then
                depositCount = 0
              elseif excess < depositCount then
                depositCount = excess
              end
            end
          end

          if depositCount and depositCount > 0 then
            local link = nil
            if C_Container and type(C_Container.GetContainerItemLink) == "function" then
              local okL, vL = pcall(C_Container.GetContainerItemLink, bag, slot)
              link = okL and vL or nil
            end

            local flags = GetDepositItemFlagsFromLink(link or ("item:" .. tostring(itemID)))
            local isBound = false
            do
              local loc = CreateItemLocationFromBagSlot(bag, slot)
              if loc and C_Item and type(C_Item.IsBound) == "function" then
                local okB, vB = pcall(C_Item.IsBound, loc)
                isBound = okB and vB == true
              end
            end
            if flags.soulbound or isBound then
              skippedSoulbound = skippedSoulbound + 1
              Print("Skipped (soulbound, can't deposit to guild bank): " .. tostring(link or itemID))
            elseif flags.warbound then
              skippedWarbound = skippedWarbound + 1
            else
              local bankSlot = FindBestGuildBankSlot(tab, itemID)
              if not bankSlot then
                Print("Guild bank tab is full.")
                return moved > 0
              end
              local okMove, why = DepositToGuildBankOnce(bag, slot, tab, bankSlot, depositCount ~= stack and depositCount or nil)
              if okMove then
                moved = moved + 1
                if keep > 0 and GetEffectiveKeepScope(itemID) == "S" then
                  storeHave[itemID] = (tonumber(storeHave[itemID]) or 0) + (tonumber(depositCount) or 0)
                end
                if moved <= 15 then
                  movedLines[#movedLines + 1] = tostring(link or itemID) .. " x" .. tostring(depositCount)
                end
              else
                Print("Deposit blocked (guild): " .. tostring(why or "unknown"))
                return moved > 0
              end
            end
          end
        end
      end
    end
    if moved >= maxMoves then break end
  end

  local storeMoved = 0
  do
    for itemID in pairs(targets) do
      itemID = tonumber(itemID)
      if itemID and itemID > 0 then
        local keep = GetEffectiveKeepAmount(itemID)
        if keep > 0 and GetEffectiveKeepScope(itemID) == "S" then
          local have = tonumber(storeHave[itemID])
          if have == nil then
            have = CountItemInGuildBankTab(tab, itemID)
          end
          local excess = (have or 0) - keep
          if excess > 0 then
            local did, why = WithdrawFromGuildBankToBags(tab, itemID, excess)
            if why then
              if tostring(why) == "No bag space" then
                Print("Store withdraw blocked (guild): bags are full (free bag space and retry deposit)")
              else
                Print("Store withdraw blocked (guild): " .. tostring(why))
              end
              return moved > 0
            end
            did = tonumber(did) or 0
            if did > 0 then
              storeMoved = storeMoved + did
              storeHave[itemID] = (have or 0) - did
            end
          end
        end
      end
    end
  end

  if moved > 0 then
    Print("Deposited: " .. tostring(moved) .. " move(s)")
    for i = 1, #movedLines do
      Print("  " .. movedLines[i])
    end
    if moved > #movedLines then
      Print("  (and " .. tostring(moved - #movedLines) .. " more)")
    end
    if skippedSoulbound > 0 then
      Print("Skipped soulbound: " .. tostring(skippedSoulbound))
    end
    if storeMoved > 0 then
      Print("Withdrew (store): " .. tostring(storeMoved) .. " item(s)")
    end
    return true
  end
  if storeMoved > 0 then
    Print("Withdrew (store): " .. tostring(storeMoved) .. " item(s)")
    return true
  end
  -- Nothing left to deposit; run a cleanup pass like BankStack /sort guild.
  RunDepositCleanupOncePerReset("guild", TryAutoSortGuildBank, "account", "daily")
  return false
end

local function DepositToPersonalBankOnce(bag, slot, amount)
  if not (C_Container and type(C_Container.PickupContainerItem) == "function") then
    return false
  end

  local putInBank = _G and rawget(_G, "PutItemInBank")
  if type(putInBank) ~= "function" then
    return false
  end

  local clear = _G and rawget(_G, "ClearCursor")
  local cursorHas = _G and rawget(_G, "CursorHasItem")

  if type(clear) == "function" then pcall(clear) end

  local okPick = SplitPickupContainerItemSafe(bag, slot, amount)
  if not okPick then
    if type(clear) == "function" then pcall(clear) end
    return false
  end

  if type(cursorHas) == "function" then
    local okCur, has = pcall(cursorHas)
    if okCur and not has then
      if type(clear) == "function" then pcall(clear) end
      return false
    end
  end

  pcall(putInBank)

  if type(cursorHas) == "function" then
    local okCur2, has2 = pcall(cursorHas)
    if okCur2 and has2 then
      if type(clear) == "function" then pcall(clear) end
      return false
    end
  end

  if type(clear) == "function" then pcall(clear) end
  return true
end

local function RunDepositPersonalBank()
  if not IsPersonalBankOpen() then
    return false
  end

  local targets = GetEffectiveDepositItemIDs()
  local hasAny = false
  for _ in pairs(targets) do hasAny = true break end
  if not hasAny then
    Print("Deposit list is empty.")
    return false
  end

  local bankBags = GetPersonalBankBagIDs and GetPersonalBankBagIDs() or nil

  local moved = 0
  local movedLines = {}
  local maxMoves = 200

  -- Optional Stack Pull: withdraw a partial stack from the bank first (per item), but only
  -- when the player has enough in bags to fill it.
  do
    local touched = {}
    if type(bankBags) == "table" and #bankBags > 0 and C_Container and type(C_Container.GetContainerNumSlots) == "function" then
      for itemID in pairs(targets) do
        itemID = tonumber(itemID)
        if itemID and itemID > 0 and IsStackPullEnabledForItem(itemID) and not touched[itemID] then
          local maxStack = GetItemMaxStack(itemID)
          if maxStack and maxStack > 1 then
            local inBags = CountItemInPlayerBags(itemID)
            if inBags and inBags > 0 then
              local partialCount = nil
              for i = 1, #bankBags do
                local b = bankBags[i]
                local okN, n = pcall(C_Container.GetContainerNumSlots, b)
                n = okN and tonumber(n) or 0
                if n and n > 0 then
                  for s = 1, n do
                    local info = nil
                    if type(C_Container.GetContainerItemInfo) == "function" then
                      local ok, v = pcall(C_Container.GetContainerItemInfo, b, s)
                      info = ok and v or nil
                    end
                    if info and tonumber(info.itemID) == itemID then
                      local count = tonumber(info.stackCount)
                      local locked = info.isLocked
                      if count and count > 0 and count < maxStack and locked ~= true then
                        partialCount = count
                        break
                      end
                    end
                  end
                end
                if partialCount then break end
              end

              if partialCount and partialCount > 0 and partialCount < maxStack then
                local needToFill = maxStack - partialCount
                if needToFill > 0 and inBags >= needToFill then
                  touched[itemID] = true
                  WithdrawFromContainerBagsToBags(bankBags, itemID, partialCount)
                end
              end
            end
          end
        end
      end
    end
  end

  -- Store scope (S): keep amount in bank; deposit up to Keep, withdraw excess.
  local storeHave = {}
  do
    if type(bankBags) == "table" and #bankBags > 0 then
      for itemID in pairs(targets) do
        itemID = tonumber(itemID)
        if itemID and itemID > 0 then
          local keep = GetEffectiveKeepAmount(itemID)
          if keep > 0 and GetEffectiveKeepScope(itemID) == "S" then
            storeHave[itemID] = CountItemInContainerBags(bankBags, itemID)
          end
        end
      end
    end
  end

  for bag = 0, 6 do
    local n = 0
    if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
      local ok, v = pcall(C_Container.GetContainerNumSlots, bag)
      n = ok and tonumber(v) or 0
    end
    if n and n > 0 then
      for slot = 1, n do
        if moved >= maxMoves then break end

        local info = nil
        if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
          local ok, v = pcall(C_Container.GetContainerItemInfo, bag, slot)
          info = ok and v or nil
        end
        local itemID = info and tonumber(info.itemID) or nil
        if itemID and targets[itemID] == true then
          local stack = (info and tonumber(info.stackCount)) or 1
          local depositCount = stack
          local keep = GetEffectiveKeepAmount(itemID)
          if keep > 0 then
            local scope = GetEffectiveKeepScope(itemID)
            if scope == "S" then
              local have = tonumber(storeHave[itemID]) or 0
              local need = keep - have
              if need <= 0 then
                depositCount = 0
              elseif need < depositCount then
                depositCount = need
              end
            else
              local current = CountItemInPlayerBags(itemID)
              local excess = (current or 0) - keep
              if excess <= 0 then
                depositCount = 0
              elseif excess < depositCount then
                depositCount = excess
              end
            end
          end

          if depositCount and depositCount > 0 then
            local link = nil
            if C_Container and type(C_Container.GetContainerItemLink) == "function" then
              local okL, vL = pcall(C_Container.GetContainerItemLink, bag, slot)
              link = okL and vL or nil
            end

            local okMove = DepositToPersonalBankOnce(bag, slot, depositCount ~= stack and depositCount or nil)
            if okMove then
              moved = moved + 1
              if keep > 0 and GetEffectiveKeepScope(itemID) == "S" then
                storeHave[itemID] = (tonumber(storeHave[itemID]) or 0) + (tonumber(depositCount) or 0)
              end
              if moved <= 15 then
                movedLines[#movedLines + 1] = tostring(link or itemID) .. " x" .. tostring(depositCount)
              end
            else
              Print("Deposit blocked (personal bank)")
              return moved > 0
            end
          end
        end
      end
    end
    if moved >= maxMoves then break end
  end

  local storeMoved = 0
  do
    if type(bankBags) == "table" and #bankBags > 0 then
      for itemID in pairs(targets) do
        itemID = tonumber(itemID)
        if itemID and itemID > 0 then
          local keep = GetEffectiveKeepAmount(itemID)
          if keep > 0 and GetEffectiveKeepScope(itemID) == "S" then
            local have = tonumber(storeHave[itemID])
            if have == nil then
              have = CountItemInContainerBags(bankBags, itemID)
            end
            local excess = (have or 0) - keep
            if excess > 0 then
              local did, why = WithdrawFromContainerBagsToBags(bankBags, itemID, excess)
              if why then
                if tostring(why) == "No bag space" then
                  Print("Store withdraw blocked (bank): bags are full (free bag space and retry deposit)")
                else
                  Print("Store withdraw blocked (bank): " .. tostring(why))
                end
                return moved > 0
              end
              did = tonumber(did) or 0
              if did > 0 then
                storeMoved = storeMoved + did
                storeHave[itemID] = (have or 0) - did
              end
            end
          end
        end
      end
    end
  end

  if moved > 0 then
    Print("Deposited: " .. tostring(moved) .. " move(s)")
    for i = 1, #movedLines do
      Print("  " .. movedLines[i])
    end
    if moved > #movedLines then
      Print("  (and " .. tostring(moved - #movedLines) .. " more)")
    end
    if storeMoved > 0 then
      Print("Withdrew (store): " .. tostring(storeMoved) .. " item(s)")
    end
    return true
  end
  if storeMoved > 0 then
    Print("Withdrew (store): " .. tostring(storeMoved) .. " item(s)")
    return true
  end
  -- Nothing left to deposit; run a cleanup pass like BankStack /sort bank.
  RunDepositCleanupOncePerReset("bank", TryAutoSortBankPanel, "char", "daily")
  return false
end

local function WarbandDepositCapability()
  -- Retail always has Warband Bank; we keep a best-effort callable detector for the eventual mover.
  local candidates = {
    { tbl = _G and rawget(_G, "C_AccountBank"), fn = "DepositItem" },
    { tbl = _G and rawget(_G, "C_Bank"), fn = "DepositItem" },
    { tbl = _G and rawget(_G, "C_Bank"), fn = "DepositToAccountBank" },
  }
  for _, c in ipairs(candidates) do
    if type(c.tbl) == "table" and type(c.tbl[c.fn]) == "function" then
      return true, c.tbl, c.fn
    end
  end
  -- Treat as supported even if we didn't find a callable (API naming can change).
  return true, nil, nil
end

local function GetWarbankDepositCallable()
  local cap, tbl, fn = WarbandDepositCapability()
  if not cap then return nil, nil, nil end
  if type(tbl) == "table" and type(fn) == "string" and type(tbl[fn]) == "function" then
    return tbl[fn], fn
  end
  return nil, nil
end

CreateItemLocationFromBagSlot = function(bag, slot)
  if not (bag and slot) then return nil end
  local il = _G and rawget(_G, "ItemLocation")
  if type(il) == "table" then
    if type(il.CreateFromBagAndSlot) == "function" then
      local ok, loc = pcall(il.CreateFromBagAndSlot, bag, slot)
      if ok then return loc end
    end
    -- Some mixin-style APIs expect self as the first arg.
    if type(il.CreateFromBagAndSlot) == "function" then
      local ok, loc = pcall(il.CreateFromBagAndSlot, il, bag, slot)
      if ok then return loc end
    end
  end
  return nil
end

local function DepositToWarbankOnce(bag, slot, sourceItemID, amount)
  local function TryDepositViaCursor()
    if not (C_Container and type(C_Container.PickupContainerItem) == "function") then
      return false, "No container pickup API"
    end

    local wantID = tonumber(sourceItemID)
    if not wantID and type(C_Container.GetContainerItemID) == "function" then
      local ok, v = pcall(C_Container.GetContainerItemID, bag, slot)
      wantID = ok and tonumber(v) or nil
    end

    local maxStack = 1
    if wantID and type(GetItemInfo) == "function" then
      local okS, s = pcall(function() return select(8, GetItemInfo(wantID)) end)
      maxStack = (okS and tonumber(s)) or 1
    end

    local selectedTab = GetSelectedAccountBankTabBagID()
    local targetBags = {}
    if selectedTab then
      targetBags[1] = selectedTab
    elseif Enum and Enum.BagIndex then
      local e = Enum.BagIndex
      local all = { e.AccountBankTab_1, e.AccountBankTab_2, e.AccountBankTab_3, e.AccountBankTab_4, e.AccountBankTab_5 }
      for i = 1, #all do
        if IsAccountBankBagID(all[i]) then
          targetBags[#targetBags + 1] = all[i]
        end
      end
    end

    if #targetBags == 0 then
      return false, "No AccountBank tab is available/selected"
    end

    -- Optional pre-check: is the item allowed in Account bank.
    local loc = CreateItemLocationFromBagSlot(bag, slot)
    local bankTypeAccount = (Enum and Enum.BankType) and Enum.BankType.Account or nil
    if bankTypeAccount ~= nil and loc ~= nil
      and C_Bank and type(C_Bank.IsItemAllowedInBankType) == "function" and type(C_Bank.CanViewBank) == "function"
    then
      local okView, canView = pcall(C_Bank.CanViewBank, bankTypeAccount)
      if okView and canView == true then
        local okAllow, allowed = pcall(C_Bank.IsItemAllowedInBankType, bankTypeAccount, loc)
        if okAllow and allowed == false then
          return false, "Not allowed in Warbank"
        end
      end
    end

    local function findBestSlot(tBag)
      local n = 0
      if type(C_Container.GetContainerNumSlots) == "function" then
        local ok, v = pcall(C_Container.GetContainerNumSlots, tBag)
        n = ok and tonumber(v) or 0
      end
      if not (n and n > 0) then return nil end

      local firstEmpty
      for tSlot = 1, n do
        local info = nil
        if type(C_Container.GetContainerItemInfo) == "function" then
          local ok, v = pcall(C_Container.GetContainerItemInfo, tBag, tSlot)
          info = ok and v or nil
        end
        if info and wantID and maxStack and maxStack > 1 then
          local id = tonumber(info.itemID)
          local count = tonumber(info.stackCount)
          local locked = info.isLocked
          if id and id == wantID and count and count > 0 and count < maxStack and locked ~= true then
            return tSlot
          end
        end
        if info == nil and not firstEmpty then
          firstEmpty = tSlot
        end
      end

      return firstEmpty
    end

    local targetBag, targetSlot
    for i = 1, #targetBags do
      local tBag = targetBags[i]
      local tSlot = findBestSlot(tBag)
      if tSlot then
        targetBag, targetSlot = tBag, tSlot
        break
      end
    end
    if not (targetBag and targetSlot) then
      return false, "Warbank tab full"
    end

    if GetCursorInfo and GetCursorInfo() == "item" and ClearCursor then
      ClearCursor()
    end

    local okPick, errPick = SplitPickupContainerItemSafe(bag, slot, amount)
    if not okPick then
      return false, "Pickup failed: " .. tostring(errPick)
    end
    if GetCursorInfo and GetCursorInfo() ~= "item" then
      return false, "Pickup did not put item on cursor"
    end

    local okPlace, errPlace = pcall(C_Container.PickupContainerItem, targetBag, targetSlot)
    if not okPlace then
      if ClearCursor then ClearCursor() end
      return false, "Place failed: " .. tostring(errPlace)
    end
    if GetCursorInfo and GetCursorInfo() == "item" then
      if ClearCursor then ClearCursor() end
      return false, "Place was blocked"
    end

    return true
  end

  -- Prefer the same approach as BankStack: move to AccountBankTab containers.
  local okCursor, whyCursor = TryDepositViaCursor()
  if okCursor then
    return true
  end

  if amount and tonumber(amount) and tonumber(amount) > 0 then
    -- For partial-stack deposits we must not fall back to any opaque API
    -- that would deposit the full remaining stack from the original slot.
    if ClearCursor then pcall(ClearCursor) end
    return false, tostring(whyCursor or "Partial deposit failed")
  end

  -- Fallback: try any detected Warbank deposit API.
  local f, fnName = GetWarbankDepositCallable()
  if type(f) ~= "function" then
    return false, tostring(whyCursor or "No Warbank deposit API")
  end

  -- Try common signatures (API differs by build).
  local loc = CreateItemLocationFromBagSlot(bag, slot)
  local bankTypeAccount = (Enum and Enum.BankType) and Enum.BankType.Account or nil

  local lastErr
  local function tryCall(...)
    local ok, resOrErr = pcall(f, ...)
    if ok then
      if resOrErr == false then
        lastErr = "returned false"
        return false
      end
      return true
    end
    lastErr = tostring(resOrErr)
    return false
  end

  -- Signature zoo: different builds use different function names/args.
  -- We try the safest/most common permutations first.
  if loc ~= nil then
    if tryCall(loc) then return true end
  end
  if tryCall(bag, slot) then return true end

  if bankTypeAccount ~= nil then
    if loc ~= nil and tryCall(bankTypeAccount, loc) then return true end
    if tryCall(bankTypeAccount, bag, slot) then return true end
    if loc ~= nil and tryCall(loc, bankTypeAccount) then return true end
    if tryCall(bag, slot, bankTypeAccount) then return true end
  end

  return false, tostring(fnName or "deposit") .. ": " .. tostring(lastErr or "failed")
end

GetItemMaxStack = function(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return 1 end
  if type(GetItemInfo) ~= "function" then return 1 end
  local okS, s = pcall(function() return select(8, GetItemInfo(itemID)) end)
  local maxStack = (okS and tonumber(s)) or 1
  if not maxStack or maxStack < 1 then maxStack = 1 end
  return math.floor(maxStack)
end

local function WithdrawWarbankPartialStacksToBags(itemID, maxStack)
  itemID = tonumber(itemID)
  maxStack = tonumber(maxStack)
  if not itemID or itemID <= 0 then return true end
  if not maxStack or maxStack <= 1 then return true end
  if not (C_Container and type(C_Container.PickupContainerItem) == "function") then
    return false, "No container pickup API"
  end

  local function cursorHasItem()
    if GetCursorInfo then
      local ok, kind = pcall(GetCursorInfo)
      return ok and kind == "item"
    end
    local cursorHas = _G and rawget(_G, "CursorHasItem")
    if type(cursorHas) == "function" then
      local ok, has = pcall(cursorHas)
      return ok and has == true
    end
    return false
  end

  local function clearCursor()
    if ClearCursor and type(ClearCursor) == "function" then
      pcall(ClearCursor)
    end
  end

  local function findBestBagSlot()
    local bestBag, bestSlot
    local firstEmptyBag, firstEmptySlot
    for bag = 0, 6 do
      local n = 0
      if type(C_Container.GetContainerNumSlots) == "function" then
        local ok, v = pcall(C_Container.GetContainerNumSlots, bag)
        n = ok and tonumber(v) or 0
      end
      if n and n > 0 then
        for slot = 1, n do
          local info = nil
          if type(C_Container.GetContainerItemInfo) == "function" then
            local ok, v = pcall(C_Container.GetContainerItemInfo, bag, slot)
            info = ok and v or nil
          end
          if info and tonumber(info.itemID) == itemID then
            local count = tonumber(info.stackCount)
            local locked = info.isLocked
            if count and count > 0 and count < maxStack and locked ~= true then
              return bag, slot
            end
          end
          if info == nil and not firstEmptyBag then
            firstEmptyBag, firstEmptySlot = bag, slot
          end
        end
      end
    end
    return firstEmptyBag, firstEmptySlot
  end

  local selectedTab = GetSelectedAccountBankTabBagID()
  local warBags = {}
  if selectedTab then
    warBags[1] = selectedTab
  elseif Enum and Enum.BagIndex then
    local e = Enum.BagIndex
    warBags = { e.AccountBankTab_1, e.AccountBankTab_2, e.AccountBankTab_3, e.AccountBankTab_4, e.AccountBankTab_5 }
  end

  local moved = 0
  local maxMoves = 80
  for i = 1, #warBags do
    local wBag = warBags[i]
    if IsAccountBankBagID(wBag) then
      local n = 0
      if type(C_Container.GetContainerNumSlots) == "function" then
        local ok, v = pcall(C_Container.GetContainerNumSlots, wBag)
        n = ok and tonumber(v) or 0
      end
      if n and n > 0 then
        for wSlot = 1, n do
          if moved >= maxMoves then
            return true
          end

          local info = nil
          if type(C_Container.GetContainerItemInfo) == "function" then
            local ok, v = pcall(C_Container.GetContainerItemInfo, wBag, wSlot)
            info = ok and v or nil
          end
          if info and tonumber(info.itemID) == itemID then
            local count = tonumber(info.stackCount)
            local locked = info.isLocked
            if count and count > 0 and count < maxStack and locked ~= true then
              local tBag, tSlot = findBestBagSlot()
              if not (tBag and tSlot) then
                clearCursor()
                return false, "No bag space to withdraw partial Warbank stack"
              end

              if cursorHasItem() then clearCursor() end

              local okPick, errPick = pcall(C_Container.PickupContainerItem, wBag, wSlot)
              if not okPick then
                clearCursor()
                return false, "Withdraw pickup failed: " .. tostring(errPick)
              end
              if not cursorHasItem() then
                clearCursor()
                return false, "Withdraw pickup did not put item on cursor"
              end

              local okPlace, errPlace = pcall(C_Container.PickupContainerItem, tBag, tSlot)
              if not okPlace then
                clearCursor()
                return false, "Withdraw place failed: " .. tostring(errPlace)
              end
              if cursorHasItem() then
                clearCursor()
                return false, "Withdraw place was blocked"
              end
              moved = moved + 1
            end
          end
        end
      end
    end
  end

  return true
end

local function RunDepositWarband()
  if not IsWarbankOpen() then
    return false
  end

  local targets = GetEffectiveDepositItemIDs()
  local hasAny = false
  for _ in pairs(targets) do hasAny = true break end
  if not hasAny then
    Print("Deposit list is empty.")
    return false
  end

  local warbankBags = {}
  do
    local selectedTab = GetSelectedAccountBankTabBagID()
    local all = {}
    if selectedTab then
      all[1] = selectedTab
    elseif Enum and Enum.BagIndex then
      local e = Enum.BagIndex
      all = { e.AccountBankTab_1, e.AccountBankTab_2, e.AccountBankTab_3, e.AccountBankTab_4, e.AccountBankTab_5 }
    end
    for i = 1, #all do
      local b = all[i]
      if IsAccountBankBagID(b) then
        warbankBags[#warbankBags + 1] = b
      end
    end
  end

  -- Optional workaround (Stack Pull): For stackable items, if Warbank already has
  -- a partial stack (count < max stack), withdraw that partial stack to bags first, then deposit.
  do
    local function FindAnyPartialWarbankStackCount(itemID, maxStack)
      itemID = tonumber(itemID)
      maxStack = tonumber(maxStack) or 1
      if not itemID or itemID <= 0 then return nil end
      if not maxStack or maxStack < 2 then return nil end

      local warBags = {}
      if Enum and Enum.BagIndex then
        local e = Enum.BagIndex
        warBags = { e.AccountBankTab_1, e.AccountBankTab_2, e.AccountBankTab_3, e.AccountBankTab_4, e.AccountBankTab_5 }
      end

      for i = 1, #warBags do
        local wBag = warBags[i]
        if IsAccountBankBagID(wBag) then
          local n = 0
          if type(C_Container.GetContainerNumSlots) == "function" then
            local ok, v = pcall(C_Container.GetContainerNumSlots, wBag)
            n = ok and tonumber(v) or 0
          end
          if n and n > 0 then
            for wSlot = 1, n do
              local info = nil
              if type(C_Container.GetContainerItemInfo) == "function" then
                local ok, v = pcall(C_Container.GetContainerItemInfo, wBag, wSlot)
                info = ok and v or nil
              end
              if info and tonumber(info.itemID) == itemID then
                local count = tonumber(info.stackCount)
                local locked = info.isLocked
                if count and count > 0 and count < maxStack and locked ~= true then
                  return count
                end
              end
            end
          end
        end
      end

      return nil
    end

    local touched = {}
    for itemID in pairs(targets) do
      itemID = tonumber(itemID)
      if itemID and itemID > 0 and IsStackPullEnabledForItem(itemID) and not touched[itemID] then
        local maxStack = GetItemMaxStack(itemID)
        if maxStack and maxStack > 1 then
          -- Prevent oscillation: only apply the workaround when we can actually
          -- fill a partial stack using items currently in bags.
          local inBags = CountItemInPlayerBags(itemID)
          if inBags and inBags > 0 then
            local partialCount = FindAnyPartialWarbankStackCount(itemID, maxStack)
            if partialCount and partialCount > 0 and partialCount < maxStack then
              local needToFill = maxStack - partialCount
              if needToFill > 0 and inBags >= needToFill then
                touched[itemID] = true
                local okW, whyW = WithdrawWarbankPartialStacksToBags(itemID, maxStack)
                if not okW then
                  Print("Withdraw blocked (warbank): " .. tostring(whyW or "unknown"))
                  return false
                end
              end
            end
          end
        end
      end
    end
  end

  local moved = 0
  local movedLines = {}
  local maxMoves = 200

  -- Store scope (S): keep amount in warbank; deposit up to Keep, withdraw excess.
  local storeHave = {}
  do
    if type(warbankBags) == "table" and #warbankBags > 0 then
      for itemID in pairs(targets) do
        itemID = tonumber(itemID)
        if itemID and itemID > 0 then
          local keep = GetEffectiveKeepAmount(itemID)
          if keep > 0 and GetEffectiveKeepScope(itemID) == "S" then
            storeHave[itemID] = CountItemInContainerBags(warbankBags, itemID)
          end
        end
      end
    end
  end
  for bag = 0, 6 do
    local n = 0
    if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
      local ok, v = pcall(C_Container.GetContainerNumSlots, bag)
      n = ok and tonumber(v) or 0
    end
    if n and n > 0 then
      for slot = 1, n do
        if moved >= maxMoves then break end

        local info = nil
        if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
          local ok, v = pcall(C_Container.GetContainerItemInfo, bag, slot)
          info = ok and v or nil
        end
        local itemID = info and tonumber(info.itemID) or nil
        if itemID and targets[itemID] == true then
          local stack = (info and tonumber(info.stackCount)) or 1
          local depositCount = stack
          local keep = GetEffectiveKeepAmount(itemID)
          if keep > 0 then
            local scope = GetEffectiveKeepScope(itemID)
            if scope == "S" then
              local have = tonumber(storeHave[itemID]) or 0
              local need = keep - have
              if need <= 0 then
                depositCount = 0
              elseif need < depositCount then
                depositCount = need
              end
            else
              local current = CountItemInPlayerBags(itemID)
              local excess = (current or 0) - keep
              if excess <= 0 then
                depositCount = 0
              elseif excess < depositCount then
                depositCount = excess
              end
            end
          end

          if depositCount and depositCount > 0 then
            local link = nil
            if C_Container and type(C_Container.GetContainerItemLink) == "function" then
              local okL, vL = pcall(C_Container.GetContainerItemLink, bag, slot)
              link = okL and vL or nil
            end

            local okMove, why = DepositToWarbankOnce(bag, slot, itemID, depositCount ~= stack and depositCount or nil)
            if okMove then
              moved = moved + 1
              if keep > 0 and GetEffectiveKeepScope(itemID) == "S" then
                storeHave[itemID] = (tonumber(storeHave[itemID]) or 0) + (tonumber(depositCount) or 0)
              end
              if moved <= 15 then
                movedLines[#movedLines + 1] = tostring(link or itemID) .. " x" .. tostring(depositCount)
              end
            else
              Print("Deposit blocked (warbank): " .. tostring(why or "unknown"))
              return moved > 0
            end
          end
        end
      end
    end
    if moved >= maxMoves then break end
  end

  local storeMoved = 0
  do
    if type(warbankBags) == "table" and #warbankBags > 0 then
      for itemID in pairs(targets) do
        itemID = tonumber(itemID)
        if itemID and itemID > 0 then
          local keep = GetEffectiveKeepAmount(itemID)
          if keep > 0 and GetEffectiveKeepScope(itemID) == "S" then
            local have = tonumber(storeHave[itemID])
            if have == nil then
              have = CountItemInContainerBags(warbankBags, itemID)
            end
            local excess = (have or 0) - keep
            if excess > 0 then
              local did, why = WithdrawFromContainerBagsToBags(warbankBags, itemID, excess)
              if why then
                if tostring(why) == "No bag space" then
                  Print("Store withdraw blocked (warbank): bags are full (free bag space and retry deposit)")
                else
                  Print("Store withdraw blocked (warbank): " .. tostring(why))
                end
                return moved > 0
              end
              did = tonumber(did) or 0
              if did > 0 then
                storeMoved = storeMoved + did
                storeHave[itemID] = (have or 0) - did
              end
            end
          end
        end
      end
    end
  end

  if moved > 0 then
    Print("Deposited: " .. tostring(moved) .. " move(s)")
    for i = 1, #movedLines do
      Print("  " .. movedLines[i])
    end
    if moved > #movedLines then
      Print("  (and " .. tostring(moved - #movedLines) .. " more)")
    end
    if storeMoved > 0 then
      Print("Withdrew (store): " .. tostring(storeMoved) .. " item(s)")
    end
    return true
  end
  if storeMoved > 0 then
    Print("Withdrew (store): " .. tostring(storeMoved) .. " item(s)")
    return true
  end
  -- Nothing left to deposit; run a cleanup pass like BankStack /sort account.
  RunDepositCleanupOncePerReset("warbank", TryAutoSortBankPanel, "account", "daily")
  return false
end

-- Keep amount (Deposit mode): if bags have less than Keep and the selected/open
-- bank has stock, withdraw up to the amount needed.

local function CursorHasItemSafe()
  if type(GetCursorInfo) == "function" then
    local ok, kind = pcall(GetCursorInfo)
    return ok and kind == "item"
  end
  local cursorHas = _G and rawget(_G, "CursorHasItem")
  if type(cursorHas) == "function" then
    local ok, has = pcall(cursorHas)
    return ok and has == true
  end
  return false
end

local function ClearCursorSafe()
  if ClearCursor and type(ClearCursor) == "function" then
    pcall(ClearCursor)
  end
end

local function FindBestBagSlotForItem(itemID, maxStack)
  itemID = tonumber(itemID)
  maxStack = tonumber(maxStack) or 1
  if not itemID or itemID <= 0 then return nil end
  if not maxStack or maxStack < 1 then maxStack = 1 end

  local firstEmptyBag, firstEmptySlot
  for bag = 0, 6 do
    local n = 0
    if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
      local ok, v = pcall(C_Container.GetContainerNumSlots, bag)
      n = ok and tonumber(v) or 0
    end
    if n and n > 0 then
      for slot = 1, n do
        local info = nil
        if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
          local ok, v = pcall(C_Container.GetContainerItemInfo, bag, slot)
          info = ok and v or nil
        end

        if info and tonumber(info.itemID) == itemID then
          local count = tonumber(info.stackCount)
          local locked = info.isLocked
          if count and count > 0 and count < maxStack and locked ~= true then
            return bag, slot
          end
        end

        if info == nil and not firstEmptyBag then
          firstEmptyBag, firstEmptySlot = bag, slot
        end
      end
    end
  end
  return firstEmptyBag, firstEmptySlot
end

WithdrawFromContainerBagsToBags = function(sourceBags, itemID, wantCount)
  if not (C_Container and type(C_Container.GetContainerNumSlots) == "function") then
    return 0, "No container API"
  end
  itemID = tonumber(itemID)
  wantCount = tonumber(wantCount)
  if not itemID or itemID <= 0 then return 0 end
  wantCount = wantCount and math.floor(wantCount) or 0
  if wantCount <= 0 then return 0 end

  local maxStack = GetItemMaxStack(itemID)
  local moved = 0

  for i = 1, #sourceBags do
    local sBag = sourceBags[i]
    local n = 0
    local okN, vN = pcall(C_Container.GetContainerNumSlots, sBag)
    n = okN and tonumber(vN) or 0
    if n and n > 0 then
      for sSlot = 1, n do
        if moved >= wantCount then
          return moved
        end

        local info = nil
        if type(C_Container.GetContainerItemInfo) == "function" then
          local ok, v = pcall(C_Container.GetContainerItemInfo, sBag, sSlot)
          info = ok and v or nil
        end
        local id = info and tonumber(info.itemID) or nil
        if id and id == itemID then
          local count = (info and tonumber(info.stackCount)) or 1
          local locked = info and info.isLocked or nil
          if locked ~= true and count > 0 then
            local need = wantCount - moved
            local take = (need < count) and need or count
            if take > 0 then
              local tBag, tSlot = FindBestBagSlotForItem(itemID, maxStack)
              if not (tBag and tSlot) then
                ClearCursorSafe()
                return moved, "No bag space"
              end

              if CursorHasItemSafe() then ClearCursorSafe() end

              local okPick, errPick = SplitPickupContainerItemSafe(sBag, sSlot, (take < count) and take or nil)
              if not okPick then
                ClearCursorSafe()
                return moved, "Withdraw pickup failed: " .. tostring(errPick)
              end
              if not CursorHasItemSafe() then
                ClearCursorSafe()
                return moved, "Withdraw pickup did not put item on cursor"
              end

              local okPlace, errPlace = pcall(C_Container.PickupContainerItem, tBag, tSlot)
              if not okPlace then
                ClearCursorSafe()
                return moved, "Withdraw place failed: " .. tostring(errPlace)
              end
              if CursorHasItemSafe() then
                ClearCursorSafe()
                return moved, "Withdraw place was blocked"
              end

              moved = moved + take
            end
          end
        end
      end
    end
  end

  return moved
end

GetPersonalBankBagIDs = function()
  local out = {}
  local seen = {}
  local function add(id)
    id = tonumber(id)
    if not id then return end
    if seen[id] then return end
    seen[id] = true
    out[#out + 1] = id
  end

  -- Newer client constants (access via rawget to keep analyzers happy).
  local e = (Enum and Enum.BagIndex) and Enum.BagIndex or nil
  if type(e) == "table" then
    add(rawget(e, "Bank"))
    add(rawget(e, "ReagentBank"))
    for i = 1, 7 do
      add(rawget(e, "BankBag_" .. tostring(i)))
    end
  end

  local bankContainer = _G and rawget(_G, "BANK_CONTAINER")
  if bankContainer ~= nil then
    add(bankContainer)
  else
    add(-1)
  end

  -- Legacy-ish bank bag ids (best-effort)
  for id = 5, 11 do
    add(id)
  end

  -- Filter to those that actually have slots.
  if not (C_Container and type(C_Container.GetContainerNumSlots) == "function") then
    return out
  end
  local filtered = {}
  for i = 1, #out do
    local bagID = out[i]
    local ok, n = pcall(C_Container.GetContainerNumSlots, bagID)
    n = ok and tonumber(n) or 0
    if n and n > 0 then
      filtered[#filtered + 1] = bagID
    end
  end
  return filtered
end

WithdrawFromGuildBankToBags = function(tab, itemID, wantCount)
  tab = tonumber(tab)
  itemID = tonumber(itemID)
  wantCount = tonumber(wantCount)
  if not tab or tab <= 0 then return 0 end
  if not itemID or itemID <= 0 then return 0 end
  wantCount = wantCount and math.floor(wantCount) or 0
  if wantCount <= 0 then return 0 end
  if type(GetGuildBankItemLink) ~= "function" and not (CreateFrame and UIParent) then
    return 0, "No guild bank API"
  end
  if type(PickupGuildBankItem) ~= "function" then return 0, "No guild bank API" end
  if not (C_Container and type(C_Container.PickupContainerItem) == "function") then
    return 0, "No container pickup API"
  end

  do
    local okView, whyView = GuildBankTabCanView(tab)
    if not okView then
      return 0, whyView
    end
  end

  -- Some clients are picky about the current tab being selected before data is fully available.
  if type(SetCurrentGuildBankTab) == "function" then
    pcall(SetCurrentGuildBankTab, tab)
  end

  if QueryGuildBankTabIfNeeded then
    QueryGuildBankTabIfNeeded(tab)
  end
  local maxSlots = _G and rawget(_G, "MAX_GUILDBANK_SLOTS_PER_TAB")
  maxSlots = tonumber(maxSlots) or 98

  local maxStack = GetItemMaxStack(itemID)
  local moved = 0
  for slot = 1, maxSlots do
    if moved >= wantCount then return moved end
    local link = GetGuildBankItemLinkSafe(tab, slot)
    if type(link) == "string" then
      local id = tonumber(string.match(link, "item:(%d+)"))
      if id and id == itemID then
        local okI, _, count, locked = false, nil, nil, nil
        if type(GetGuildBankItemInfo) == "function" then
          okI, _, count, locked = pcall(GetGuildBankItemInfo, tab, slot)
        end
        count = okI and tonumber(count) or nil
        locked = okI and locked or nil
        if locked ~= true and count and count > 0 then
          local need = wantCount - moved
          local take = (need < count) and need or count
          if take > 0 then
            local tBag, tSlot = FindBestBagSlotForItem(itemID, maxStack)
            if not (tBag and tSlot) then
              ClearCursorSafe()
              return moved, "No bag space"
            end
            if CursorHasItemSafe() then ClearCursorSafe() end

            local okPick, errPick
            if take < count and type(SplitGuildBankItem) == "function" then
              okPick, errPick = pcall(SplitGuildBankItem, tab, slot, take)
            else
              okPick, errPick = pcall(PickupGuildBankItem, tab, slot)
            end
            if not okPick then
              ClearCursorSafe()
              return moved, "Withdraw pickup failed: " .. tostring(errPick)
            end
            if not CursorHasItemSafe() then
              ClearCursorSafe()
              return moved, "Withdraw pickup did not put item on cursor"
            end

            local okPlace, errPlace = pcall(C_Container.PickupContainerItem, tBag, tSlot)
            if not okPlace then
              ClearCursorSafe()
              return moved, "Withdraw place failed: " .. tostring(errPlace)
            end
            if CursorHasItemSafe() then
              ClearCursorSafe()
              return moved, "Withdraw place was blocked"
            end

            moved = moved + take
          end
        end
      end
    end
  end
  return moved
end

local function WithdrawFromGuildBankToBagsAuto(preferredTab, itemID, wantCount)
  preferredTab = tonumber(preferredTab)
  itemID = tonumber(itemID)
  wantCount = tonumber(wantCount)
  if not itemID or itemID <= 0 then return 0 end
  wantCount = wantCount and math.floor(wantCount) or 0
  if wantCount <= 0 then return 0 end
  if not IsGuildBankOpen() then return 0, "Guild bank not open" end

  local nTabs = GetGuildBankTabCount and GetGuildBankTabCount() or 8
  nTabs = tonumber(nTabs) or 8
  nTabs = math.floor(nTabs)
  if nTabs < 1 then nTabs = 1 end
  if nTabs > 8 then nTabs = 8 end

  local moved = 0
  local anyViewable = false

  local function tryTab(t)
    if moved >= wantCount then return end
    t = tonumber(t)
    if not t or t <= 0 then return end
    if t > nTabs then return end
    local okView = true
    if GuildBankTabCanView then
      okView = (select(1, GuildBankTabCanView(t)) == true)
    end
    if not okView then return end
    anyViewable = true
    local did, why = WithdrawFromGuildBankToBags(t, itemID, wantCount - moved)
    if why then
      return why
    end
    moved = moved + (tonumber(did) or 0)
  end

  local why = nil
  if preferredTab and preferredTab > 0 then
    why = tryTab(preferredTab) or why
  end
  for t = 1, nTabs do
    if moved >= wantCount then break end
    if not preferredTab or t ~= preferredTab then
      why = tryTab(t) or why
    end
  end

  if moved > 0 then return moved end
  if not anyViewable then
    return 0, "No view permission"
  end
  return 0
end

local function RunKeepTopUpForTarget(target, targets)
  if type(targets) ~= "table" then return false end
  local hasAny = false
  for _ in pairs(targets) do hasAny = true break end
  if not hasAny then return false end

  local function resolvedTarget(t)
    t = tostring(t or "")
    t = t:lower():gsub("%s+", "")
    if t == "either" then t = "bank" end
    if t == "warband" then t = "warbank" end
    if t ~= "bank" and t ~= "guild" and t ~= "warbank" then t = "" end
    return t
  end

  target = resolvedTarget(target)
  if target == "" then
    -- No explicit target: treat as "bank" (auto to whichever bank is open).
    target = "bank"
  end

  if target == "bank" then
    if IsWarbankOpen() then target = "warbank"
    elseif IsGuildBankOpen() then target = "guild"
    elseif IsPersonalBankOpen() then target = "bank"
    else return false end
  end

  local anyMoved = false
  for itemID in pairs(targets) do
    itemID = tonumber(itemID)
    if itemID and itemID > 0 then
      local keep = GetEffectiveKeepAmount(itemID)
      local scope = GetEffectiveKeepScope(itemID)
      if keep > 0 and scope ~= "S" then
        local have = CountItemInPlayerBags(itemID)
        if have < keep then
          local need = keep - have
          local moved = 0
          local why

          if target == "warbank" then
            if not IsWarbankOpen() then
              return anyMoved
            end

            local selectedTab = GetSelectedAccountBankTabBagID()
            local warBags = {}
            if selectedTab then
              warBags[1] = selectedTab
            elseif Enum and Enum.BagIndex then
              local e = Enum.BagIndex
              warBags = {
                rawget(e, "AccountBankTab_1"),
                rawget(e, "AccountBankTab_2"),
                rawget(e, "AccountBankTab_3"),
                rawget(e, "AccountBankTab_4"),
                rawget(e, "AccountBankTab_5"),
              }
            end
            local src = {}
            for i = 1, #warBags do
              local id = warBags[i]
              if id and IsAccountBankBagID(id) then src[#src + 1] = id end
            end
            if #src == 0 then
              moved, why = 0, "No Warbank tab is available/selected"
            else
              moved, why = WithdrawFromContainerBagsToBags(src, itemID, need)
            end
          elseif target == "guild" then
            if not IsGuildBankOpen() then
              return anyMoved
            end
            local tab = GetConfiguredGuildBankTab()
            moved, why = WithdrawFromGuildBankToBagsAuto(tab, itemID, need)
          else
            if not IsPersonalBankOpen() then
              return anyMoved
            end
            local src = GetPersonalBankBagIDs()
            moved, why = WithdrawFromContainerBagsToBags(src, itemID, need)
          end

          if moved and moved > 0 then
            anyMoved = true
          elseif why then
            -- Don't spam: only warn when Keep is configured and something is actively blocked.
            Print("Keep withdraw blocked: " .. tostring(why))
            return anyMoved
          end
        end
      end
    end
  end

  return anyMoved
end

local function RunDeposit(target)
  -- Hard gate: do nothing at all unless some bank UI is open.
  if not (IsWarbankOpen() or IsGuildBankOpen() or IsPersonalBankOpen()) then
    return false
  end

  local function Normalize(t)
    t = tostring(t or "")
    t = t:lower():gsub("%s+", "")
    if t == "either" then t = "bank" end
    if t == "warband" then t = "warbank" end
    if t ~= "bank" and t ~= "guild" and t ~= "warbank" then
      t = ""
    end
    return t
  end

  target = Normalize(target)
  if target == "" then
    -- No explicit target: treat as "bank" (auto to whichever bank is open).
    target = "bank"
  end

  local keepMoved = false
  do
    local targets = GetEffectiveDepositItemIDs()
    keepMoved = RunKeepTopUpForTarget(target, targets) == true
  end
  local didDeposit = false
  if target == "guild" then
    didDeposit = RunDepositGuild() == true
  elseif target == "warbank" then
    didDeposit = RunDepositWarband() == true
  else
    -- Bank: whichever bank is currently open.
    if IsWarbankOpen() then
      didDeposit = RunDepositWarband() == true
    elseif IsGuildBankOpen() then
      didDeposit = RunDepositGuild() == true
    elseif IsPersonalBankOpen() then
      didDeposit = RunDepositPersonalBank() == true
    else
      didDeposit = false
    end
  end

  return (keepMoved or didDeposit) and true or false
end

-- Vendor buy/sell/restock (merchant open)
local function NormalizeTradeMode(mode)
  local m = tostring(mode or ""):lower():gsub("%s+", "")
  if m ~= "deposit" and m ~= "buy" and m ~= "sell" then
    m = "deposit"
  end
  return m
end

local function GetTradeMode()
  local cfg = DepositCfgAcc()
  return NormalizeTradeMode(cfg and cfg.tradeMode)
end

local function NormalizeRule(v)
  if v == nil then return nil end
  if type(v) == "number" then
    return { count = math.floor(v) }
  end
  if type(v) == "table" then
    local c = tonumber(v.count)
    if c == nil then c = tonumber(v[1]) end
    c = c and math.floor(c) or nil
    local r = (v.restock == true)
    if c == nil and r ~= true then return nil end
    return { count = c, restock = r }
  end
  return nil
end

local function GetItemNameSafe(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return nil end
  if C_Item and type(C_Item.GetItemNameByID) == "function" then
    local ok, name = pcall(C_Item.GetItemNameByID, itemID)
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
  end
  if type(GetItemInfo) == "function" then
    local name = GetItemInfo(itemID)
    if type(name) == "string" and name ~= "" then
      return name
    end
  end
  return nil
end

local function GetItemLinkSafe(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return nil end
  if type(GetItemInfo) == "function" then
    local ok, name, link = pcall(GetItemInfo, itemID)
    if ok and type(link) == "string" and link ~= "" then
      return link
    end
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
  end
  return GetItemNameSafe(itemID) or tostring(itemID)
end

local function StripLinkBrackets(s)
  if type(s) ~= "string" then return s end
  -- Item links are usually: |Hitem:...|h[Name]|h
  s = s:gsub("(|h)%[(.-)%](|h)", "%1%2%3")
  return s
end

local function GetClassColoredPlayerName()
  local n = (UnitName and UnitName("player")) or ""
  n = tostring(n or "")
  local short = n:match("^(.-)%-") or n
  if short == "" then short = "Player" end

  local classFile = nil
  if type(UnitClass) == "function" then
    local _, c = UnitClass("player")
    classFile = c
  end

  local r, g, b = 1, 1, 1
  if classFile and type(C_ClassColor) == "table" and type(C_ClassColor.GetClassColor) == "function" then
    local ok, colorObj = pcall(C_ClassColor.GetClassColor, classFile)
    if ok and type(colorObj) == "table" then
      if type(colorObj.GetRGB) == "function" then
        local rr, gg, bb = colorObj:GetRGB()
        r, g, b = tonumber(rr) or r, tonumber(gg) or g, tonumber(bb) or b
      elseif type(colorObj.r) == "number" then
        r, g, b = colorObj.r or r, colorObj.g or g, colorObj.b or b
      end
    end
  elseif classFile and type(RAID_CLASS_COLORS) == "table" and type(RAID_CLASS_COLORS[classFile]) == "table" then
    local c = RAID_CLASS_COLORS[classFile]
    r, g, b = tonumber(c.r) or r, tonumber(c.g) or g, tonumber(c.b) or b
  end

  local function toHex(x)
    x = tonumber(x) or 0
    if x < 0 then x = 0 end
    if x > 1 then x = 1 end
    return string.format("%02x", math.floor(x * 255 + 0.5))
  end

  return "|cff" .. toHex(r) .. toHex(g) .. toHex(b) .. short .. ":|r"
end

local function FormatGoldOnly(totalCopper)
  local copper = tonumber(totalCopper) or 0
  if copper < 0 then copper = 0 end
  local gold = math.floor(copper / 10000)
  if gold < 1 then gold = 1 end
  return tostring(gold) .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
end

local function GetRealmRuleTable(cfg, mode)
  local rk = GetCurrentRealmKey()
  if rk == "" then return nil, nil end
  if mode == "buy" then
    cfg.buyItemsRealm = (type(cfg.buyItemsRealm) == "table") and cfg.buyItemsRealm or {}
    cfg.buyItemsRealm[rk] = (type(cfg.buyItemsRealm[rk]) == "table") and cfg.buyItemsRealm[rk] or {}
    return cfg.buyItemsRealm[rk], rk
  end
  if mode == "sell" then
    cfg.sellItemsRealm = (type(cfg.sellItemsRealm) == "table") and cfg.sellItemsRealm or {}
    cfg.sellItemsRealm[rk] = (type(cfg.sellItemsRealm[rk]) == "table") and cfg.sellItemsRealm[rk] or {}
    return cfg.sellItemsRealm[rk], rk
  end
  cfg.itemsRealm = (type(cfg.itemsRealm) == "table") and cfg.itemsRealm or {}
  cfg.itemsRealm[rk] = (type(cfg.itemsRealm[rk]) == "table") and cfg.itemsRealm[rk] or {}
  return cfg.itemsRealm[rk], rk
end

local function GetScopeStores(mode)
  local cfg = DepositCfgAcc()
  local ch = DepositCfgChar()
  local realmTbl, realmKey = GetRealmRuleTable(cfg, mode)
  if mode == "buy" then
    return cfg.buyItemsAcc, realmTbl, realmKey, ch.buyItemsChar, ch.buyDisableAcc
  end
  if mode == "sell" then
    return cfg.sellItemsAcc, realmTbl, realmKey, ch.sellItemsChar, ch.sellDisableAcc
  end
  return cfg.itemsAcc, realmTbl, realmKey, ch.itemsChar, ch.disableAcc
end

local function GetEffectiveTradeRules(mode)
  mode = NormalizeTradeMode(mode)
  local accTbl, realmTbl, realmKey, charTbl, disableAccTbl = GetScopeStores(mode)
  local out = {}

  local cfg = DepositCfgAcc()
  local ch = DepositCfgChar()

  local accDisabledTbl = nil
  local accDisableRealmTbl = nil
  local realmDisabledTbl = nil
  local charDisabledTbl = nil
  local disableRealmTbl = nil

  if mode == "buy" then
    accDisabledTbl = cfg.buyItemsAccDisabled
    accDisableRealmTbl = (type(cfg.buyItemsAccDisableRealm) == "table" and realmKey and realmKey ~= "") and cfg.buyItemsAccDisableRealm[realmKey] or nil
    realmDisabledTbl = (type(cfg.buyItemsRealmDisabled) == "table" and realmKey and realmKey ~= "") and cfg.buyItemsRealmDisabled[realmKey] or nil
    charDisabledTbl = ch.buyItemsCharDisabled
    disableRealmTbl = ch.buyDisableRealm
  elseif mode == "sell" then
    accDisabledTbl = cfg.sellItemsAccDisabled
    accDisableRealmTbl = (type(cfg.sellItemsAccDisableRealm) == "table" and realmKey and realmKey ~= "") and cfg.sellItemsAccDisableRealm[realmKey] or nil
    realmDisabledTbl = (type(cfg.sellItemsRealmDisabled) == "table" and realmKey and realmKey ~= "") and cfg.sellItemsRealmDisabled[realmKey] or nil
    charDisabledTbl = ch.sellItemsCharDisabled
    disableRealmTbl = ch.sellDisableRealm
  else
    accDisabledTbl = cfg.itemsAccDisabled
    accDisableRealmTbl = (type(cfg.itemsAccDisableRealm) == "table" and realmKey and realmKey ~= "") and cfg.itemsAccDisableRealm[realmKey] or nil
    realmDisabledTbl = (type(cfg.itemsRealmDisabled) == "table" and realmKey and realmKey ~= "") and cfg.itemsRealmDisabled[realmKey] or nil
    charDisabledTbl = ch.itemsCharDisabled
    disableRealmTbl = ch.disableRealm
  end

  local function setFrom(tbl, isAccount, isRealm, isChar)
    if type(tbl) ~= "table" then return end
    for id, v in pairs(tbl) do
      id = tonumber(id)
      if id and id > 0 then
        if isAccount and ((type(accDisabledTbl) == "table" and accDisabledTbl[id] == true) or (type(accDisableRealmTbl) == "table" and accDisableRealmTbl[id] == true) or (type(disableAccTbl) == "table" and disableAccTbl[id] == true)) then
          -- skip
        elseif isRealm and ((type(realmDisabledTbl) == "table" and realmDisabledTbl[id] == true) or (type(disableRealmTbl) == "table" and disableRealmTbl[id] == true)) then
          -- skip
        elseif isChar and (type(charDisabledTbl) == "table" and charDisabledTbl[id] == true) then
          -- skip
        else
          if mode == "deposit" then
            if v == true then
              out[id] = { on = true }
            end
          else
            local r = NormalizeRule(v)
            if r and r.count ~= nil then
              out[id] = { count = r.count, restock = r.restock == true }
            end
          end
        end
      end
    end
  end

  -- Priority: Account -> Realm -> Character
  setFrom(accTbl, true, false, false)
  setFrom(realmTbl, false, true, false)
  setFrom(charTbl, false, false, true)
  return out
end

local function IterateBagSlots(cb)
  for bag = 0, 6 do
    local n = 0
    if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
      local ok, v = pcall(C_Container.GetContainerNumSlots, bag)
      n = ok and tonumber(v) or 0
    end
    if n and n > 0 then
      for slot = 1, n do
        cb(bag, slot)
      end
    end
  end
end

local function GetBagItemInfo(bag, slot)
  if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
    local ok, v = pcall(C_Container.GetContainerItemInfo, bag, slot)
    return ok and v or nil
  end
  return nil
end

local function UseContainerItemSafe(bag, slot)
  if C_Container and type(C_Container.UseContainerItem) == "function" then
    pcall(C_Container.UseContainerItem, bag, slot)
    return
  end
  local uci = _G and _G["UseContainerItem"]
  if type(uci) == "function" then
    pcall(uci, bag, slot)
  end
end

local function CountItemInBags(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return 0 end
  local total = 0
  IterateBagSlots(function(bag, slot)
    local info = GetBagItemInfo(bag, slot)
    if info and tonumber(info.itemID) == itemID then
      local stack = tonumber(info.stackCount)
      total = total + (stack or 1)
    end
  end)
  return total
end

-- Use-text parsing (used by restock to group items).
-- NOTE: For food/drink we *must not* strip numbers, otherwise 5% and 7% become equivalent.
local _useKeyCacheByID = {}
local _foodUseCacheByID = {}

local function IsFoodDrinkItemID(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return false end
  if not (C_Item and type(C_Item.GetItemInfoInstant) == "function") then return false end
  local ok, _, _, _, _, _, classID, subClassID = pcall(C_Item.GetItemInfoInstant, itemID)
  if not ok then return false end
  return (tonumber(classID) == 0) and (tonumber(subClassID) == 5)
end

local function NormalizeUseText_Generic(s)
  if type(s) ~= "string" then return nil end
  local t = s:lower()
  t = t:gsub("^use:%s*", "")
  -- Generic normalization intentionally strips digits so e.g. "Deals 500" and "Deals 600" can be grouped.
  -- Food/drink is handled separately.
  t = t:gsub("%d+", "")
  t = t:gsub("[%p%c]", " ")
  t = t:gsub("%s+", " ")
  t = t:gsub("^%s+", "")
  t = t:gsub("%s+$", "")
  if t == "" then return nil end
  return t
end

local function ParseFoodDrinkUseLine(s)
  if type(s) ~= "string" or s == "" then return nil end
  local low = s:lower()
  if not low:find("^use:", 1) then return nil end
  if not low:find("restores", 1, true) then return nil end
  -- Tooltip text varies; accept "health" with %.
  if not low:find("health", 1, true) then return nil end

  -- Example (2026+):
  -- "Use: Restores 7% of your maximum health and mana every second over 20 sec."
  local pct = low:match("restores%s+(%d+)%s*%%")
  pct = pct and tonumber(pct) or nil
  if not pct then return nil end

  local dur = low:match("over%s+(%d+)%s*sec") or low:match("for%s+(%d+)%s*sec")
  dur = dur and tonumber(dur) or nil

  -- Avoid false positives: %health food/drink typically has a duration.
  if dur == nil and not low:find("every second", 1, true) then
    return nil
  end

  local hasMana = (low:find("mana", 1, true) ~= nil)
  return {
    pct = pct,
    dur = dur,
    hasMana = hasMana,
  }
end

local function GetFoodDrinkTupleForItemID(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return nil end
  if _foodUseCacheByID[itemID] ~= nil then
    return _foodUseCacheByID[itemID]
  end

  -- Only treat actual food/drink items as "food restock" candidates.
  if not IsFoodDrinkItemID(itemID) then
    _foodUseCacheByID[itemID] = false
    return nil
  end

  local tuple = nil
  if C_TooltipInfo and type(C_TooltipInfo.GetHyperlink) == "function" then
    local ok, tip = pcall(C_TooltipInfo.GetHyperlink, "item:" .. tostring(itemID))
    if ok and type(tip) == "table" and type(tip.lines) == "table" then
      for _, line in ipairs(tip.lines) do
        local left = (type(line) == "table") and line.leftText or nil
        if type(left) == "string" and left:find("^Use:", 1) then
          tuple = ParseFoodDrinkUseLine(left)
          if tuple then break end
        end
      end
    end
  end

  _foodUseCacheByID[itemID] = tuple or false
  return tuple
end

local function GetFoodDrinkCategoryKey(tuple)
  if type(tuple) ~= "table" then return nil end
  -- Category is intentionally coarse: any %health-restoring food/drink.
  -- We intentionally do NOT split by "also restores mana" so non-mana classes
  -- can still buy the best %health option when it happens to be health+mana.
  return "foodrestores"
end

local function FoodDrinkScore(tuple)
  if type(tuple) ~= "table" then return nil end
  local pct = tonumber(tuple.pct) or nil
  if not pct then return nil end
  local dur = tonumber(tuple.dur) or 20
  if dur <= 0 then dur = 20 end
  return pct * dur
end

local function GetUseKeyForItemID(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return nil end

  if _useKeyCacheByID[itemID] ~= nil then
    return _useKeyCacheByID[itemID]
  end

  -- Prefer specialized food/drink keys if the item matches that pattern.
  local fd = GetFoodDrinkTupleForItemID(itemID)
  if type(fd) == "table" then
    local score = FoodDrinkScore(fd) or 0
    local k = (GetFoodDrinkCategoryKey(fd) or "foodrestores") .. "|score:" .. tostring(score)
    _useKeyCacheByID[itemID] = k
    return k
  end

  local useLines = {}
  local hasMana = false

  if C_TooltipInfo and type(C_TooltipInfo.GetHyperlink) == "function" then
    local ok, tip = pcall(C_TooltipInfo.GetHyperlink, "item:" .. tostring(itemID))
    if ok and type(tip) == "table" and type(tip.lines) == "table" then
      for _, line in ipairs(tip.lines) do
        local left = (type(line) == "table") and line.leftText or nil
        if type(left) == "string" and left:find("^Use:", 1) then
          local norm = NormalizeUseText_Generic(left)
          if norm then
            useLines[#useLines + 1] = norm
            if norm:find("mana", 1, true) then hasMana = true end
          end
        end
      end
    end
  end

  if #useLines == 0 then
    _useKeyCacheByID[itemID] = false
    return nil
  end
  local out = table.concat(useLines, " ") .. "|mana:" .. (hasMana and "1" or "0")
  _useKeyCacheByID[itemID] = out
  return out
end

local function CountFoodDrinkAtOrAboveInBags(categoryKey, minScore)
  if type(categoryKey) ~= "string" or categoryKey == "" then return 0 end
  minScore = tonumber(minScore) or 0
  local total = 0
  IterateBagSlots(function(bag, slot)
    local info = GetBagItemInfo(bag, slot)
    local itemID = info and tonumber(info.itemID) or nil
    if itemID then
      local t = GetFoodDrinkTupleForItemID(itemID)
      if type(t) == "table" and GetFoodDrinkCategoryKey(t) == categoryKey then
        local sc = FoodDrinkScore(t) or 0
        if sc >= minScore then
          local stack = info and tonumber(info.stackCount) or nil
          total = total + (stack or 1)
        end
      end
    end
  end)
  return total
end

local function GetMaxFoodDrinkScoreInBags(categoryKey)
  if type(categoryKey) ~= "string" or categoryKey == "" then return nil end
  local best = nil
  IterateBagSlots(function(bag, slot)
    local info = GetBagItemInfo(bag, slot)
    local itemID = info and tonumber(info.itemID) or nil
    if itemID then
      local t = GetFoodDrinkTupleForItemID(itemID)
      if type(t) == "table" and GetFoodDrinkCategoryKey(t) == categoryKey then
        local sc = FoodDrinkScore(t)
        if sc and ((not best) or sc > best) then
          best = sc
        end
      end
    end
  end)
  return best
end

local function PlayerUsesMana()
  if type(UnitPowerType) ~= "function" then return false end
  local pt = UnitPowerType("player")
  return (pt == 0)
end

local function CountEquivalentByUseKeyInBags(useKey)
  if type(useKey) ~= "string" or useKey == "" then return 0 end
  local total = 0
  IterateBagSlots(function(bag, slot)
    local info = GetBagItemInfo(bag, slot)
    local itemID = info and tonumber(info.itemID) or nil
    if itemID then
      local k = GetUseKeyForItemID(itemID)
      if k and k == useKey then
        local stack = info and tonumber(info.stackCount) or nil
        total = total + (stack or 1)
      end
    end
  end)
  return total
end

local function GetMerchantIndexForItemID(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return nil end
  if type(GetMerchantNumItems) ~= "function" then return nil end
  local n = tonumber(GetMerchantNumItems()) or 0
  for i = 1, n do
    local link = type(GetMerchantItemLink) == "function" and GetMerchantItemLink(i) or nil
    if type(link) == "string" then
      local id = link:match("Hitem:(%d+):")
      id = id and tonumber(id) or nil
      if id == itemID then
        return i
      end
    end
  end
  return nil
end

local function GetItemRequiredPlayerLevel(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return nil end
  if type(GetItemInfo) ~= "function" then return nil end
  -- GetItemInfo returns: name, link, quality, itemLevel, requiredLevel, ...
  local ok, _, _, _, reqLevel = pcall(GetItemInfo, itemID)
  if not ok then return nil end
  reqLevel = tonumber(reqLevel)
  if reqLevel and reqLevel > 0 then
    return reqLevel
  end
  return nil
end

local function GetBestMerchantFoodDrinkForCategory(categoryKey, usesMana)
  if type(categoryKey) ~= "string" or categoryKey == "" then return nil end
  if type(GetMerchantNumItems) ~= "function" then return nil end
  local n = tonumber(GetMerchantNumItems()) or 0
  if n <= 0 then return nil end

  local pl = (type(UnitLevel) == "function") and tonumber(UnitLevel("player")) or nil

  local function isUsableForPlayer(id)
    if not pl then return true end
    local reqLevel = GetItemRequiredPlayerLevel(id)
    -- If item info isn't cached yet, treat as not usable (avoid buying unusable items).
    if reqLevel == nil then
      return false
    end
    if reqLevel > pl then
      return false
    end
    if C_Item and type(C_Item.IsUsableItem) == "function" then
      local okU, usable = pcall(C_Item.IsUsableItem, id)
      if okU and usable == false then
        return false
      end
    elseif type(IsUsableItem) == "function" then
      local okU, usable = pcall(IsUsableItem, id)
      if okU and usable == false then
        return false
      end
    end
    return true
  end

  local best = { idx = nil, itemID = nil, score = nil, pct = nil, unitPrice = nil }

  for i = 1, n do
    local link = type(GetMerchantItemLink) == "function" and GetMerchantItemLink(i) or nil
    if type(link) == "string" then
      local id = link:match("Hitem:(%d+):")
      id = id and tonumber(id) or nil
      if id and id > 0 and isUsableForPlayer(id) then
        local t = GetFoodDrinkTupleForItemID(id)
        if type(t) == "table" and GetFoodDrinkCategoryKey(t) == categoryKey then
          local sc = FoodDrinkScore(t) or nil
          if sc then
            local price, qty = nil, nil
            if C_MerchantFrame and type(C_MerchantFrame.GetItemInfo) == "function" then
              local okI, info = pcall(C_MerchantFrame.GetItemInfo, i)
              if okI and type(info) == "table" then
                price = tonumber(info.price)
                qty = tonumber(info.stackCount or info.quantity)
              end
            end
            if price == nil and type(GetMerchantItemInfo) == "function" then
              local okI, _, _, p, q = pcall(GetMerchantItemInfo, i)
              if okI then
                price = tonumber(p)
                qty = tonumber(q)
              end
            end
            if qty == nil or qty <= 0 then qty = 1 end
            local unit = (price and price > 0) and (price / qty) or nil

            local better = false
            if not best.idx then
              better = true
            elseif sc > (best.score or 0) then
              better = true
            elseif sc == (best.score or 0) then
              if unit ~= nil and (best.unitPrice == nil or unit < best.unitPrice) then
                better = true
              end
            end

            if better then
              best.idx, best.itemID, best.score, best.pct, best.unitPrice = i, id, sc, tonumber(t.pct) or nil, unit
            end
          end
        end
      end
    end
  end

  if not best.idx then return nil end
  return best
end

local function GetBestMerchantItemForUseKey(useKey, usesMana)
  if type(useKey) ~= "string" or useKey == "" then return nil end
  if type(GetMerchantNumItems) ~= "function" then return nil end
  local n = tonumber(GetMerchantNumItems()) or 0
  if n <= 0 then return nil end

  local pl = (type(UnitLevel) == "function") and tonumber(UnitLevel("player")) or nil

  local function isUsableForPlayer(id)
    if not pl then return true end
    local reqLevel = GetItemRequiredPlayerLevel(id)
    if reqLevel == nil then
      return false
    end
    if reqLevel > pl then
      return false
    end
    if C_Item and type(C_Item.IsUsableItem) == "function" then
      local okU, usable = pcall(C_Item.IsUsableItem, id)
      if okU and usable == false then
        return false
      end
    elseif type(IsUsableItem) == "function" then
      local okU, usable = pcall(IsUsableItem, id)
      if okU and usable == false then
        return false
      end
    end
    return true
  end

  local best = { idx = nil, itemID = nil, unitPrice = nil }

  for i = 1, n do
    local link = type(GetMerchantItemLink) == "function" and GetMerchantItemLink(i) or nil
    if type(link) == "string" then
      local id = link:match("Hitem:(%d+):")
      id = id and tonumber(id) or nil
      if id and id > 0 and isUsableForPlayer(id) then
        local k = GetUseKeyForItemID(id)
        if k and k == useKey then
          if (usesMana == false) and (k:sub(-7) == "|mana:1") then
            -- Non-mana classes: skip mana-tagged use items.
          else
            local price, qty = nil, nil
            if C_MerchantFrame and type(C_MerchantFrame.GetItemInfo) == "function" then
              local okI, info = pcall(C_MerchantFrame.GetItemInfo, i)
              if okI and type(info) == "table" then
                price = tonumber(info.price)
                qty = tonumber(info.stackCount or info.quantity)
              end
            end
            if price == nil and type(GetMerchantItemInfo) == "function" then
              local okI, _, _, p, q = pcall(GetMerchantItemInfo, i)
              if okI then
                price = tonumber(p)
                qty = tonumber(q)
              end
            end
            if qty == nil or qty <= 0 then qty = 1 end
            local unit = (price and price > 0) and (price / qty) or nil

            local better = false
            if not best.idx then
              better = true
            elseif unit ~= nil and (best.unitPrice == nil or unit < best.unitPrice) then
              better = true
            end

            if better then
              best.idx, best.itemID, best.unitPrice = i, id, unit
            end
          end
        end
      end
    end
  end

  if not best.idx then return nil end
  return best
end

local function IsFoodItemID(itemID)
  if not (C_Item and type(C_Item.GetItemInfoInstant) == "function") then return false end
  local ok, _, _, _, _, _, classID, subClassID = pcall(C_Item.GetItemInfoInstant, itemID)
  if not ok then return false end
  return (tonumber(classID) == 0) and (tonumber(subClassID) == 5)
end

local function GetItemMinLevel(itemID, link)
  itemID = tonumber(itemID)
  if not itemID then return nil end
  if type(GetItemInfo) == "function" then
    local _, _, _, ilvl, reqLevel = GetItemInfo(itemID)
    reqLevel = tonumber(reqLevel)
    if reqLevel and reqLevel > 0 then
      return reqLevel
    end
    ilvl = tonumber(ilvl)
    if ilvl and ilvl > 0 then
      return ilvl
    end
  end
  if link and type(GetDetailedItemLevelInfo) == "function" then
    local okI, ilvl = pcall(GetDetailedItemLevelInfo, link)
    ilvl = okI and tonumber(ilvl) or nil
    if ilvl and ilvl > 0 then
      return ilvl
    end
  end
  return nil
end

local function GetItemSellPrice(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return nil end
  if type(GetItemInfo) == "function" then
    local sellPrice = select(11, GetItemInfo(itemID))
    sellPrice = tonumber(sellPrice)
    return sellPrice
  end
  return nil
end

local function SellOldFoodAtMerchant(levelDiff, protectedIDs)
  local diff = tonumber(levelDiff) or 10
  if diff < 1 then diff = 1 end
  if diff > 80 then diff = 80 end

  local pl = type(UnitLevel) == "function" and tonumber(UnitLevel("player")) or nil
  if not pl or pl <= 1 then return end
  local threshold = pl - diff

  local soldByID = {}
  local ops = 0
  local maxOps = 200

  IterateBagSlots(function(bag, slot)
    if ops >= maxOps then return end
    local info = GetBagItemInfo(bag, slot)
    if not info or info.isLocked then return end
    local itemID = tonumber(info.itemID)
    if not itemID or not IsFoodItemID(itemID) then return end
    if type(protectedIDs) == "table" and protectedIDs[itemID] == true then return end
    local link = nil
    if C_Container and type(C_Container.GetContainerItemLink) == "function" then
      local okL, vL = pcall(C_Container.GetContainerItemLink, bag, slot)
      link = okL and vL or nil
    end
    local req = GetItemMinLevel(itemID, link)
    if not req or req <= 0 then return end
    if req > threshold then return end
    local sellPrice = GetItemSellPrice(itemID)
    if not sellPrice or sellPrice <= 0 then return end

    local stack = tonumber(info.stackCount) or 1
    UseContainerItemSafe(bag, slot)
    soldByID[itemID] = (soldByID[itemID] or 0) + stack
    ops = ops + 1
  end)

  for id, cnt in pairs(soldByID) do
    if Print then
      local perItem = GetItemSellPrice(id)
      local total = (perItem and perItem > 0) and (perItem * cnt) or nil
      local moneyText = FormatGoldOnly(total or 0)
      local itemText = StripLinkBrackets(GetItemLinkSafe(id) or tostring(id))
      Print(GetClassColoredPlayerName() .. " " .. tostring(moneyText) .. "  Sold  " .. tostring(itemText) .. " x" .. tostring(cnt))
    end
  end
end

local function IsSellFoodEnabled()
  EnsureDB()
  local acc = DepositCfgAcc()
  local ch = DepositCfgChar()
  return ((acc and acc.sellFoodEnabledAcc) == true) or ((ch and ch.sellFoodEnabledChar) == true)
end

local function DebugSellOldFoodAtMerchant(levelDiff, maxLines)
  local diff = tonumber(levelDiff) or 10
  if diff < 1 then diff = 1 end
  if diff > 80 then diff = 80 end

  local pl = type(UnitLevel) == "function" and tonumber(UnitLevel("player")) or nil
  local threshold = (pl and pl > 1) and (pl - diff) or nil

  local mf = _G and rawget(_G, "MerchantFrame")
  local merchantShown = (mf and mf.IsShown and mf:IsShown()) and true or false

  Print("Food debug: merchantShown=" .. tostring(merchantShown) .. ", enabled=" .. tostring(IsSellFoodEnabled()) .. ", diff=" .. tostring(diff) .. ", player=" .. tostring(pl) .. ", threshold=" .. tostring(threshold))

  local lines = 0
  local cap = tonumber(maxLines) or 25
  if cap < 5 then cap = 5 end
  if cap > 60 then cap = 60 end

  local counts = { total = 0, food = 0, eligible = 0, locked = 0, noReq = 0, above = 0, noPrice = 0 }

  IterateBagSlots(function(bag, slot)
    if lines >= cap then return end

    local info = GetBagItemInfo(bag, slot)
    if not info then return end
    local itemID = tonumber(info.itemID)
    if not itemID or itemID <= 0 then return end

    counts.total = counts.total + 1
    local locked = (info.isLocked == true)
    if locked then counts.locked = counts.locked + 1 end

    local classID, subClassID = nil, nil
    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
      local ok, _, _, _, _, _, c, s = pcall(C_Item.GetItemInfoInstant, itemID)
      if ok then classID, subClassID = tonumber(c), tonumber(s) end
    end
    local isFood = IsFoodItemID(itemID)
    if isFood then counts.food = counts.food + 1 end
    if not isFood then return end

    local link = nil
    if C_Container and type(C_Container.GetContainerItemLink) == "function" then
      local okL, vL = pcall(C_Container.GetContainerItemLink, bag, slot)
      link = okL and vL or nil
    end

    local req = GetItemMinLevel(itemID, link)
    if not req or req <= 0 then counts.noReq = counts.noReq + 1 end

    local sellPrice = GetItemSellPrice(itemID)
    if not sellPrice or sellPrice <= 0 then counts.noPrice = counts.noPrice + 1 end

    local okThreshold = (threshold ~= nil) and (req ~= nil) and (req > 0) and (req <= threshold)
    if threshold ~= nil and req and req > threshold then counts.above = counts.above + 1 end

    local eligible = (not locked) and okThreshold and (sellPrice and sellPrice > 0)
    if eligible then counts.eligible = counts.eligible + 1 end

    local name = (GetItemNameSafe and GetItemNameSafe(itemID)) or tostring(itemID)
    local stack = tonumber(info.stackCount) or 1
    Print(string.format("Food slot: bag=%d slot=%d id=%d x%d class=%s/%s req=%s price=%s eligible=%s %s", bag, slot, itemID, stack, tostring(classID), tostring(subClassID), tostring(req), tostring(sellPrice), tostring(eligible), name))
    lines = lines + 1
  end)

  Print(string.format("Food debug summary: totalItems=%d, food=%d, eligible=%d, locked=%d, noReq=%d, aboveThreshold=%d, noPrice=%d", counts.total, counts.food, counts.eligible, counts.locked, counts.noReq, counts.above, counts.noPrice))
end

LI.DebugSellOldFoodAtMerchant = DebugSellOldFoodAtMerchant

local function GetFreeBackpackSlots()
  if not (C_Container and type(C_Container.GetContainerNumFreeSlots) == "function") then
    return nil
  end
  local total = 0
  for bag = 0, 4 do
    local ok, free = pcall(C_Container.GetContainerNumFreeSlots, bag)
    if ok and type(free) == "number" then
      total = total + free
    end
  end
  return total
end

-- Merchant session buy tracking (used to avoid double-buying on fast tickers).
local _liMerchantBuyBaselineHave
local _liMerchantBuySessionBought
local _liMerchantNotSoldWarned

local function RunMerchantTradeOnce(skipFoodSell)
  local mode = GetTradeMode()

  local foodEnabled = IsSellFoodEnabled()
  local foodDiff = (DB and DB.deposit and tonumber(DB.deposit.sellFoodLevelDiff)) or 10
  foodDiff = foodDiff and math.floor(foodDiff) or 10
  if foodDiff < 1 then foodDiff = 1 end
  if foodDiff > 80 then foodDiff = 80 end

  -- Food selling is independent of buy/sell mode; run whenever enabled at merchant.
  -- When running on a ticker, only do it once per merchant open.
  if (skipFoodSell ~= true) and foodEnabled then
    local protected = nil
    if type(GetEffectiveTradeRules) == "function" then
      local buyRules = GetEffectiveTradeRules("buy")
      if type(buyRules) == "table" and next(buyRules) then
        protected = {}
        for id in pairs(buyRules) do
          id = tonumber(id)
          if id and id > 0 then
            protected[id] = true
          end
        end
      end
    end
    SellOldFoodAtMerchant(foodDiff, protected)
  end

  if mode ~= "buy" and mode ~= "sell" then return 0 end

  local rules = GetEffectiveTradeRules(mode)
  if type(rules) ~= "table" then return 0 end

  local any = false
  local anyRestock = false
  for _, r in pairs(rules) do
    any = true
    if r and r.restock == true then anyRestock = true end
  end
  if not any then return 0 end

LI.RunDeposit = RunDeposit

  local usesMana = PlayerUsesMana()
  local ops = 0
  local maxOps = 200

  local function GetRestockGroupKey(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return nil end
    local fd = GetFoodDrinkTupleForItemID(itemID)
    local cat = fd and GetFoodDrinkCategoryKey(fd) or nil
    if cat then
      return "food:" .. tostring(cat)
    end
    local key = GetUseKeyForItemID(itemID)
    if key then
      return "use:" .. tostring(key)
    end
    return nil
  end

  -- Prevent double-buying across fast merchant ticker ticks by tracking what we've
  -- already requested this merchant session. Bag counts can lag behind.
  local function GetHaveCount(id)
    id = tonumber(id)
    if not id or id <= 0 then return 0 end

    local raw = CountItemInBags(id) or 0

    if type(_liMerchantBuyBaselineHave) ~= "table" or type(_liMerchantBuySessionBought) ~= "table" then
      return raw
    end

    if _liMerchantBuyBaselineHave[id] == nil then
      _liMerchantBuyBaselineHave[id] = raw
    end

    local base = tonumber(_liMerchantBuyBaselineHave[id]) or 0
    local bought = tonumber(_liMerchantBuySessionBought[id]) or 0
    local expected = base + bought
    if expected > raw then
      return expected
    end
    return raw
  end

  local function GetPendingBought(id)
    id = tonumber(id)
    if not id or id <= 0 then return 0 end

    if type(_liMerchantBuyBaselineHave) ~= "table" or type(_liMerchantBuySessionBought) ~= "table" then
      return 0
    end

    local raw = CountItemInBags(id) or 0
    if _liMerchantBuyBaselineHave[id] == nil then
      _liMerchantBuyBaselineHave[id] = raw
    end
    local base = tonumber(_liMerchantBuyBaselineHave[id]) or 0
    local bought = tonumber(_liMerchantBuySessionBought[id]) or 0
    local expected = base + bought
    local pending = expected - raw
    if pending > 0 then return pending end
    return 0
  end

  local function GetMerchantItemBuyInfo(idx)
    idx = tonumber(idx)
    if not idx or idx <= 0 then return nil end

    local maxStack = nil
    if type(GetMerchantItemMaxStack) == "function" then
      local okS, v = pcall(GetMerchantItemMaxStack, idx)
      maxStack = okS and tonumber(v) or nil
      if maxStack ~= nil and maxStack < 1 then maxStack = nil end
    end

    -- Prefer modern API if available; it is usually more reliable on Retail.
    if C_MerchantFrame and type(C_MerchantFrame.GetItemInfo) == "function" then
      local ok, info = pcall(C_MerchantFrame.GetItemInfo, idx)
      if ok and type(info) == "table" then
        local name = info.name
        local price = tonumber(info.price) or 0
        local quantity = tonumber(info.stackCount or info.quantity) or 1
        local numAvailable = info.numAvailable
        return {
          name = (type(name) == "string" and name ~= "") and name or nil,
          price = price,
          quantity = (quantity and quantity > 0) and quantity or 1,
          numAvailable = (numAvailable ~= nil) and tonumber(numAvailable) or nil,
          maxStack = maxStack,
        }
      end
    end

    -- Fallback legacy API.
    if type(GetMerchantItemInfo) == "function" then
      local ok, name, _, price, quantity, numAvailable = pcall(GetMerchantItemInfo, idx)
      if ok then
        price = tonumber(price) or 0
        quantity = tonumber(quantity) or 1
        return {
          name = (type(name) == "string" and name ~= "") and name or nil,
          price = price,
          quantity = (quantity and quantity > 0) and quantity or 1,
          numAvailable = (numAvailable ~= nil) and tonumber(numAvailable) or nil,
          maxStack = maxStack,
        }
      end
    end

    return nil
  end

  if mode == "buy" then
    -- Restock grouping: if multiple rules are restock-equivalent, only act once per group.
    local restockGroupTarget = {}
    local restockGroupSeed = {}
    for itemID, r in pairs(rules) do
      itemID = tonumber(itemID)
      local target = r and tonumber(r.count) or nil
      if itemID and itemID > 0 and r and r.restock == true and target and target > 0 then
        local gk = GetRestockGroupKey(itemID)
        if gk then
          local cur = tonumber(restockGroupTarget[gk])
          if (cur == nil) or (target > cur) then
            restockGroupTarget[gk] = target
          end
          if restockGroupSeed[gk] == nil then
            restockGroupSeed[gk] = itemID
          end
        end
      end
    end

    for itemID, r in pairs(rules) do
      if ops >= maxOps then break end
      local target = r and tonumber(r.count) or nil
      if target and target > 0 then
        local skipThisRule = false
        if r and r.restock == true then
          local gk = GetRestockGroupKey(itemID)
          if gk and restockGroupSeed[gk] ~= nil and restockGroupSeed[gk] ~= itemID then
            -- Skip: another rule is the seed for this restock group.
            skipThisRule = true
          end
          if gk and restockGroupTarget[gk] ~= nil then
            target = tonumber(restockGroupTarget[gk]) or target
          end
        end
        if not skipThisRule then
          local current = 0
          if r.restock == true then
            -- Food/drink: pick strongest matching item sold by this merchant,
            -- and count bag items that are >= that strength.
            local fd = GetFoodDrinkTupleForItemID(itemID)
            local cat = fd and GetFoodDrinkCategoryKey(fd) or nil
            if cat then
              local best = GetBestMerchantFoodDrinkForCategory(cat, usesMana)
              local skipLowerTierVendor = false
              if best and best.score then
                -- If the merchant is "lower end" than what we already have, don't buy downgrades.
                local maxBag = GetMaxFoodDrinkScoreInBags(cat)
                if maxBag and maxBag > best.score then
                  skipLowerTierVendor = true
                  if Print then
                    Print("Restock skipped (merchant lower tier): " .. (GetItemNameSafe(itemID) or tostring(itemID)))
                  end
                end
              end

              if skipLowerTierVendor then
                -- Treat as satisfied so this rule won't buy from this vendor.
                current = target
              else
                local desiredScore = (best and best.score) or FoodDrinkScore(fd) or 0
                current = CountFoodDrinkAtOrAboveInBags(cat, desiredScore)
                if best and best.itemID then
                  current = current + GetPendingBought(best.itemID)
                end
              end
            else
              local key = GetUseKeyForItemID(itemID)
              if key then
                local hasMana = (key:sub(-7) == "|mana:1")
                if (not usesMana) and hasMana then
                  -- Non-mana classes: do not restock mana items.
                  current = target
                else
                  local best = GetBestMerchantItemForUseKey(key, usesMana)
                  current = CountEquivalentByUseKeyInBags(key)
                  if best and best.itemID then
                    current = current + GetPendingBought(best.itemID)
                  end
                end
              else
                current = GetHaveCount(itemID)
              end
            end
          else
            current = GetHaveCount(itemID)
          end

          local need = target - current
          if need > 0 then
            local freeSlots = GetFreeBackpackSlots()
            if freeSlots ~= nil and freeSlots <= 0 then
              if Print and LI and LI.Trade and LI.Trade._debugOn == true then
                Print("Restock: no free bag slots; skipping buys.")
              end
              return ops
            end

            local buyID, idx = itemID, nil

            if r.restock == true then
              local fd = GetFoodDrinkTupleForItemID(itemID)
              local cat = fd and GetFoodDrinkCategoryKey(fd) or nil
              if cat then
                local best = GetBestMerchantFoodDrinkForCategory(cat, usesMana)
                if best and best.idx and best.itemID then
                  buyID, idx = best.itemID, best.idx
                else
                  buyID, idx = nil, nil
                end
              else
                local key = GetUseKeyForItemID(itemID)
                if key then
                  local best = GetBestMerchantItemForUseKey(key, usesMana)
                  if best and best.idx and best.itemID then
                    buyID, idx = best.itemID, best.idx
                  else
                    buyID, idx = nil, nil
                  end
                else
                  buyID, idx = nil, nil
                end
              end
            end

            if buyID and Print and r.restock == true and LI and LI.Trade and LI.Trade._debugOn == true then
              local t = GetFoodDrinkTupleForItemID(buyID)
              if type(t) == "table" and type(t.pct) == "number" then
                local reqLevel = GetItemRequiredPlayerLevel(buyID)
                if reqLevel and reqLevel > 0 then
                  Print("Best usable vendor food: " .. tostring(t.pct) .. "% (req " .. tostring(reqLevel) .. ")")
                else
                  Print("Best usable vendor food: " .. tostring(t.pct) .. "%")
                end
              end
            end

            if buyID and (not idx) then
              idx = GetMerchantIndexForItemID(buyID)
            end
            if buyID and idx and type(BuyMerchantItem) == "function" then
              local bi = GetMerchantItemBuyInfo(idx) or {}
              local name = bi.name
              local price = bi.price
              local vendorQty = tonumber(bi.quantity) or 1
              if vendorQty <= 0 then vendorQty = 1 end

              -- BuyMerchantItem's quantity parameter is the number of *items* to buy.
              -- The merchant UI may display a "xN" quantity, but addons can still request arbitrary amounts.
              local availItems = tonumber(bi.numAvailable)
              if availItems == nil or availItems < 0 then
                availItems = need
              end
              if availItems <= 0 then
                -- out of stock
              else
                local buyCount = need
                if buyCount > availItems then buyCount = availItems end

                local maxCall = tonumber(bi.maxStack) or 0
                if maxCall > 0 and buyCount > maxCall then buyCount = maxCall end

                -- Safety cap to avoid huge buys if APIs misreport.
                if buyCount > 200 then buyCount = 200 end

                local p = tonumber(price) or 0
                if p > 0 and type(GetMoney) == "function" then
                  local money = tonumber(GetMoney()) or 0
                  local maxAffordable = math.floor(money / p)
                  if maxAffordable < buyCount then buyCount = maxAffordable end
                end

                if buyCount > 0 then
                  if Print and LI and LI.Trade and LI.Trade._debugOn == true then
                    Print(
                      "Restock buy tick: idx=" .. tostring(idx) ..
                      ", id=" .. tostring(buyID) ..
                      ", target=" .. tostring(target) ..
                      ", current=" .. tostring(current) ..
                      ", need=" .. tostring(need) ..
                      ", vendorQty=" .. tostring(vendorQty) ..
                      ", buy=" .. tostring(buyCount) ..
                      ", avail=" .. tostring(availItems) ..
                      ", maxStack=" .. tostring(bi.maxStack)
                    )
                  end
                  pcall(BuyMerchantItem, idx, buyCount)
                  if type(_liMerchantBuySessionBought) == "table" then
                    local id = tonumber(buyID)
                    if id and id > 0 then
                      _liMerchantBuySessionBought[id] = (tonumber(_liMerchantBuySessionBought[id]) or 0) + buyCount
                    end
                  end
                  ops = ops + 1
                  if Print then
                    Print("Buying: " .. tostring(buyCount) .. "x " .. (name or (GetItemNameSafe(buyID) or tostring(buyID))))
                  end
                  return ops
                end
              end
            else
              if buyID and Print and LI and LI.Trade and LI.Trade._debugOn == true then
                if type(_liMerchantNotSoldWarned) ~= "table" then _liMerchantNotSoldWarned = {} end
                local warnID = tonumber(buyID) or buyID
                if _liMerchantNotSoldWarned[warnID] ~= true then
                  _liMerchantNotSoldWarned[warnID] = true
                  Print("Cannot buy (not sold by this merchant): " .. (GetItemNameSafe(buyID) or tostring(buyID)))
                end
              end
            end
          end
        end
      end
    end
    return ops
  end

  -- Sell mode
  for itemID, r in pairs(rules) do
    if ops >= maxOps then break end
    local target = r and tonumber(r.count) or 0
    if target < 0 then target = 0 end
    target = math.floor(target)

    local current = CountItemInBags(itemID)
    local toSell = current - target
    if toSell > 0 then
      local sold = 0
      IterateBagSlots(function(bag, slot)
        if ops >= maxOps then return end
        if sold >= toSell then return end
        local info = GetBagItemInfo(bag, slot)
        if not info or info.isLocked then return end
        if tonumber(info.itemID) ~= itemID then return end
        local sellPrice = GetItemSellPrice(itemID)
        if not sellPrice or sellPrice <= 0 then return end

        local stack = tonumber(info.stackCount) or 1
        UseContainerItemSafe(bag, slot)
        sold = sold + stack
        ops = ops + 1
      end)
      if Print then
        Print("Selling: " .. tostring(math.min(sold, toSell)) .. "x " .. (GetItemNameSafe(itemID) or tostring(itemID)))
      end
    end
  end
  return ops
end

local _liMerchantTicker
local _liMerchantDidFoodSell = false
local _liMerchantIdleTicks = 0

local function StopMerchantTradeTicker()
  if _liMerchantTicker and _liMerchantTicker.Cancel then
    _liMerchantTicker:Cancel()
  end
  _liMerchantTicker = nil
  _liMerchantDidFoodSell = false
  _liMerchantIdleTicks = 0
  _liMerchantBuyBaselineHave = nil
  _liMerchantBuySessionBought = nil
  _liMerchantNotSoldWarned = nil
end

local function StartMerchantTradeTicker()
  StopMerchantTradeTicker()

  _liMerchantBuyBaselineHave = {}
  _liMerchantBuySessionBought = {}
  _liMerchantNotSoldWarned = {}

  if not (C_Timer and type(C_Timer.NewTicker) == "function") then
    RunMerchantTradeOnce(false)
    return
  end

  _liMerchantTicker = C_Timer.NewTicker(0.20, function()
    local ok, err = pcall(function()
      local mf = _G and rawget(_G, "MerchantFrame")
      if not (mf and mf.IsShown and mf:IsShown()) then
        StopMerchantTradeTicker()
        return
      end

      local opsDone = RunMerchantTradeOnce(_liMerchantDidFoodSell == true)
      _liMerchantDidFoodSell = true
      opsDone = tonumber(opsDone) or 0

      if opsDone <= 0 then
        _liMerchantIdleTicks = (_liMerchantIdleTicks or 0) + 1
      else
        _liMerchantIdleTicks = 0
      end

      -- Stop after a short idle streak so we don't keep scanning needlessly.
      if (_liMerchantIdleTicks or 0) >= 6 then
        StopMerchantTradeTicker()
      end
    end)

    if not ok then
      if Print and LI and LI.Trade and LI.Trade._debugOn == true then
        Print("Merchant ticker error: " .. tostring(err))
      end
      StopMerchantTradeTicker()
    end
  end)
end

local DepositButton
local function EnsureDepositButton()
  if DepositButton then return DepositButton end

  local b = CreateFrame("Button", "fr0z3nUI_LootItDepositButton", UIParent, "UIPanelButtonTemplate")
  b:SetSize(74, 22)
  b:SetText("Deposit")
  b:Hide()
  b:SetScript("OnClick", function()
    RunDeposit(nil)
  end)

  DepositButton = b
  return b
end

local function UpdateDepositButtonVisibility()
  local b = EnsureDepositButton()
  local cfg = DepositCfgAcc()
  if not (cfg and cfg.showButton ~= false) then
    b:Hide()
    return
  end

  local wb = GetWarbankFrame()
  if wb then
    if b.ClearAllPoints and b.SetPoint then
      b:ClearAllPoints()
      b:SetPoint("TOPRIGHT", wb, "TOPLEFT", -8, -10)
    end
    b:Show()
    return
  end

  if IsGuildBankOpen() then
    local g = _G and rawget(_G, "GuildBankFrame")
    if g and b.ClearAllPoints and b.SetPoint then
      b:ClearAllPoints()
      b:SetPoint("TOPRIGHT", g, "TOPLEFT", -8, -10)
    end
    b:Show()
    return
  end
  b:Hide()
end

LI.UpdateDepositButtonVisibility = UpdateDepositButtonVisibility

local function IsMailNotifierEnabled()
  -- Tri-state:
  --   CHAR override true  -> On
  --   CHAR override false -> Off
  --   nil                 -> use account (DB.mailNotify.enabled)
  if CHARDB and CHARDB.mailNotifyEnabledOverride ~= nil then
    return (CHARDB.mailNotifyEnabledOverride == true)
  end
  return (DB and DB.mailNotify and DB.mailNotify.enabled) and true or false
end

local function MailNotifyCfg()
  EnsureDB()
  return (CHARDB and type(CHARDB.mailNotify) == "table") and CHARDB.mailNotify or nil
end

Print = function(msg)
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

    local final = (prefix ~= "") and (prefix .. text) or text
    local lootChat = LI and LI.LootChat
    if lootChat and lootChat.CaptureEnabled and lootChat.CaptureEnabled() then
      local e = {
        msg = final,
        raw = text,
        prefix = prefix,
        outputChatFrame = (DB and DB.outputChatFrame) or nil,
      }
      if (DB and DB.debugCaptureStacks) and type(debugstack) == "function" then
        e.stack = debugstack(2, 10, 10)
      end
      if lootChat.CaptureAppend then
        lootChat.CaptureAppend("PRINT", e)
      end
    end

    frame:AddMessage(final)
  end
end

LI.Print = Print

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
    local text = tostring(msg or "")
    local lootChat = LI and LI.LootChat
    if lootChat and lootChat.CaptureEnabled and lootChat.CaptureEnabled() then
      local e = {
        msg = text,
        outputChatFrame = tonumber(chatFrameID) or nil,
      }
      if (DB and DB.debugCaptureStacks) and type(debugstack) == "function" then
        e.stack = debugstack(2, 10, 10)
      end
      if lootChat.CaptureAppend then
        lootChat.CaptureAppend("PRINT", e)
      end
    end
    frame:AddMessage(text)
  end
end

local function SetCheckBoxText(cb, text)
  if not cb then return end
  local label = cb.Text or (cb.GetName and cb:GetName() and _G[cb:GetName() .. "Text"]) or cb.text
  if label and label.SetText then
    label:SetText(text)
  end
end

LI.SetCheckBoxText = SetCheckBoxText

local function SetCheckBoxChecked(cb, checked)
  if cb and cb.SetChecked then
    cb:SetChecked(checked and true or false)
  end
end

LI.SetCheckBoxChecked = SetCheckBoxChecked

local function GetLootChatModule()
  return LI and LI.LootChat
end

do
  local lootChat = GetLootChatModule()
  if lootChat and type(lootChat.SetEnv) == "function" then
    lootChat.SetEnv({
      EnsureDB = EnsureDB,
      GetDB = function() return DB end,
      GetCharDB = function() return CHARDB end,
      IsEnabled = IsEnabled,
      IsIgnoredItemID = IsIgnoredItemID,
      IsItemLevelEnabled = IsItemLevelEnabled,
      ADDON_LINK_ALIASES = ADDON_LINK_ALIASES,
      ADDON_CURRENCY_ALIASES = ADDON_CURRENCY_ALIASES,
      DEFAULTS = DEFAULTS,
      Print = Print,
      PrintToChatFrame = PrintToChatFrame,
    })
  end
end

local function CaptureAppend(kind, data)
  local lootChat = GetLootChatModule()
  if lootChat and lootChat.CaptureAppend then
    return lootChat.CaptureAppend(kind, data)
  end
end

local function LootCombineEnabled()
  local lootChat = GetLootChatModule()
  return (lootChat and lootChat.LootCombineEnabled and lootChat.LootCombineEnabled()) and true or false
end

local function LootCombineFlush()
  local lootChat = GetLootChatModule()
  if lootChat and lootChat.LootCombineFlush then
    return lootChat.LootCombineFlush()
  end
end

local function LootCombineCancelTimers()
  local lootChat = GetLootChatModule()
  if lootChat and lootChat.LootCombineCancelTimers then
    return lootChat.LootCombineCancelTimers()
  end
end

local function LootCombineWindowStart()
  local lootChat = GetLootChatModule()
  if lootChat and lootChat.LootCombineWindowStart then
    return lootChat.LootCombineWindowStart()
  end
end

local function LootCombineWindowEnd()
  local lootChat = GetLootChatModule()
  if lootChat and lootChat.LootCombineWindowEnd then
    return lootChat.LootCombineWindowEnd()
  end
end

local function DelayPrintFlushAll()
  local lootChat = GetLootChatModule()
  if lootChat and lootChat.DelayPrintFlushAll then
    return lootChat.DelayPrintFlushAll()
  end
end

local function ApplyFilters()
  local lootChat = GetLootChatModule()
  if lootChat and lootChat.ApplyFilters then
    return lootChat.ApplyFilters()
  end
end

local function ApplyFiltersSoon(delaySeconds)
  local lootChat = GetLootChatModule()
  if lootChat and lootChat.ApplyFiltersSoon then
    return lootChat.ApplyFiltersSoon(delaySeconds)
  end
end

local function GetSupportedMessageLines()
  local lootChat = GetLootChatModule()
  if lootChat and lootChat.GetSupportedMessageLines then
    return lootChat.GetSupportedMessageLines()
  end
  return {}
end

-- UI (config window shell) moved to fr0z3nUI_LootItUI.lua

-- Forward declarations (modules/CLI reference these)
local CreateMailNotifier
local UpdateMailNotifier
local ApplyMailModelToFrame
local ApplyMailNotifierInteractivity
local ModelGetRotation
local ModelSetRotation
local ModelApplyZoom
local ModelApplyAnimation

local function IsMailEditorOpen()
  local ui = LI and LI.UI
  if ui and ui.IsMailEditorOpen then
    return ui.IsMailEditorOpen() and true or false
  end
  return false
end

local function CreateConfigUI()
  local ui = LI and LI.UI
  if ui and ui.CreateConfigUI then
    return ui.CreateConfigUI()
  end
  return nil
end

local function ToggleConfigUI()
  local ui = LI and LI.UI
  if ui and ui.ToggleConfigUI then
    return ui.ToggleConfigUI()
  end
end

do
  local ui = LI and LI.UI
  if ui and type(ui.SetEnv) == "function" then
    ui.SetEnv({
      EnsureDB = EnsureDB,
      GetDB = function() return DB end,
      GetCharDB = function() return CHARDB end,
      ApplyFilters = ApplyFilters,
      LootCombineCancelTimers = LootCombineCancelTimers,
      LootCombineFlush = LootCombineFlush,
      SetCheckBoxText = SetCheckBoxText,
      SetCheckBoxChecked = SetCheckBoxChecked,
      GetSupportedMessageLines = GetSupportedMessageLines,
      MailNotifyCfg = MailNotifyCfg,
      Clamp = Clamp,
      Print = Print,
      ApplyMailNotifierInteractivity = (LI and LI.Mail and LI.Mail.ApplyMailNotifierInteractivity) or nil,
      CreateMailNotifier = (LI and LI.Mail and LI.Mail.CreateMailNotifier) or nil,
      UpdateMailNotifier = (LI and LI.Mail and LI.Mail.UpdateMailNotifier) or nil,
      ApplyMailModelToFrame = (LI and LI.Mail and LI.Mail.ApplyMailModelToFrame) or nil,
      ModelApplyAnimation = (LI and LI.Mail and LI.Mail.ModelApplyAnimation) or nil,
      ModelGetRotation = (LI and LI.Mail and LI.Mail.ModelGetRotation) or nil,
      ModelSetRotation = (LI and LI.Mail and LI.Mail.ModelSetRotation) or nil,
      ModelApplyZoom = (LI and LI.Mail and LI.Mail.ModelApplyZoom) or nil,
      GetMailNotifier = (LI and LI.Mail and LI.Mail.GetMailNotifier) or nil,
    })
  end
end

do
  local mail = LI and LI.Mail
  if mail and type(mail.SetNotifierEnv) == "function" then
    mail.SetNotifierEnv({
      EnsureDB = EnsureDB,
      MailNotifyCfg = MailNotifyCfg,
      IsMailNotifierEnabled = IsMailNotifierEnabled,
      IsMailEditorOpen = IsMailEditorOpen,
      ToggleConfigUI = ToggleConfigUI,
      Clamp = Clamp,
      Print = Print,
    })

    ApplyMailNotifierInteractivity = mail.ApplyMailNotifierInteractivity
    ModelGetRotation = mail.ModelGetRotation
    ModelSetRotation = mail.ModelSetRotation
    ModelApplyZoom = mail.ModelApplyZoom
    ModelApplyAnimation = mail.ModelApplyAnimation
    ApplyMailModelToFrame = mail.ApplyMailModelToFrame
    CreateMailNotifier = mail.CreateMailNotifier
    UpdateMailNotifier = mail.UpdateMailNotifier
  end
end

SLASH_FR0Z3NUI_LOOTIT1 = "/fli"
SLASH_FR0Z3NUI_LOOTIT2 = "/lootit"

do
  local uiv = LI and LI.UIV
  if uiv and type(uiv.SetEnv) == "function" then
    uiv.SetEnv({
      EnsureDB = EnsureDB,
      GetDB = function() return DB end,
      GetCharDB = function() return CHARDB end,
      SANITY_VERSION = SANITY_VERSION,
      IsEnabled = IsEnabled,
      ToggleConfigUI = ToggleConfigUI,
      CreateConfigUI = CreateConfigUI,
      RunDeposit = RunDeposit,
      ApplyFilters = ApplyFilters,
      LootCombineEnabled = LootCombineEnabled,
      CaptureAppend = CaptureAppend,
      Print = Print,
      PREFIX = PREFIX,
      MailNotifyCfg = MailNotifyCfg,
      UpdateMailNotifier = UpdateMailNotifier,
      CreateMailNotifier = CreateMailNotifier,
      ApplyMailModelToFrame = ApplyMailModelToFrame,
      DebugSellOldFoodAtMerchant = DebugSellOldFoodAtMerchant,
    })
  end
end

---@diagnostic disable-next-line: duplicate-set-field
SlashCmdList.FR0Z3NUI_LOOTIT = function(msg)
  local uiv = LI and LI.UIV
  if uiv and type(uiv.Handle) == "function" then
    return uiv.Handle(msg)
  end

  EnsureDB()
  Print("LootIt slash handler not available.")
end

local function SafeUpdateMailNotifier()
  if type(UpdateMailNotifier) ~= "function" then return end
  pcall(UpdateMailNotifier)
end

local _mailNotifierBootstrapTicker
local function BootstrapMailNotifier()
  -- Mail state can arrive a bit after login; do a short refresh loop so the
  -- notifier appears without needing to open the /fli UI.
  if not (C_Timer and C_Timer.NewTicker and C_Timer.After) then
    SafeUpdateMailNotifier()
    return
  end

  -- If a bootstrap loop is already running, just force an update now.
  if _mailNotifierBootstrapTicker then
    SafeUpdateMailNotifier()
    return
  end

  local tries = 0
  local maxTries = 18 -- ~20-25s depending on ticker interval
  local interval = 1.25

  local function Tick()
    tries = tries + 1
    SafeUpdateMailNotifier()

    local stop = (tries >= maxTries)
    if not stop then
      local has = (HasNewMail and HasNewMail()) and true or false
      if has then
        local mn = (LI and LI.Mail and LI.Mail.GetMailNotifier and LI.Mail.GetMailNotifier()) or nil
        if mn and mn.IsShown and mn:IsShown() then
          stop = true
        end
      end
    end

    if stop and _mailNotifierBootstrapTicker and _mailNotifierBootstrapTicker.Cancel then
      _mailNotifierBootstrapTicker:Cancel()
      _mailNotifierBootstrapTicker = nil
    end
  end

  Tick()
  C_Timer.After(0.75, Tick)
  _mailNotifierBootstrapTicker = C_Timer.NewTicker(interval, Tick, maxTries)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_GUILD_UPDATE")
f:RegisterEvent("CHAT_MSG_MONEY")
f:RegisterEvent("CHAT_MSG_SYSTEM")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("MERCHANT_CLOSED")
f:RegisterEvent("UPDATE_PENDING_MAIL")
f:RegisterEvent("MAIL_INBOX_UPDATE")
f:RegisterEvent("GUILDBANKFRAME_OPENED")
f:RegisterEvent("GUILDBANKFRAME_CLOSED")
f:RegisterEvent("BANKFRAME_OPENED")
f:RegisterEvent("BANKFRAME_CLOSED")
f:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
f:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("LOOT_OPENED")
f:RegisterEvent("LOOT_CLOSED")
f:RegisterEvent("LOOT_READY")
f:SetScript("OnEvent", function(_, event, arg1)
  EnsureDB()
  if event == "PLAYER_LOGIN" then
    UpdateSeenGuilds()
    do
      local tax = LI and LI.Tax
      if tax and tax.Init then
        tax.Init(DB, CHARDB, { Print = Print })
      end
    end
    ApplyFilters()
    ApplyFiltersSoon(1)
    BootstrapMailNotifier()
    if UpdateDepositButtonVisibility then
      C_Timer.After(0.25, UpdateDepositButtonVisibility)
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    UpdateSeenGuilds()
    ApplyFiltersSoon(0.5)
    BootstrapMailNotifier()
    if UpdateDepositButtonVisibility then
      C_Timer.After(0.25, UpdateDepositButtonVisibility)
    end
  elseif event == "PLAYER_GUILD_UPDATE" then
    UpdateSeenGuilds()
  elseif event == "CHAT_MSG_MONEY" or event == "CHAT_MSG_SYSTEM" then
    local tax = LI and LI.Tax
    if tax and tax.OnMoneyMessage then
      tax.OnMoneyMessage(event, arg1)
    end
  elseif event == "MERCHANT_SHOW" then
    StartMerchantTradeTicker()
    local tax = LI and LI.Tax
    if tax and tax.OnMerchantShow then
      tax.OnMerchantShow()
    end
  elseif event == "MERCHANT_CLOSED" then
    StopMerchantTradeTicker()
    if DB and DB.delayPrint and DB.delayPrint.flushOnMerchantClose then
      DelayPrintFlushAll()
    end
    local tax = LI and LI.Tax
    if tax and tax.OnMerchantClosed then
      tax.OnMerchantClosed()
    end
  elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
    local it = (Enum and Enum.PlayerInteractionType) and Enum.PlayerInteractionType or nil
    local isShow = (event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    local isBanker = (it and it.Banker and arg1 == it.Banker) and true or false
    local isAccountBanker = (it and it.AccountBanker and arg1 == it.AccountBanker) and true or false
    local isGuildBanker = (it and it.GuildBanker and arg1 == it.GuildBanker) and true or false
    do
      local tax = LI and LI.Tax
      if tax and tax.OnInteraction then
        tax.OnInteraction(isShow, arg1)
      end
    end
    if isBanker then
      _bankInteractionOpen = isShow
    elseif isAccountBanker then
      _warbankInteractionOpen = isShow
    elseif isGuildBanker then
      _guildbankInteractionOpen = isShow
      if isShow and ResetGuildBankQuerySession then
        ResetGuildBankQuerySession()
      end
    end
    if (isBanker or isAccountBanker or isGuildBanker) and UpdateDepositButtonVisibility then
      UpdateDepositButtonVisibility()
    end
  elseif event == "GUILDBANKFRAME_OPENED" or event == "GUILDBANKFRAME_CLOSED" or event == "BANKFRAME_OPENED" or event == "BANKFRAME_CLOSED" then
    if event == "GUILDBANKFRAME_OPENED" and ResetGuildBankQuerySession then
      ResetGuildBankQuerySession()
    end
    if event == "GUILDBANKFRAME_CLOSED" and ResetGuildBankQuerySession then
      ResetGuildBankQuerySession()
    end
    if UpdateDepositButtonVisibility then
      UpdateDepositButtonVisibility()
    end
  elseif event == "UPDATE_PENDING_MAIL" then
    BootstrapMailNotifier()
  elseif event == "MAIL_INBOX_UPDATE" then
    -- Extra safety: some clients update HasNewMail/UI state later than UPDATE_PENDING_MAIL.
    BootstrapMailNotifier()
  elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    SafeUpdateMailNotifier()
  elseif event == "LOOT_OPENED" or event == "LOOT_READY" then
    -- Other addons can remove chat filters at runtime; re-apply here so loot lines are still rewritten.
    ApplyFilters()
    LootCombineWindowStart()
  elseif event == "LOOT_CLOSED" then
    LootCombineWindowEnd()
  end
end)
