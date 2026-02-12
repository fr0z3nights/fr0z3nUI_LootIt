local ADDON = ...

local PREFIX = "|cff00ccff[LI]|r "

local LI = fr0z3nUI_LootIt or {}
fr0z3nUI_LootIt = LI
LI.PREFIX = PREFIX

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

  -- Loot-output styling: suppress tabard iLvl suffix below this iLvl (0 disables).
  ignoreTabardLootBelowIlvl = 10,
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

  tabard = {
    enabled = true,
    delay = 0.75,
    hideRepBarWhenNoChampion = false,
    modeByContext = {
      solo = "nochange",
      city = "closest",
      dungeon = "closest",
      raid = "nochange",
      pvp = "nochange",
    },
    tabardMap = {},
  },

  -- Deposit helper (bank open + command/button pressed).
  deposit = {
    tradeMode = "deposit", -- deposit | buy | sell
    target = "bank", -- bank | guild | warbank
    guildTab = 0, -- legacy fallback; 0=current tab; 1..8 specific tab
    guildTabByRealm = {}, -- [realm] = 0..8
    showButton = true,
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
  if DB.deposit.target == nil then DB.deposit.target = "bank" end
  if DB.deposit.guildTab == nil then DB.deposit.guildTab = 0 end
  if DB.deposit.showButton == nil then DB.deposit.showButton = true end

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
  DB.deposit.itemsAcc = (type(DB.deposit.itemsAcc) == "table") and DB.deposit.itemsAcc or {}
  DB.deposit.itemsRealm = (type(DB.deposit.itemsRealm) == "table") and DB.deposit.itemsRealm or {}
  DB.deposit.guildTabByRealm = (type(DB.deposit.guildTabByRealm) == "table") and DB.deposit.guildTabByRealm or {}
  DB.deposit.buyItemsAcc = (type(DB.deposit.buyItemsAcc) == "table") and DB.deposit.buyItemsAcc or {}
  DB.deposit.buyItemsRealm = (type(DB.deposit.buyItemsRealm) == "table") and DB.deposit.buyItemsRealm or {}
  DB.deposit.sellItemsAcc = (type(DB.deposit.sellItemsAcc) == "table") and DB.deposit.sellItemsAcc or {}
  DB.deposit.sellItemsRealm = (type(DB.deposit.sellItemsRealm) == "table") and DB.deposit.sellItemsRealm or {}
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
  CHARDB.deposit.disableAcc = (type(CHARDB.deposit.disableAcc) == "table") and CHARDB.deposit.disableAcc or {}
  CHARDB.deposit.buyItemsChar = (type(CHARDB.deposit.buyItemsChar) == "table") and CHARDB.deposit.buyItemsChar or {}
  CHARDB.deposit.buyDisableAcc = (type(CHARDB.deposit.buyDisableAcc) == "table") and CHARDB.deposit.buyDisableAcc or {}
  CHARDB.deposit.sellItemsChar = (type(CHARDB.deposit.sellItemsChar) == "table") and CHARDB.deposit.sellItemsChar or {}
  CHARDB.deposit.sellDisableAcc = (type(CHARDB.deposit.sellDisableAcc) == "table") and CHARDB.deposit.sellDisableAcc or {}
  return CHARDB.deposit
end

LI.DepositCfgChar = DepositCfgChar

local function GetEffectiveDepositItemIDs()
  local acc = DepositCfgAcc()
  local ch = DepositCfgChar()
  local out = {}
  for id, on in pairs(acc.itemsAcc or {}) do
    id = tonumber(id)
    if id and id > 0 and on == true and not (ch.disableAcc and ch.disableAcc[id] == true) then
      out[id] = true
    end
  end
  for id, on in pairs(ch.itemsChar or {}) do
    id = tonumber(id)
    if id and id > 0 and on == true then
      out[id] = true
    end
  end

  do
    local realmItems = nil
    realmItems = (type(acc.itemsRealm) == "table") and acc.itemsRealm[GetCurrentRealmKey()] or nil
    if type(realmItems) == "table" then
      for id, on in pairs(realmItems) do
        id = tonumber(id)
        if id and id > 0 and on == true then
          out[id] = true
        end
      end
    end
  end
  return out
end

local function IsGuildBankOpen()
  local f = _G and rawget(_G, "GuildBankFrame")
  if f and f.IsShown and f:IsShown() then
    return true
  end
  return false
end

local _warbankInteractionOpen = false

local function GetWarbankFrame()
  local candidates = {
    "AccountBankFrame",
    "AccountBankPanel",
    "BankFrame",
    "WarbandBankFrame",
    "WarbandBankPanel",
    "WarbandBank",
  }
  for _, k in ipairs(candidates) do
    local f = _G and rawget(_G, k)
    if f and f.IsShown and f:IsShown() then
      return f
    end
  end
  return nil
end

local function IsWarbankOpen()
  if _warbankInteractionOpen == true then
    return true
  end
  return (GetWarbankFrame() ~= nil)
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

local function FindFirstEmptyGuildBankSlot(tab)
  tab = tonumber(tab)
  if not tab or tab <= 0 then return nil end
  local maxSlots = _G and rawget(_G, "MAX_GUILDBANK_SLOTS_PER_TAB")
  maxSlots = tonumber(maxSlots) or 98
  if type(GetGuildBankItemLink) ~= "function" then
    return nil
  end
  for slot = 1, maxSlots do
    local ok, link = pcall(GetGuildBankItemLink, tab, slot)
    if ok and not link then
      return slot
    end
  end
  return nil
end

local function DepositToGuildBankOnce(bag, slot, tab, bankSlot)
  if not (C_Container and type(C_Container.PickupContainerItem) == "function") then
    return false
  end
  if type(PickupGuildBankItem) ~= "function" then
    return false
  end

  local clear = _G and rawget(_G, "ClearCursor")
  local cursorHas = _G and rawget(_G, "CursorHasItem")

  if type(clear) == "function" then pcall(clear) end

  local okPick = pcall(C_Container.PickupContainerItem, bag, slot)
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

  local okDrop = pcall(PickupGuildBankItem, tab, bankSlot)
  if not okDrop then
    if type(clear) == "function" then pcall(clear) end
    return false
  end
  if type(clear) == "function" then pcall(clear) end
  return true
end

local function RunDepositGuild()
  if not IsGuildBankOpen() then
    Print("Guild bank is not open.")
    return false
  end

  local targets = GetEffectiveDepositItemIDs()
  local hasAny = false
  for _ in pairs(targets) do hasAny = true break end
  if not hasAny then
    Print("Deposit list is empty.")
    return false
  end

  local tab = GetConfiguredGuildBankTab()
  local moved = 0
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
          local bankSlot = FindFirstEmptyGuildBankSlot(tab)
          if not bankSlot then
            Print("Guild bank tab is full.")
            return moved > 0
          end
          local okMove = DepositToGuildBankOnce(bag, slot, tab, bankSlot)
          if okMove then
            moved = moved + 1
          else
            Print("Deposit blocked; try clicking Deposit again.")
            return moved > 0
          end
        end
      end
    end
    if moved >= maxMoves then break end
  end

  if moved > 0 then
    Print("Deposited: " .. tostring(moved) .. " move(s)")
    return true
  end
  Print("No matching items found in bags.")
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

local function CreateItemLocationFromBagSlot(bag, slot)
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

local function DepositToWarbankOnce(bag, slot)
  local f, fnName = GetWarbankDepositCallable()
  if type(f) ~= "function" then
    return false, "No deposit API"
  end

  -- Try common signatures (API differs by build).
  local loc = CreateItemLocationFromBagSlot(bag, slot)
  local bankTypeAccount = (Enum and Enum.BankType) and Enum.BankType.Account or nil

  local function tryCall(...)
    local ok, res = pcall(f, ...)
    if ok and res ~= false then
      return true
    end
    return false
  end

  if bankTypeAccount ~= nil then
    if tryCall(bankTypeAccount, bag, slot) then return true end
    if loc ~= nil and tryCall(bankTypeAccount, loc) then return true end
  end

  if tryCall(bag, slot) then return true end
  if loc ~= nil and tryCall(loc) then return true end

  return false, tostring(fnName or "deposit")
end

local function RunDepositWarband()
  if not IsWarbankOpen() then
    Print("WarBank is not open.")
    return false
  end

  local targets = GetEffectiveDepositItemIDs()
  local hasAny = false
  for _ in pairs(targets) do hasAny = true break end
  if not hasAny then
    Print("Deposit list is empty.")
    return false
  end

  local moved = 0
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
          local okMove = DepositToWarbankOnce(bag, slot)
          if okMove then
            moved = moved + 1
          else
            Print("Deposit blocked; try clicking Deposit again.")
            return moved > 0
          end
        end
      end
    end
    if moved >= maxMoves then break end
  end

  if moved > 0 then
    Print("Deposited: " .. tostring(moved) .. " move(s)")
    return true
  end
  Print("No matching items found in bags.")
  return false
end

local function RunDeposit(target)
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
    local cfg = DepositCfgAcc()
    target = Normalize(cfg.target)
    if target == "" then target = "bank" end
  end

  if target == "guild" then
    return RunDepositGuild()
  elseif target == "warbank" then
    return RunDepositWarband()
  else
    -- Bank: whichever bank is currently open.
    if IsWarbankOpen() then
      return RunDepositWarband()
    end
    if IsGuildBankOpen() then
      return RunDepositGuild()
    end
    Print("No bank is open.")
    return false
  end
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
  local accTbl, realmTbl, _, charTbl, disableAccTbl = GetScopeStores(mode)
  local out = {}

  local function setFrom(tbl, isAccount)
    if type(tbl) ~= "table" then return end
    for id, v in pairs(tbl) do
      id = tonumber(id)
      if id and id > 0 then
        if isAccount and type(disableAccTbl) == "table" and disableAccTbl[id] == true then
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
  setFrom(accTbl, true)
  setFrom(realmTbl, false)
  setFrom(charTbl, false)
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

local function NormalizeUseText(s)
  if type(s) ~= "string" then return nil end
  local t = s:lower()
  t = t:gsub("^use:%s*", "")
  t = t:gsub("%d+", "")
  t = t:gsub("[%p%c]", " ")
  t = t:gsub("%s+", " ")
  t = t:gsub("^%s+", "")
  t = t:gsub("%s+$", "")
  if t == "" then return nil end
  return t
end

local function GetUseKeyForItemID(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return nil end

  local useLines = {}
  local hasMana = false

  if C_TooltipInfo and type(C_TooltipInfo.GetHyperlink) == "function" then
    local ok, tip = pcall(C_TooltipInfo.GetHyperlink, "item:" .. tostring(itemID))
    if ok and type(tip) == "table" and type(tip.lines) == "table" then
      for _, line in ipairs(tip.lines) do
        local left = (type(line) == "table") and line.leftText or nil
        if type(left) == "string" and left:find("^Use:", 1) then
          local norm = NormalizeUseText(left)
          if norm then
            useLines[#useLines + 1] = norm
            if norm:find("mana", 1, true) then hasMana = true end
          end
        end
      end
    end
  end

  if #useLines == 0 then
    return nil
  end
  return table.concat(useLines, " ") .. "|mana:" .. (hasMana and "1" or "0")
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

local function IsFoodItemID(itemID)
  if not (C_Item and type(C_Item.GetItemInfoInstant) == "function") then return false end
  local ok, _, _, _, _, classID, subClassID = pcall(C_Item.GetItemInfoInstant, itemID)
  if not ok then return false end
  return (tonumber(classID) == 0) and (tonumber(subClassID) == 5)
end

local function GetItemMinLevel(itemID)
  itemID = tonumber(itemID)
  if not itemID then return nil end
  if type(GetItemInfo) == "function" then
    local _, _, _, _, reqLevel = GetItemInfo(itemID)
    reqLevel = tonumber(reqLevel)
    return reqLevel
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

local function SellOldFoodAtMerchant(levelDiff)
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
    local req = GetItemMinLevel(itemID)
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
      Print("Sold old food: " .. (GetItemNameSafe(id) or tostring(id)) .. " x" .. tostring(cnt))
    end
  end
end

local function RunMerchantTradeOnce()
  local mode = GetTradeMode()
  if mode ~= "buy" and mode ~= "sell" then return end

  local rules = GetEffectiveTradeRules(mode)
  if type(rules) ~= "table" then return end

  local any = false
  local anyRestock = false
  for _, r in pairs(rules) do
    any = true
    if r and r.restock == true then anyRestock = true end
  end
  if not any then return end

  if mode == "buy" and anyRestock then
    SellOldFoodAtMerchant(10)
  end

  local usesMana = PlayerUsesMana()
  local ops = 0
  local maxOps = 200

  if mode == "buy" then
    for itemID, r in pairs(rules) do
      if ops >= maxOps then break end
      local target = r and tonumber(r.count) or nil
      if target and target > 0 then
        local current = 0
        if r.restock == true then
          local key = GetUseKeyForItemID(itemID)
          if key then
            local hasMana = (key:sub(-7) == "|mana:1")
            if (not usesMana) and hasMana then
              -- Non-mana classes: treat mana food as a different pool; do not restock it implicitly.
              current = CountItemInBags(itemID)
            else
              current = CountEquivalentByUseKeyInBags(key)
            end
          else
            current = CountItemInBags(itemID)
          end
        else
          current = CountItemInBags(itemID)
        end

        local need = target - current
        if need > 0 then
          local idx = GetMerchantIndexForItemID(itemID)
          if idx and type(BuyMerchantItem) == "function" then
            local name, _, _, _, numAvailable = nil, nil, nil, nil, nil
            if type(GetMerchantItemInfo) == "function" then
              name, _, _, _, numAvailable = GetMerchantItemInfo(idx)
            end
            local avail = tonumber(numAvailable)
            if avail == nil or avail < 0 then avail = need end
            if avail <= 0 then
              -- out of stock
            else
              local buyCount = need
              if buyCount > avail then buyCount = avail end
              if buyCount > 0 then
                pcall(BuyMerchantItem, idx, buyCount)
                ops = ops + 1
                if Print then
                  Print("Buying: " .. tostring(buyCount) .. "x " .. (name or (GetItemNameSafe(itemID) or tostring(itemID))))
                end
              end
            end
          else
            if Print then
              Print("Cannot buy (not sold by this merchant): " .. (GetItemNameSafe(itemID) or tostring(itemID)))
            end
          end
        end
      end
    end
    return
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

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("MERCHANT_CLOSED")
f:RegisterEvent("UPDATE_PENDING_MAIL")
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
    do
      local tabard = _G and rawget(_G, "fr0z3nUI_LootItTabard")
      if tabard and tabard.Init then
        tabard.Init(DB, CHARDB)
      end
    end
    ApplyFilters()
    ApplyFiltersSoon(1)
    C_Timer.After(1, UpdateMailNotifier)
    if UpdateDepositButtonVisibility then
      C_Timer.After(0.25, UpdateDepositButtonVisibility)
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    ApplyFiltersSoon(0.5)
    C_Timer.After(1, UpdateMailNotifier)
    if UpdateDepositButtonVisibility then
      C_Timer.After(0.25, UpdateDepositButtonVisibility)
    end
  elseif event == "MERCHANT_SHOW" then
    RunMerchantTradeOnce()
  elseif event == "MERCHANT_CLOSED" then
    if DB and DB.delayPrint and DB.delayPrint.flushOnMerchantClose then
      DelayPrintFlushAll()
    end
  elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
    local it = (Enum and Enum.PlayerInteractionType) and Enum.PlayerInteractionType or nil
    local isAccountBanker = (it and it.AccountBanker and arg1 == it.AccountBanker) and true or false
    if isAccountBanker then
      _warbankInteractionOpen = (event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
      if UpdateDepositButtonVisibility then
        UpdateDepositButtonVisibility()
      end
    end
  elseif event == "GUILDBANKFRAME_OPENED" or event == "GUILDBANKFRAME_CLOSED" or event == "BANKFRAME_OPENED" or event == "BANKFRAME_CLOSED" then
    if UpdateDepositButtonVisibility then
      UpdateDepositButtonVisibility()
    end
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
