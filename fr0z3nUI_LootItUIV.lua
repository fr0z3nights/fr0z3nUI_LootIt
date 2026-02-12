---@diagnostic disable: undefined-global

local LI = fr0z3nUI_LootIt or {}
fr0z3nUI_LootIt = LI

LI.UIV = LI.UIV or {}
local UIV = LI.UIV

local env

function UIV.SetEnv(e)
  env = e or {}
end

local function SafeCall(fn, ...)
  if type(fn) == "function" then
    return fn(...)
  end
end

function UIV.Handle(msg)
  local e = env or {}
  SafeCall(e.EnsureDB)

  local DB = SafeCall(e.GetDB)
  local CHARDB = SafeCall(e.GetCharDB)

  local Print = e.Print
  local ToggleConfigUI = e.ToggleConfigUI
  local CreateConfigUI = e.CreateConfigUI
  local RunDeposit = e.RunDeposit
  local ApplyFilters = e.ApplyFilters
  local LootCombineEnabled = e.LootCombineEnabled
  local IsEnabled = e.IsEnabled
  local CaptureAppend = e.CaptureAppend

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
    local enabledNow = (type(IsEnabled) == "function" and IsEnabled()) and "on" or "off"
    local hideNow = (DB and DB.hideLootText) and "on" or "off"
    local echoNow = (DB and DB.echoItem) and "on" or "off"
    SafeCall(Print, string.format("enabled=%s (%s), hide=%s, echo=%s", enabledNow, (mode == "acc") and "acc" or "char", hideNow, echoNow))
  end

  if cmd == "" then
    SafeCall(ToggleConfigUI)
    return
  end

  if cmd == "?" or cmd == "help" then
    SafeCall(Print, "/fli - open options")
    SafeCall(Print, "/fli on|off|toggle")
    SafeCall(Print, "/fli deposit")
    SafeCall(Print, "/fli hide on|off")
    SafeCall(Print, "/fli echo on|off")
    SafeCall(Print, "/fli selfname on|off")
    SafeCall(Print, "/fli prefix <text>|default (leave blank to clear)")
    SafeCall(Print, "/fli ignore <itemID>")
    SafeCall(Print, "/fli tabard swap")
    SafeCall(Print, "/fli tabard debug")
    SafeCall(Print, "/fli mail on|off|toggle|test")
    SafeCall(Print, "/fli mail model player")
    SafeCall(Print, "/fli mail model katy")
    SafeCall(Print, "/fli mail model dalaran")
    SafeCall(Print, "/fli mail model plagued")
    SafeCall(Print, "/fli mail model npc <id>")
    SafeCall(Print, "/fli mail model display <id>")
    SafeCall(Print, "/fli mail model file <id>")
    SafeCall(Print, "/fli alias set [acc|char] <itemID> <text>")
    SafeCall(Print, "/fli alias del [acc|char] <itemID>")
    SafeCall(Print, "/fli alias list")
    SafeCall(Print, "/fli capture on|off|status|dump|clear|max|stacks")
    SafeCall(Print, "/fli status")
    return
  end

  if cmd == "deposit" then
    -- Macro friendly: only does something when bank UI is open.
    SafeCall(RunDeposit, nil)
    return
  end

  if cmd == "ignore" then
    local id = tonumber((rest or ""):match("(%d+)"))
    if not id or id <= 0 then
      local n = 0
      if DB and type(DB.ignoredItemIDs) == "table" then
        for _ in pairs(DB.ignoredItemIDs) do n = n + 1 end
      end
      SafeCall(Print, "Usage: /fli ignore <itemID>")
      SafeCall(Print, "Ignored items: " .. tostring(n))
      return
    end

    DB.ignoredItemIDs = (type(DB.ignoredItemIDs) == "table") and DB.ignoredItemIDs or {}
    local on = not (DB.ignoredItemIDs[id] == true)
    DB.ignoredItemIDs[id] = on and true or nil
    SafeCall(Print, string.format("Ignore %s: %d", on and "enabled" or "disabled", id))
    return
  end

  if cmd == "tabard" then
    local sub = tostring(rest or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local tabard = _G and rawget(_G, "fr0z3nUI_LootItTabard")
    if sub == "" or sub == "help" or sub == "?" then
      SafeCall(Print, "Tabard commands:")
      SafeCall(Print, "  /fli tabard swap")
      SafeCall(Print, "  /fli tabard debug")
      return
    end

    if not (tabard and (tabard.MaybeSwap or tabard.Debug)) then
      SafeCall(Print, "Tabard module not loaded.")
      return
    end

    if sub == "swap" then
      if tabard.MaybeSwap then tabard.MaybeSwap("cmd") end
      return
    end
    if sub == "debug" then
      if tabard.Debug then tabard.Debug() end
      return
    end

    SafeCall(Print, "Unknown tabard command. Try: /fli tabard help")
    return
  end

  if cmd == "capture" or cmd == "cap" then
    local parts = {}
    for w in tostring(rest or ""):gmatch("%S+") do
      parts[#parts + 1] = w
    end
    local sub = (parts[1] and parts[1]:lower()) or "status"

    if sub == "on" then
      DB.debugCapture = true
      -- Force a first entry so users can verify capture is working immediately.
      SafeCall(CaptureAppend, "CAPTURE", { event = "manual_on", msg = "Capture enabled" })
      SafeCall(Print, "Capture: on")
      return
    end
    if sub == "off" then
      DB.debugCapture = false
      SafeCall(Print, "Capture: off")
      return
    end
    if sub == "stacks" then
      DB.debugCaptureStacks = not (DB and DB.debugCaptureStacks)
      SafeCall(Print, "Capture stacks: " .. ((DB.debugCaptureStacks and "on") or "off"))
      return
    end
    if sub == "max" then
      local n = tonumber(parts[2])
      if not n then
        SafeCall(Print, "Capture max: " .. tostring(DB.debugCaptureMax or 200))
        return
      end
      if n < 20 then n = 20 end
      if n > 500 then n = 500 end
      DB.debugCaptureMax = n
      SafeCall(Print, "Capture max set: " .. n)
      return
    end
    if sub == "clear" then
      if CHARDB then
        CHARDB.debugCaptureLog = {}
      end
      SafeCall(Print, "Capture: cleared")
      return
    end
    if sub == "dump" then
      if not (DB and DB.debugCapture) then
        SafeCall(Print, "Capture is OFF. Run: /fli capture on")
      end
      local n = tonumber(parts[2]) or 30
      if n < 1 then n = 1 end
      if n > 200 then n = 200 end
      local filter = table.concat(parts, " ", 3)
      filter = (type(filter) == "string") and filter:lower() or ""

      local log = (CHARDB and type(CHARDB.debugCaptureLog) == "table") and CHARDB.debugCaptureLog or {}
      SafeCall(Print, string.format("Capture dump: %d entries (showing last %d)", #log, n))
      if #log == 0 then
        SafeCall(Print, "(No entries yet. Make sure you ran /fli capture on, then loot something or run /fli status.)")
      end
      local start = #log - n + 1
      if start < 1 then start = 1 end
      for i = start, #log do
        local entry = log[i]
        if type(entry) == "table" then
          local line = string.format("%s %s %s", tostring(entry.t or ""), tostring(entry.kind or ""), tostring(entry.event or ""))
          local msg2 = tostring(entry.out or entry.msg or entry.link or "")

          local hay = (msg2 ~= "" and msg2 or line)
          if filter == "" or hay:lower():find(filter, 1, true) then
            local extra = ""
            if entry.kind == "MATCH" then
              extra = string.format(" (hasItemLink=%s link=%s qty=%s)", tostring(entry.hasItemLink), tostring(entry.link or ""), tostring(entry.qty or ""))
            else
              if entry.itemID then
                extra = extra .. string.format(" (itemID=%s)", tostring(entry.itemID))
              end
              if entry.link and entry.link ~= "" and (entry.kind == "CHAT_IN" or entry.kind == "CHAT_OUT") then
                extra = extra .. string.format(" (link=%s)", tostring(entry.link))
              end
              if entry.hasItemLink ~= nil and entry.kind == "CHAT_IN" then
                extra = extra .. string.format(" (hasItemLink=%s)", tostring(entry.hasItemLink))
              end
              if entry.rewrittenMoney then
                extra = extra .. " (rewrittenMoney=true)"
              end
              if entry.rewrittenCurrency then
                extra = extra .. " (rewrittenCurrency=true)"
              end
              if entry.async then
                extra = extra .. " (async=true)"
              end
            end

            if msg2 ~= "" then
              SafeCall(Print, line .. " :: " .. msg2 .. extra)
            else
              SafeCall(Print, line .. extra)
            end
          end
        end
      end
      return
    end

    local enabled = (DB and DB.debugCapture) and "on" or "off"
    local stacks = (DB and DB.debugCaptureStacks) and "on" or "off"
    local count = (CHARDB and type(CHARDB.debugCaptureLog) == "table") and #CHARDB.debugCaptureLog or 0
    SafeCall(Print, string.format("Capture: %s (stacks=%s, max=%s, entries=%d)", enabled, stacks, tostring(DB and DB.debugCaptureMax or 200), count))
    SafeCall(Print, "Usage: /fli capture on|off|status|dump [n] [filter]|clear|max <n>|stacks")
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
      SafeCall(Print, string.format("Aliases (%s): %d", scopeLabel == "char" and "Character" or "Account", a))
      for id, text in pairs(t) do
        SafeCall(Print, string.format("  %d = %s", tonumber(id) or 0, tostring(text or "")))
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
        SafeCall(Print, "Usage: /fli alias set [acc|char] <itemID> <text>")
        return
      end

      if scope == "char" then
        CHARDB.linkAliases = (type(CHARDB.linkAliases) == "table") and CHARDB.linkAliases or {}
        CHARDB.linkAliasDisabledChar = (type(CHARDB.linkAliasDisabledChar) == "table") and CHARDB.linkAliasDisabledChar or {}
        CHARDB.linkAliases[id] = text
        CHARDB.linkAliasDisabledChar[id] = nil
        SafeCall(Print, string.format("Alias set (Character): %d -> %s", id, text))
      else
        DB.linkAliases = (type(DB.linkAliases) == "table") and DB.linkAliases or {}
        DB.linkAliasDisabledAccount = (type(DB.linkAliasDisabledAccount) == "table") and DB.linkAliasDisabledAccount or {}
        DB.linkAliases[id] = text
        DB.linkAliasDisabledAccount[id] = nil
        SafeCall(Print, string.format("Alias set (Account): %d -> %s", id, text))
      end
      return
    end

    if sub == "del" or sub == "remove" or sub == "clear" then
      local scope = NormalizeScope(parts[2]) or "acc"
      local idIndex = (NormalizeScope(parts[2]) and 3) or 2
      local id = tonumber(parts[idIndex])
      if not id or id <= 0 then
        SafeCall(Print, "Usage: /fli alias del [acc|char] <itemID>")
        return
      end

      if scope == "char" then
        CHARDB.linkAliases = (type(CHARDB.linkAliases) == "table") and CHARDB.linkAliases or {}
        CHARDB.linkAliasDisabledChar = (type(CHARDB.linkAliasDisabledChar) == "table") and CHARDB.linkAliasDisabledChar or {}
        CHARDB.linkAliases[id] = nil
        CHARDB.linkAliasDisabledChar[id] = nil
        SafeCall(Print, "Alias removed (Character): " .. id)
      else
        DB.linkAliases = (type(DB.linkAliases) == "table") and DB.linkAliases or {}
        DB.linkAliasDisabledAccount = (type(DB.linkAliasDisabledAccount) == "table") and DB.linkAliasDisabledAccount or {}
        DB.linkAliases[id] = nil
        DB.linkAliasDisabledAccount[id] = nil
        SafeCall(Print, "Alias removed (Account): " .. id)
      end
      return
    end

    SafeCall(Print, "Usage: /fli alias set|del|list")
    SafeCall(Print, "  /fli alias set [acc|char] <itemID> <text>")
    SafeCall(Print, "  /fli alias del [acc|char] <itemID>")
    return
  end

  if cmd == "status" then
    Status()
    return
  end

  if cmd == "repair" or cmd == "reapply" then
    SafeCall(ApplyFilters)
    local combine = (type(LootCombineEnabled) == "function" and LootCombineEnabled()) and "on" or "off"
    SafeCall(Print, string.format("reapplied filters (enabled=%s, hide=%s, echo=%s, combine=%s)", (type(IsEnabled) == "function" and IsEnabled()) and "on" or "off", (DB and DB.hideLootText) and "on" or "off", (DB and DB.echoItem) and "on" or "off", combine))
    return
  end

  if cmd == "debugfilters" or cmd == "debug" then
    local add = _G and rawget(_G, "ChatFrame_AddMessageEventFilter")
    local rem = _G and rawget(_G, "ChatFrame_RemoveMessageEventFilter")
    local combine = (type(LootCombineEnabled) == "function" and LootCombineEnabled()) and "on" or "off"
    SafeCall(Print, string.format("enabled=%s, hide=%s, echo=%s, combine=%s", (type(IsEnabled) == "function" and IsEnabled()) and "on" or "off", (DB and DB.hideLootText) and "on" or "off", (DB and DB.echoItem) and "on" or "off", combine))
    SafeCall(Print, string.format("ChatFrame_AddMessageEventFilter=%s", type(add)))
    SafeCall(Print, string.format("ChatFrame_RemoveMessageEventFilter=%s", type(rem)))
    SafeCall(Print, "(If those are nil, chat filters cannot install yet.)")
    return
  end

  if cmd == "ui" or cmd == "config" or cmd == "options" then
    SafeCall(ToggleConfigUI)
    return
  end

  if cmd == "on" or cmd == "enable" then
    -- Keep slash commands account-wide (matches old behavior).
    if CHARDB then CHARDB.enabledOverride = nil end
    if DB then DB.enabled = true end
    SafeCall(ApplyFilters)
    Status()
    return
  end

  if cmd == "off" or cmd == "disable" then
    if CHARDB then CHARDB.enabledOverride = nil end
    if DB then DB.enabled = false end
    SafeCall(ApplyFilters)
    Status()
    return
  end

  if cmd == "toggle" then
    if CHARDB then CHARDB.enabledOverride = nil end
    if DB then DB.enabled = not DB.enabled end
    SafeCall(ApplyFilters)
    Status()
    return
  end

  if cmd == "hide" then
    local v = (rest or ""):lower()
    if DB then DB.hideLootText = (v ~= "off" and v ~= "0" and v ~= "false") end
    Status()
    return
  end

  if cmd == "echo" then
    local v = (rest or ""):lower()
    if DB then DB.echoItem = (v ~= "off" and v ~= "0" and v ~= "false") end
    Status()
    return
  end

  if cmd == "selfname" then
    local v = (rest or ""):lower()
    if DB then DB.showSelfNameAlways = (v ~= "off" and v ~= "0" and v ~= "false") end
    Status()
    return
  end

  if cmd == "prefix" then
    local p = tostring(rest or "")
    if DB then
      if p == "" then
        DB.echoPrefix = ""
      elseif p:lower() == "default" then
        DB.echoPrefix = tostring(e.PREFIX or "")
      else
        DB.echoPrefix = p
      end
    end
    Status()
    return
  end

  if cmd == "mail" then
    local v = (rest or ""):lower()
    if DB then DB.mailNotify = DB.mailNotify or {} end

    local MailNotifyCfg = e.MailNotifyCfg
    local UpdateMailNotifier = e.UpdateMailNotifier
    local CreateMailNotifier = e.CreateMailNotifier
    local ApplyMailModelToFrame = e.ApplyMailModelToFrame

    if v:match("^model") then
      local _, kind, id = v:match("^(model)%s*(%S*)%s*(%S*)")
      kind = tostring(kind or ""):lower()

      if kind == "" then
        local ui = SafeCall(CreateConfigUI)
        if ui then
          ui:Show()
          if ui.SelectTab then ui.SelectTab("mail") end
        end
        return
      end

      local mnc = SafeCall(MailNotifyCfg)
      if not mnc then return end
      mnc.model = mnc.model or {}
      if kind == "picker" then
        local ui = SafeCall(CreateConfigUI)
        if ui then
          ui:Show()
          if ui.SelectTab then ui.SelectTab("mail") end
        end
        return
      elseif kind == "katy" then
        mnc.model.kind = "npc"
        mnc.model.id = 132969
        SafeCall(UpdateMailNotifier)
        SafeCall(Print, "Mail model: Katy Stampwhistle (132969)")
        return
      elseif kind == "dalaran" then
        mnc.model.kind = "npc"
        mnc.model.id = 104230
        SafeCall(UpdateMailNotifier)
        SafeCall(Print, "Mail model: Dalaran Mailemental (104230)")
        return
      elseif kind == "plagued" then
        mnc.model.kind = "npc"
        mnc.model.id = 155971
        SafeCall(UpdateMailNotifier)
        SafeCall(Print, "Mail model: Plagued Mailemental (155971)")
        return
      elseif kind == "player" then
        mnc.model.kind = "player"
        mnc.model.id = nil
        SafeCall(UpdateMailNotifier)
        SafeCall(Print, "Mail model: player")
        return
      elseif kind == "display" then
        local n = tonumber(id)
        if not n then
          SafeCall(Print, "Usage: /fli mail model display <id>")
          return
        end
        mnc.model.kind = "display"
        mnc.model.id = n
        SafeCall(UpdateMailNotifier)
        SafeCall(Print, "Mail model: display " .. n)
        return
      elseif kind == "npc" or kind == "creature" then
        local n = tonumber(id)
        if not n then
          SafeCall(Print, "Usage: /fli mail model npc <id>")
          return
        end
        mnc.model.kind = "npc"
        mnc.model.id = n
        SafeCall(UpdateMailNotifier)
        SafeCall(Print, "Mail model: npc " .. n)
        return
      elseif kind == "file" then
        local n = tonumber(id)
        if not n then
          SafeCall(Print, "Usage: /fli mail model file <id>")
          return
        end
        mnc.model.kind = "file"
        mnc.model.id = n
        SafeCall(UpdateMailNotifier)
        SafeCall(Print, "Mail model: file " .. n)
        return
      else
        SafeCall(Print, "Usage: /fli mail model [player|npc <id>|display <id>|file <id>]")
        return
      end
    end

    local function GetMailNotifyModeCLI()
      if CHARDB and CHARDB.mailNotifyEnabledOverride == true then return "on" end
      if CHARDB and CHARDB.mailNotifyEnabledOverride == false then return "off" end
      if DB and DB.mailNotify and DB.mailNotify.enabled then return "acc" end
      return "off"
    end

    local function SetMailNotifyModeCLI(mode)
      mode = tostring(mode or ""):lower()
      if DB then DB.mailNotify = DB.mailNotify or {} end
      if mode == "on" then
        if CHARDB then CHARDB.mailNotifyEnabledOverride = true end
      elseif mode == "acc" then
        if CHARDB then CHARDB.mailNotifyEnabledOverride = nil end
        if DB and DB.mailNotify then DB.mailNotify.enabled = true end
      else -- off
        if CHARDB then CHARDB.mailNotifyEnabledOverride = false end
      end
      SafeCall(UpdateMailNotifier)
      SafeCall(Print, "Mail notifier: " .. ((mode == "on") and "on" or ((mode == "acc") and "on acc" or "off")))
    end

    if v == "" or v == "toggle" then
      local cur = GetMailNotifyModeCLI()
      local nextMode = (cur == "off") and "on" or ((cur == "on") and "acc" or "off")
      SetMailNotifyModeCLI(nextMode)
      return
    end
    if v == "on" or v == "1" or v == "true" then
      SetMailNotifyModeCLI("on")
      return
    end
    if v == "acc" then
      SetMailNotifyModeCLI("acc")
      return
    end
    if v == "off" or v == "0" or v == "false" then
      SetMailNotifyModeCLI("off")
      return
    end
    if v == "test" then
      local mf = SafeCall(CreateMailNotifier)
      local mnc = SafeCall(MailNotifyCfg)
      if not (mf and mnc and mnc.ui) then return end
      mf:ClearAllPoints()
      local UIParent = _G and rawget(_G, "UIParent")
      mf:SetPoint(mnc.ui.point or "TOPRIGHT", UIParent, mnc.ui.point or "TOPRIGHT", mnc.ui.x or 0, mnc.ui.y or 0)
      local InCombatLockdown = _G and rawget(_G, "InCombatLockdown")
      if (mnc.showInCombat == false) and type(InCombatLockdown) == "function" and InCombatLockdown() then
        mf:Hide()
        SafeCall(Print, "Mail notifier: hidden in combat.")
        return
      end
      SafeCall(ApplyMailModelToFrame, mf.model)
      mf:Show()
      SafeCall(Print, "Mail notifier: shown (test).")
      return
    end

    SafeCall(Print, "Usage: /fli mail on|acc|off|toggle|test")
    return
  end

  SafeCall(Print, "Unknown command. Try /fli ?")
end
