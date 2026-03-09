---@diagnostic disable: undefined-global
local LI = fr0z3nUI_LootIt or {}
fr0z3nUI_LootIt = LI

LI.LootTab = LI.LootTab or {}

function LI.LootTab.BuildTab(lootPanel, env)
  if not lootPanel then return end
  env = env or {}

  local EnsureDB = env.EnsureDB or function() end
  local GetDB = env.GetDB or function() return _G and rawget(_G, "fr0z3nUI_LootItDB") end
  local GetCharDB = env.GetCharDB or function() return _G and rawget(_G, "fr0z3nUI_LootItCharDB") end

  local ApplyFilters = env.ApplyFilters or function() end
  local UpdateMailNotifier = env.UpdateMailNotifier or function() end
  local RefreshMailNotifyModeButton = env.RefreshMailNotifyModeButton or function() end
  local RefreshMailCombatButton = env.RefreshMailCombatButton or function() end

  local LootCombineCancelTimers = env.LootCombineCancelTimers or function() end
  local LootCombineFlush = env.LootCombineFlush or function() end

  local SetCheckBoxText = env.SetCheckBoxText or LI.SetCheckBoxText or function(cb, text)
    if not cb then return end
    local t = cb.Text or cb.text
    if t and t.SetText then
      t:SetText(tostring(text or ""))
    elseif cb.SetText then
      cb:SetText(tostring(text or ""))
    end
  end
  local SetCheckBoxChecked = env.SetCheckBoxChecked or LI.SetCheckBoxChecked or function(cb, checked)
    if not cb then return end
    if cb.SetChecked then
      cb:SetChecked(checked == true)
    end
  end

  local enableModeBtn = env.enableModeBtn
  local GetSupportedMessageLines = env.GetSupportedMessageLines or function() return {} end

  local hideLootBtn = CreateFrame("Button", nil, lootPanel, "UIPanelButtonTemplate")
  hideLootBtn:SetSize(60, 20)
  hideLootBtn:SetPoint("TOPLEFT", lootPanel, "TOPLEFT", 10, -2)

  if enableModeBtn and enableModeBtn.ClearAllPoints and enableModeBtn.SetPoint then
    enableModeBtn:ClearAllPoints()
    enableModeBtn:SetPoint("BOTTOMLEFT", hideLootBtn, "TOPLEFT", 0, 6)
  end

  local hideLootLabel = lootPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  hideLootLabel:SetPoint("LEFT", hideLootBtn, "RIGHT", 10, 0)
  hideLootLabel:SetText("|cff15AB0DYou receive loot:|r")

  local function RefreshHideLootButton()
    EnsureDB()
    local DB = GetDB()
    if not DB then return end

    local hideOn = (DB.hideLootText == true)
    hideLootBtn:SetText(hideOn and "Hide" or "Show")
    local fs = hideLootBtn.GetFontString and hideLootBtn:GetFontString() or nil
    if fs and fs.SetTextColor then
      if hideOn then
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
        fs:SetTextColor(0.55, 0.55, 0.55, 1) -- grey
      end
    end
  end

  hideLootBtn:SetScript("OnClick", function()
    EnsureDB()
    local DB = GetDB()
    if not DB then return end

    DB.hideLootText = not (DB.hideLootText == true)
    RefreshHideLootButton()
  end)

  local function TightenCheckBoxLabel(cb)
    local t = cb and (cb.Text or cb.text)
    if t and t.ClearAllPoints and t.SetPoint then
      if cb and cb.SetSize then
        cb:SetSize(24, 24)
      end
      t:ClearAllPoints()
      t:SetPoint("LEFT", cb, "RIGHT", 3, 0)

      if cb and cb.SetHitRectInsets and t.GetStringWidth then
        local w = tonumber(t:GetStringWidth()) or 0
        if w > 0 then
          cb:SetHitRectInsets(0, -(w + 10), 0, 0)
        end
      end
    end
  end

  local echo = CreateFrame("CheckButton", nil, lootPanel, "UICheckButtonTemplate")
  echo:SetPoint("LEFT", hideLootLabel, "RIGHT", 12, 0)
  SetCheckBoxText(echo, "Show Loot Only Line")
  echo:SetScript("OnClick", function(self)
    EnsureDB()
    local DB = GetDB()
    if not DB then return end

    DB.echoItem = self:GetChecked() and true or false
  end)

  TightenCheckBoxLabel(echo)

  local combineLabel = lootPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  combineLabel:SetPoint("TOPLEFT", hideLootBtn, "BOTTOMLEFT", 2, -10)
  combineLabel:SetText("Loot In Line")

  local combineBox = CreateFrame("EditBox", nil, lootPanel, "InputBoxTemplate")
  combineBox:SetSize(46, 20)
  combineBox:SetPoint("LEFT", combineLabel, "RIGHT", 8, 0)
  combineBox:SetAutoFocus(false)
  combineBox:SetNumeric(true)
  combineBox:SetJustifyH("CENTER")
  combineBox:SetScript("OnEnterPressed", function(self)
    EnsureDB()
    local DB = GetDB()
    if not DB then return end

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
    local DB = GetDB()
    if not DB then return end

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
    local DB = GetDB()
    if not DB then return end

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
    local DB = GetDB()
    if not DB then return end

    local isLoot = (tostring(DB.lootCombineMode or "loot") == "loot")
    if modeToggle._text then
      modeToggle._text:SetText(isLoot and "Loot Window" or "Loot Period")
      modeToggle._text:SetTextColor(COPPER[1], COPPER[2], COPPER[3], COPPER[4])
    end
  end

  modeToggle:SetScript("OnClick", function()
    EnsureDB()
    local DB = GetDB()
    if not DB then return end

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
    local DB = GetDB()
    if not DB then return end

    DB.money = DB.money or {}
    moneyGold:SetOn(DB.money.gold ~= false)
    moneySilver:SetOn(DB.money.silver == true)
    moneyCopper:SetOn(DB.money.copper == true)
  end

  moneyGold:SetScript("OnClick", function()
    EnsureDB()
    local DB = GetDB()
    if not DB then return end

    DB.money = DB.money or {}
    DB.money.gold = not (DB.money.gold ~= false)
    RefreshMoneyButtons()
  end)

  moneySilver:SetScript("OnClick", function()
    EnsureDB()
    local DB = GetDB()
    if not DB then return end

    DB.money = DB.money or {}
    DB.money.silver = not (DB.money.silver == true)
    RefreshMoneyButtons()
  end)

  moneyCopper:SetScript("OnClick", function()
    EnsureDB()
    local DB = GetDB()
    if not DB then return end

    DB.money = DB.money or {}
    DB.money.copper = not (DB.money.copper == true)
    RefreshMoneyButtons()
  end)

  local selfName = CreateFrame("CheckButton", nil, lootPanel, "UICheckButtonTemplate")
  SetCheckBoxText(selfName, "Show My Name Always")
  selfName:SetScript("OnClick", function(self)
    EnsureDB()
    local DB = GetDB()
    if not DB then return end

    DB.showSelfNameAlways = self:GetChecked() and true or false
  end)

  TightenCheckBoxLabel(selfName)

  local outputLabel = lootPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  outputLabel:SetPoint("TOPLEFT", moneyGold, "BOTTOMLEFT", 2, -8)
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
            local DB = GetDB()
            if not DB then return end

            for i = 1, (NUM_CHAT_WINDOWS or 1) do
              local name = GetChatWindowInfo and GetChatWindowInfo(i)
              if not name or name == "" then name = "Chat " .. i end
              local label = string.format("%d: %s", i, name)
              if root and root.CreateRadio then
                root:CreateRadio(label, function() return (DB.outputChatFrame == i) end, function()
                  EnsureDB()
                  local DB2 = GetDB()
                  if not DB2 then return end

                  DB2.outputChatFrame = i
                  if UIDropDownMenu_SetSelectedID then UIDropDownMenu_SetSelectedID(outputDD, i) end
                end)
              elseif root and root.CreateButton then
                root:CreateButton(label, function()
                  EnsureDB()
                  local DB2 = GetDB()
                  if not DB2 then return end

                  DB2.outputChatFrame = i
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
        local DB = GetDB()
        if not DB then return end

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
            local DB2 = GetDB()
            if not DB2 then return end

            DB2.outputChatFrame = i
            UIDropDownMenu_SetSelectedID(outputDD, i)
            do
              local cdm = _G and rawget(_G, "CloseDropDownMenus")
              if cdm then cdm() end
            end
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
    local DB = GetDB()
    if not DB then return end

    DB.echoPrefix = tostring(self:GetText() or "")
    self:ClearFocus()
  end)
  prefixBox:SetScript("OnEscapePressed", function(self)
    local DB = GetDB()
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

  selfName:ClearAllPoints()
  selfName:SetPoint("TOP", moneyGold, "TOP", 0, 0)
  selfName:SetPoint("LEFT", prefixLabel, "LEFT", 0, 0)

  local ilvlRow = CreateFrame("Frame", nil, lootPanel)
  ilvlRow:SetHeight(20)
  ilvlRow:SetPoint("TOPLEFT", outputLabel, "BOTTOMLEFT", 0, -6)
  ilvlRow:SetPoint("RIGHT", lootPanel, "RIGHT", -10, 0)

  local ilvlLabel = lootPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  ilvlLabel:SetPoint("LEFT", ilvlRow, "LEFT", 0, 0)
  ilvlLabel:SetText("iLvl")

  local ilvlToggle = CreateFrame("Button", nil, lootPanel)
  ilvlToggle:SetSize(120, 20)
  ilvlToggle:SetPoint("LEFT", ilvlLabel, "RIGHT", 10, 0)

  local ilvlHL = ilvlToggle:CreateTexture(nil, "HIGHLIGHT")
  ilvlHL:SetColorTexture(1, 1, 1, 0.06)
  ilvlHL:SetAllPoints(ilvlToggle)

  local ilvlText = ilvlToggle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ilvlText:SetPoint("CENTER", ilvlToggle, "CENTER", 0, 0)
  ilvlToggle._text = ilvlText

  local function GetIlvlMode()
    EnsureDB()
    local DB = GetDB()
    local CHARDB = GetCharDB()
    if not (DB and CHARDB) then return "on_acc" end

    local accOn = (DB.showItemLevel ~= false)
    local charHasOverride = (CHARDB.showItemLevel ~= nil)

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
    local DB = GetDB()
    local CHARDB = GetCharDB()
    if not (DB and CHARDB) then return end

    if mode == "on_acc" then
      CHARDB.showItemLevel = false
    elseif mode == "off_char" then
      DB.showItemLevel = false
      CHARDB.showItemLevel = nil
    else
      DB.showItemLevel = true
      CHARDB.showItemLevel = nil
    end

    RefreshIlvlButtons()
  end)

  RefreshIlvlButtons()

  local reset = CreateFrame("Button", nil, lootPanel, "UIPanelButtonTemplate")
  reset:SetSize(120, 22)

  local resetRow = CreateFrame("Frame", nil, lootPanel)
  resetRow:SetHeight(1)
  resetRow:SetPoint("TOP", ilvlRow, "BOTTOM", 0, -6)
  resetRow:SetPoint("LEFT", lootPanel, "LEFT", 0, 0)
  resetRow:SetPoint("RIGHT", lootPanel, "RIGHT", 0, 0)

  reset:SetPoint("TOP", resetRow, "TOP", 0, 0)
  reset:SetText("Reset Defaults")

  local supportedLabel = lootPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")

  local supportedRow = CreateFrame("Frame", nil, lootPanel)
  supportedRow:SetHeight(1)
  supportedRow:SetPoint("TOP", reset, "BOTTOM", 0, -12)
  supportedRow:SetPoint("LEFT", lootPanel, "LEFT", 10, 0)
  supportedRow:SetPoint("RIGHT", lootPanel, "RIGHT", -10, 0)

  supportedLabel:SetPoint("TOPLEFT", supportedRow, "TOPLEFT", 0, 0)
  supportedLabel:SetText("")
  if supportedLabel.Hide then supportedLabel:Hide() end

  local scroll = CreateFrame("ScrollFrame", nil, lootPanel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", supportedRow, "TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", lootPanel, "BOTTOMRIGHT", -28, 28)

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
    local lines = GetSupportedMessageLines() or {}

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

  lootPanel.Refresh = function()
    EnsureDB()
    local DB = GetDB()
    if not DB then return end

    RefreshHideLootButton()
    SetCheckBoxChecked(echo, DB.echoItem)
    SetCheckBoxChecked(selfName, DB.showSelfNameAlways)
    RefreshIlvlButtons()

    combineBox:SetText(tostring(DB.lootCombineCount or 1))
    combineCur:SetOn(DB.lootCombineIncludeCurrency)
    combineGold:SetOn(DB.lootCombineIncludeGold)
    RefreshCombineModeButtons()

    RefreshMoneyButtons()

    UIDropDownMenu_SetSelectedID(outputDD, DB.outputChatFrame or 1)
    prefixBox:SetText(DB.echoPrefix or "")

    RefreshSupportedList()
  end

  reset:SetScript("OnClick", function()
    fr0z3nUI_LootItDB = {}
    fr0z3nUI_LootItCharDB = {}
    EnsureDB()

    ApplyFilters()
    UpdateMailNotifier()

    RefreshMailNotifyModeButton()
    RefreshMailCombatButton()

    if lootPanel.Refresh then
      lootPanel:Refresh()
    end
  end)

  if env.initialRefresh ~= false and lootPanel.Refresh then
    lootPanel:Refresh()
  end
end
