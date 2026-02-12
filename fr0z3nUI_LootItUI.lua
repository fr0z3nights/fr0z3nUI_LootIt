---@diagnostic disable: undefined-global
local LI = fr0z3nUI_LootIt or {}
fr0z3nUI_LootIt = LI

LI.UI = LI.UI or {}

do
  local UI = LI.UI

  UI._env = UI._env or {}

  function UI.SetEnv(env)
    UI._env = (type(env) == "table") and env or {}
  end

  local function GetEnv()
    return UI._env or {}
  end

  local ConfigUI

  function UI.GetConfigUI()
    return ConfigUI
  end

  function UI.IsMailEditorOpen()
    if not (ConfigUI and ConfigUI.IsShown and ConfigUI:IsShown()) then return false end
    return (ConfigUI._activeTab == "mail")
  end

  function UI.CreateConfigUI()
    if ConfigUI then return ConfigUI end

    local env = GetEnv()

    local EnsureDB = env.EnsureDB or function(...) end
    local GetDB = env.GetDB or function(...) return nil end
    local GetCharDB = env.GetCharDB or function(...) return nil end

    local ApplyFilters = env.ApplyFilters or function(...) end
    local LootCombineCancelTimers = env.LootCombineCancelTimers or function(...) end
    local LootCombineFlush = env.LootCombineFlush or function(...) end
    local SetCheckBoxText = env.SetCheckBoxText or function(...) end
    local SetCheckBoxChecked = env.SetCheckBoxChecked or function(...) end
    local GetSupportedMessageLines = env.GetSupportedMessageLines or function(...) return {} end
    local MailNotifyCfg = env.MailNotifyCfg or function(...) return nil end

    local Print = env.Print or LI.Print or function(...) end

    local Clamp = env.Clamp
    if type(Clamp) ~= "function" then
      Clamp = _G and rawget(_G, "Clamp")
    end
    if type(Clamp) ~= "function" then
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

    local ApplyMailNotifierInteractivity = env.ApplyMailNotifierInteractivity or function(...) end
    local CreateMailNotifier = env.CreateMailNotifier or function(...) return nil end
    local UpdateMailNotifier = env.UpdateMailNotifier or function(...) end
    local ApplyMailModelToFrame = env.ApplyMailModelToFrame or function(...) end
    local ModelApplyAnimation = env.ModelApplyAnimation or function(...) end
    local ModelGetRotation = env.ModelGetRotation or function(...) return 0 end
    local ModelSetRotation = env.ModelSetRotation or function(...) end
    local ModelApplyZoom = env.ModelApplyZoom or function(...) end
    local GetMailNotifier = env.GetMailNotifier or function(...) return nil end

    local DB
    local CHARDB

    local function RefreshRefs()
      EnsureDB()
      DB = GetDB()
      CHARDB = GetCharDB()
    end

    RefreshRefs()

    local UISpecialFrames = _G and rawget(_G, "UISpecialFrames")

    local frame = CreateFrame("Frame", "fr0z3nUI_LootIt_Config", UIParent, "BasicFrameTemplateWithInset")

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
      RefreshRefs()
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
    titleFS:SetText("|cff00ccff[FLI]|r")
    if titleFS.Show then titleFS:Show() end

    local function GetEnableMode()
      RefreshRefs()
      if CHARDB and CHARDB.enabledOverride == true then return "on" end
      if CHARDB and CHARDB.enabledOverride == false then return "off" end
      if DB and DB.enabled then return "acc" end
      return "off"
    end

    local function SetEnableMode(mode)
      RefreshRefs()
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

    local mailUI = {}

    local function GetMailNotifyMode()
      RefreshRefs()
      if CHARDB and CHARDB.mailNotifyEnabledOverride == true then return "on" end
      if CHARDB and CHARDB.mailNotifyEnabledOverride == false then return "off" end
      if DB and DB.mailNotify and DB.mailNotify.enabled then return "acc" end
      return "off"
    end

    local function SetMailNotifyMode(mode)
      RefreshRefs()
      DB.mailNotify = DB.mailNotify or {}
      mode = tostring(mode or ""):lower()
      if mode == "on" then
        CHARDB.mailNotifyEnabledOverride = true
      elseif mode == "acc" then
        CHARDB.mailNotifyEnabledOverride = nil
        DB.mailNotify.enabled = true
      else -- off
        CHARDB.mailNotifyEnabledOverride = false
      end
      UpdateMailNotifier()
    end

    local function RefreshMailNotifyModeButton()
      local btn = mailUI and mailUI.notifyModeBtn
      if not (btn and btn.SetText) then return end
      local m = GetMailNotifyMode()
      btn:SetText((m == "on") and "On" or ((m == "acc") and "On Acc" or "Off"))
    end

    local function IsMailCombatOn()
      local mn = MailNotifyCfg()
      return (mn and mn.showInCombat ~= false) and true or false
    end

    local function RefreshMailCombatButton()
      local btn = mailUI and mailUI.combatBtn
      if not (btn and btn.GetFontString) then return end
      local fs = btn:GetFontString()
      if fs and fs.SetText then
        fs:SetText("Combat")
        if IsMailCombatOn() then
          fs:SetTextColor(1.0, 0.82, 0.0, 1)
        else
          fs:SetTextColor(0.55, 0.55, 0.55, 1)
        end
      end
    end

    local enableModeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    enableModeBtn:SetSize(90, 20)
    enableModeBtn:SetScript("OnClick", function()
      local cur = GetEnableMode()
      local nextMode = (cur == "off") and "on" or ((cur == "on") and "acc" or "off")
      SetEnableMode(nextMode)
      local m = GetEnableMode()
      enableModeBtn:SetText((m == "on") and "On" or ((m == "acc") and "On Acc" or "Off"))
    end)

    local sub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sub:SetPoint("TOPLEFT", frame.InsetBg, "TOPLEFT", 10, -10)
    sub:SetJustifyH("LEFT")
    sub:SetText("")

    local reloadBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    reloadBtn:SetSize(90, 22)
    reloadBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    reloadBtn:SetText("Reload UI")
    reloadBtn:SetScript("OnClick", function()
      local r = _G and _G["ReloadUI"]
      if r then r() end
    end)
    frame._reloadBtn = reloadBtn

    local tabLoot = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabLoot:SetSize(70, 22)
    tabLoot:SetPoint("LEFT", titleFS, "RIGHT", 8, 0)
    tabLoot:SetText("LootIt")

    local tabAlias = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabAlias:SetSize(70, 22)
    tabAlias:SetPoint("LEFT", tabLoot, "RIGHT", -6, 0)
    tabAlias:SetText("Alias")

    local tabOther = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabOther:SetSize(70, 22)
    tabOther:SetPoint("LEFT", tabAlias, "RIGHT", -6, 0)
    tabOther:SetText("Other")

    local tabMail = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabMail:SetSize(70, 22)
    tabMail:SetPoint("LEFT", tabOther, "RIGHT", -6, 0)
    tabMail:SetText("Mail")

    local tabTabard = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabTabard:SetSize(70, 22)
    tabTabard:SetPoint("LEFT", tabMail, "RIGHT", -6, 0)
    tabTabard:SetText("Tabard")

    local tabDeposit = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabDeposit:SetSize(70, 22)
    tabDeposit:SetPoint("LEFT", tabTabard, "RIGHT", -6, 0)
    tabDeposit:SetText("Trade")

    local lootPanel = CreateFrame("Frame", nil, frame)
    lootPanel:SetPoint("TOPLEFT", frame.InsetBg, "TOPLEFT", 0, -24)
    lootPanel:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", 0, 0)

    enableModeBtn:SetParent(lootPanel)
    enableModeBtn:ClearAllPoints()
    enableModeBtn:SetPoint("TOPLEFT", lootPanel, "TOPLEFT", 10, 24)
    do
      local m = GetEnableMode()
      enableModeBtn:SetText((m == "on") and "On" or ((m == "acc") and "On Acc" or "Off"))
    end

    local mailPanel = CreateFrame("Frame", nil, frame)
    mailPanel:SetPoint("TOPLEFT", frame.InsetBg, "TOPLEFT", 0, -24)
    mailPanel:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", 0, 0)

    local aliasPanel = CreateFrame("Frame", nil, frame)
    aliasPanel:SetPoint("TOPLEFT", frame.InsetBg, "TOPLEFT", 0, -24)
    aliasPanel:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", 0, 0)

    local otherPanel = CreateFrame("Frame", nil, frame)
    otherPanel:SetPoint("TOPLEFT", frame.InsetBg, "TOPLEFT", 0, -24)
    otherPanel:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", 0, 0)

    local tabardPanel = CreateFrame("Frame", nil, frame)
    tabardPanel:SetPoint("TOPLEFT", frame.InsetBg, "TOPLEFT", 0, -24)
    tabardPanel:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", 0, 0)

    local depositPanel = CreateFrame("Frame", nil, frame)
    depositPanel:SetPoint("TOPLEFT", frame.InsetBg, "TOPLEFT", 0, -24)
    depositPanel:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", 0, 0)

    local function SelectTab(which)
      which = tostring(which or "loot"):lower()
      local isLoot = (which == "loot")
      local isAlias = (which == "alias")
      local isOther = (which == "other")
      local isMail = (which == "mail")
      local isTabard = (which == "tabard")
      local isDeposit = (which == "deposit")

      lootPanel:SetShown(isLoot)
      aliasPanel:SetShown(isAlias)
      otherPanel:SetShown(isOther)
      mailPanel:SetShown(isMail)
      tabardPanel:SetShown(isTabard)
      depositPanel:SetShown(isDeposit)

      if enableModeBtn and enableModeBtn.SetShown then
        enableModeBtn:SetShown(isLoot)
      end

      local function StyleTab(btn, active)
        if not (btn and btn.GetFontString and btn.IsEnabled and btn.SetEnabled) then return end
        btn:SetEnabled(true)
        if btn.SetFrameLevel and frame.GetFrameLevel then
          local base = frame:GetFrameLevel() or 0
          btn:SetFrameLevel(base + (active and 6 or 4))
        end
        local fs = btn:GetFontString()
        if fs and fs.SetTextColor then
          if active then
            fs:SetTextColor(1.0, 0.82, 0.0, 1)
          else
            fs:SetTextColor(0.70, 0.70, 0.70, 1)
          end
        end
      end

      StyleTab(tabLoot, isLoot)
      StyleTab(tabAlias, isAlias)
      StyleTab(tabOther, isOther)
      StyleTab(tabMail, isMail)
      StyleTab(tabTabard, isTabard)
      StyleTab(tabDeposit, isDeposit)

      frame._activeTab = isLoot and "loot" or (isAlias and "alias" or (isOther and "other" or (isMail and "mail" or (isTabard and "tabard" or "deposit"))))

      ApplyMailNotifierInteractivity()
    end

    frame.SelectTab = SelectTab

    tabLoot:SetScript("OnClick", function() SelectTab("loot") end)
    tabAlias:SetScript("OnClick", function() SelectTab("alias") end)
    tabOther:SetScript("OnClick", function() SelectTab("other") end)
    tabMail:SetScript("OnClick", function() SelectTab("mail") end)
    tabTabard:SetScript("OnClick", function() SelectTab("tabard") end)
    tabDeposit:SetScript("OnClick", function() SelectTab("deposit") end)

    do
      local mod = fr0z3nUI_LootIt
      if mod and mod.Trade and type(mod.Trade.BuildTab) == "function" then
        mod.Trade.BuildTab(depositPanel)
      end
    end

    do
      local mod = fr0z3nUI_LootIt
      local tabMod = _G and rawget(_G, "fr0z3nUI_LootItTabard")
      if tabMod and type(tabMod.BuildTab) == "function" then
        tabMod.BuildTab(tabardPanel, {
          EnsureDB = EnsureDB,
          GetDB = function() return DB end,
          GetCharDB = function() return CHARDB end,
          Clamp = Clamp,
          SetCheckBoxText = SetCheckBoxText,
        })
      elseif mod and mod.TabardUI and type(mod.TabardUI.BuildTab) == "function" then
        -- Backward-compat: older split UI module.
        mod.TabardUI.BuildTab(tabardPanel, {
          EnsureDB = EnsureDB,
          GetDB = function() return DB end,
          GetCharDB = function() return CHARDB end,
          Clamp = Clamp,
          SetCheckBoxText = SetCheckBoxText,
        })
      end
    end

    do
      local mod = fr0z3nUI_LootIt
      if mod and mod.Other and type(mod.Other.BuildTab) == "function" then
        mod.Other.BuildTab(otherPanel, {
          EnsureDB = EnsureDB,
          GetDB = function() return DB end,
          ApplyFilters = ApplyFilters,
          SetCheckBoxText = SetCheckBoxText,
          SetCheckBoxChecked = SetCheckBoxChecked,
        })
      end
    end

    do
      local mod = fr0z3nUI_LootIt
      if mod and mod.LootTab and type(mod.LootTab.BuildTab) == "function" then
        mod.LootTab.BuildTab(lootPanel, {
          EnsureDB = EnsureDB,
          GetDB = function() return DB end,
          GetCharDB = function() return CHARDB end,
          LootCombineCancelTimers = LootCombineCancelTimers,
          LootCombineFlush = LootCombineFlush,
          ApplyFilters = ApplyFilters,
          UpdateMailNotifier = UpdateMailNotifier,
          RefreshMailNotifyModeButton = RefreshMailNotifyModeButton,
          RefreshMailCombatButton = RefreshMailCombatButton,
          SetCheckBoxText = SetCheckBoxText,
          SetCheckBoxChecked = SetCheckBoxChecked,
          GetSupportedMessageLines = GetSupportedMessageLines,
          enableModeBtn = enableModeBtn,
        })
      end
    end

    do
      if LI and LI.Alias and type(LI.Alias.BuildTab) == "function" then
        LI.Alias.BuildTab(aliasPanel)
      end
    end

    do
      local mod = fr0z3nUI_LootIt
      if mod and mod.Mail and type(mod.Mail.BuildTab) == "function" then
        mod.Mail.BuildTab(mailPanel, mailUI, {
          EnsureDB = EnsureDB,
          MailNotifyCfg = MailNotifyCfg,
          GetMailNotifyMode = GetMailNotifyMode,
          SetMailNotifyMode = SetMailNotifyMode,
          RefreshMailNotifyModeButton = RefreshMailNotifyModeButton,
          RefreshMailCombatButton = RefreshMailCombatButton,
          UpdateMailNotifier = UpdateMailNotifier,
          CreateMailNotifier = CreateMailNotifier,
          ApplyMailModelToFrame = ApplyMailModelToFrame,
          ModelApplyAnimation = ModelApplyAnimation,
          ModelGetRotation = ModelGetRotation,
          ModelSetRotation = ModelSetRotation,
          ModelApplyZoom = ModelApplyZoom,
          GetMailNotifier = GetMailNotifier,
          reloadBtn = reloadBtn,
          Print = Print,
          SetCheckBoxText = SetCheckBoxText,
          SetCheckBoxChecked = SetCheckBoxChecked,
        })
      end
    end

    frame:SetScript("OnShow", function(self)
      RefreshRefs()
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
      if lootPanel and lootPanel.Refresh then
        lootPanel:Refresh()
      end
      RefreshMailNotifyModeButton()
      RefreshMailCombatButton()
      if DB and DB.ui then
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
    end)

    frame:SetScript("OnHide", function()
      ApplyMailNotifierInteractivity()
    end)

    SelectTab("loot")

    frame:Hide()
    ConfigUI = frame
    return frame
  end

  function UI.ToggleConfigUI()
    local env = GetEnv()
    local EnsureDB = env.EnsureDB or function(...) end

    EnsureDB()
    local frame = UI.CreateConfigUI()
    if not frame then return end
    if frame.IsShown and frame:IsShown() then
      frame:Hide()
    else
      frame:Show()
    end
  end
end
