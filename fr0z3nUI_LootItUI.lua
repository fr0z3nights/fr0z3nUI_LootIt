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

    local frame = CreateFrame("Frame", "fr0z3nUI_LootIt_Config", UIParent, "BackdropTemplate")

    do
      -- Match FGO styling: simple tooltip background + top tab bar.
      frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
      })
      frame:SetBackdropColor(0, 0, 0, 0.85)

      local tabBarBG = CreateFrame("Frame", nil, frame, "BackdropTemplate")
      tabBarBG:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
      tabBarBG:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
      tabBarBG:SetHeight(26)
      tabBarBG:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
      })
      tabBarBG:SetBackdropColor(0, 0, 0, 0.92)
      tabBarBG:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 0) + 1)
      frame._tabBarBG = tabBarBG

      local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
      closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
      closeBtn:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 0) + 20)
      closeBtn:SetScript("OnClick", function()
        if frame and frame.Hide then
          frame:Hide()
        end
      end)
      frame._closeBtn = closeBtn
    end

    if type(UISpecialFrames) == "table" then
      local name = "fr0z3nUI_LootIt_Config"
      local exists = false
      for i = 1, #UISpecialFrames do
        if UISpecialFrames[i] == name then exists = true break end
      end
      if not exists and tinsert then tinsert(UISpecialFrames, name) end
    end

    frame:SetSize(480, 400)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
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

    local titleFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame._titleFS = titleFS

    titleFS:ClearAllPoints()
    if frame._tabBarBG and titleFS.SetParent then
      titleFS:SetParent(frame._tabBarBG)
    end
    if frame._tabBarBG then
      titleFS:SetPoint("LEFT", frame._tabBarBG, "LEFT", 8, 0)
    else
      titleFS:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -6)
    end
    titleFS:SetText("|cff00ccff[FLI]|r")
    do
      local fontPath, fontSize, fontFlags = titleFS:GetFont()
      if fontPath and fontSize then
        titleFS:SetFont(fontPath, fontSize + 2, fontFlags)
      end
    end
    if titleFS.Show then titleFS:Show() end

    -- Content root (below the tab bar), matching FGO layout.
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -54)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    frame._content = content

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
          local c = rawget(_G, "GREEN_FONT_COLOR")
          if c and type(c.GetRGB) == "function" then
            local r, g, b = c:GetRGB()
            fs:SetTextColor(r or 0.20, g or 1.00, b or 0.20, 1)
          elseif type(c) == "table" and c.r and c.g and c.b then
            fs:SetTextColor(c.r, c.g, c.b, c.a or 1)
          else
            fs:SetTextColor(0.20, 1.00, 0.20, 1)
          end
        else
          fs:SetTextColor(0.55, 0.55, 0.55, 1)
        end
      end
    end

    local function GetMailNotifyScope()
      RefreshRefs()
      return (CHARDB and CHARDB.mailNotifyScope == "char") and "char" or "acc"
    end

    local function SetMailNotifyScope(scope)
      RefreshRefs()
      scope = tostring(scope or ""):lower()
      if scope == "char" or scope == "character" then
        CHARDB.mailNotifyScope = "char"
      else
        CHARDB.mailNotifyScope = nil
      end
      UpdateMailNotifier()
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
    sub:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
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

    local TAB_COUNT = 6
    local TAB_OVERLAP_X = -6

    local function SizeTabToText(btn, pad, minW)
      if not (btn and btn.GetFontString and btn.SetWidth) then return end
      local fs = btn:GetFontString()
      local w = (fs and fs.GetStringWidth and fs:GetStringWidth()) or 0
      w = (tonumber(w) or 0) + (tonumber(pad) or 18)
      if minW and w < minW then w = minW end
      btn:SetWidth(w)
    end

    local function StyleTab(btn, active)
      if not (btn and btn.GetFontString) then return end
      local fs = btn:GetFontString()
      if fs and fs.SetTextColor then
        if active then
          fs:SetTextColor(1.0, 0.82, 0.0, 1)
        else
          fs:SetTextColor(0.70, 0.70, 0.70, 1)
        end
      end
    end

    local function UpdateTabZOrder(activeIndex)
      local base = (frame.GetFrameLevel and frame:GetFrameLevel()) or 0
      base = base + 20
      for i = 1, TAB_COUNT do
        local t = frame["tab" .. tostring(i)]
        if t and t.SetFrameLevel then
          t:SetFrameLevel(base + (TAB_COUNT - i))
        end
      end
      local a = tonumber(activeIndex)
      if a and a >= 1 and a <= TAB_COUNT then
        local t = frame["tab" .. tostring(a)]
        if t and t.SetFrameLevel then
          t:SetFrameLevel(base + TAB_COUNT + 5)
        end
      end
    end

    local tabLoot = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabLoot:SetID(1)
    tabLoot:SetText("LootIt")
    tabLoot:SetPoint("LEFT", titleFS, "RIGHT", 10, 0)
    tabLoot:SetHeight(22)
    SizeTabToText(tabLoot, 18, 70)
    frame.tab1 = tabLoot

    local tabAlias = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabAlias:SetID(2)
    tabAlias:SetText("Alias")
    tabAlias:SetPoint("LEFT", tabLoot, "RIGHT", TAB_OVERLAP_X, 0)
    tabAlias:SetHeight(22)
    SizeTabToText(tabAlias, 18, 70)
    frame.tab2 = tabAlias

    local tabOther = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabOther:SetID(3)
    tabOther:SetText("Other")
    tabOther:SetPoint("LEFT", tabLoot, "RIGHT", TAB_OVERLAP_X, 0)
    tabOther:SetHeight(22)
    SizeTabToText(tabOther, 18, 70)
    frame.tab3 = tabOther

    local tabMail = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabMail:SetID(4)
    tabMail:SetText("Mail")
    tabMail:SetPoint("LEFT", tabOther, "RIGHT", TAB_OVERLAP_X, 0)
    tabMail:SetHeight(22)
    SizeTabToText(tabMail, 18, 70)
    frame.tab4 = tabMail

    local tabTax = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabTax:SetID(5)
    tabTax:SetText("Tax")
    tabTax:SetPoint("LEFT", tabMail, "RIGHT", TAB_OVERLAP_X, 0)
    tabTax:SetHeight(22)
    SizeTabToText(tabTax, 18, 70)
    frame.tab5 = tabTax

    local tabDeposit = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabDeposit:SetID(6)
    tabDeposit:SetText("Trade")
    tabDeposit:SetPoint("LEFT", tabTax, "RIGHT", TAB_OVERLAP_X, 0)
    tabDeposit:SetHeight(22)
    SizeTabToText(tabDeposit, 18, 70)
    frame.tab6 = tabDeposit

    local lootPanel = CreateFrame("Frame", nil, frame)
    lootPanel:SetAllPoints(content)

    enableModeBtn:SetParent(lootPanel)
    enableModeBtn:ClearAllPoints()
    enableModeBtn:SetPoint("TOPLEFT", lootPanel, "TOPLEFT", 0, 0)
    do
      local m = GetEnableMode()
      enableModeBtn:SetText((m == "on") and "On" or ((m == "acc") and "On Acc" or "Off"))
    end

    local mailPanel = CreateFrame("Frame", nil, frame)
    mailPanel:SetAllPoints(content)

    local otherPanel = CreateFrame("Frame", nil, frame)
    otherPanel:SetAllPoints(content)

    local taxPanel = CreateFrame("Frame", nil, frame)
    taxPanel:SetAllPoints(content)

    local depositPanel = CreateFrame("Frame", nil, frame)
    depositPanel:SetAllPoints(content)

    -- Alias popout (Alias content moved off the tab bar)
    local aliasPopout = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    aliasPopout:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    aliasPopout:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    aliasPopout:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 0) + 80)
    aliasPopout:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    aliasPopout:SetBackdropColor(0, 0, 0, 0.92)
    aliasPopout:Hide()

    local aliasPanel = CreateFrame("Frame", nil, aliasPopout)
    aliasPanel:SetAllPoints(aliasPopout)

    local function ToggleAliasPopout(force)
      local show = force
      if show == nil then
        show = not (aliasPopout.IsShown and aliasPopout:IsShown())
      end
      if show then
        aliasPopout:Show()
        if aliasPanel and aliasPanel.Refresh then
          aliasPanel:Refresh()
        end
      else
        aliasPopout:Hide()
      end
    end
    frame.ToggleAliasPopout = ToggleAliasPopout

    local function SelectTab(which)
      which = tostring(which or "loot"):lower()
      local isLoot = (which == "loot")
      local isAlias = false
      local isOther = (which == "other")
      local isMail = (which == "mail")
      local isTax = (which == "tax")
      local isDeposit = (which == "deposit")

      lootPanel:SetShown(isLoot)
      otherPanel:SetShown(isOther)
      mailPanel:SetShown(isMail)
      taxPanel:SetShown(isTax)
      depositPanel:SetShown(isDeposit)

      if aliasPopout and aliasPopout.Hide then
        aliasPopout:Hide()
      end

      if enableModeBtn and enableModeBtn.SetShown then
        enableModeBtn:SetShown(isLoot)
      end

      StyleTab(tabLoot, isLoot)
      StyleTab(tabAlias, false)
      StyleTab(tabOther, isOther)
      StyleTab(tabMail, isMail)
      StyleTab(tabTax, isTax)
      StyleTab(tabDeposit, isDeposit)

      UpdateTabZOrder(isLoot and 1 or (isOther and 3 or (isMail and 4 or (isTax and 5 or 6))))

      frame._activeTab = isLoot and "loot" or (isOther and "other" or (isMail and "mail" or (isTax and "tax" or "deposit")))

      ApplyMailNotifierInteractivity()
    end

    frame.SelectTab = SelectTab

    tabLoot:SetScript("OnClick", function() SelectTab("loot") end)
    tabAlias:SetScript("OnClick", function() SelectTab("loot") end)
    tabOther:SetScript("OnClick", function() SelectTab("other") end)
    tabMail:SetScript("OnClick", function() SelectTab("mail") end)
    tabTax:SetScript("OnClick", function() SelectTab("tax") end)
    tabDeposit:SetScript("OnClick", function() SelectTab("deposit") end)

    -- Initialize first tab styling + z-order.
    StyleTab(tabLoot, true)
    StyleTab(tabAlias, false)
    StyleTab(tabOther, false)
    StyleTab(tabMail, false)
    StyleTab(tabTax, false)
    StyleTab(tabDeposit, false)
    UpdateTabZOrder(1)

    do
      local mod = fr0z3nUI_LootIt
      if mod and mod.Trade and type(mod.Trade.BuildTab) == "function" then
        mod.Trade.BuildTab(depositPanel)
      end
    end

    do
      local mod = fr0z3nUI_LootIt
      if mod and mod.Tax and type(mod.Tax.BuildTab) == "function" then
        mod.Tax.BuildTab(taxPanel, {
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
          ToggleAliasPopout = ToggleAliasPopout,
        })
      end
    end

    do
      if LI and LI.Alias and type(LI.Alias.BuildTab) == "function" then
        LI.Alias.BuildTab(aliasPanel)
      end
    end

    if tabAlias and tabAlias.Hide then
      tabAlias:Hide()
    end

    do
      local mod = fr0z3nUI_LootIt
      if mod and mod.Mail and type(mod.Mail.BuildTab) == "function" then
        mod.Mail.BuildTab(mailPanel, mailUI, {
          EnsureDB = EnsureDB,
          MailNotifyCfg = MailNotifyCfg,
          GetMailNotifyScope = GetMailNotifyScope,
          SetMailNotifyScope = SetMailNotifyScope,
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
