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
  local ToggleAliasPopout = env.ToggleAliasPopout

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

  local qualityBtn = CreateInlineTextToggleButton(lootPanel, "Quality", { 1, 0.82, 0, 1 })
  qualityBtn:SetSize(62, 20)
  do
    local t = echo.Text or echo.text
    if t and t.SetPoint then
      qualityBtn:SetPoint("LEFT", t, "RIGHT", 12, 0)
    else
      qualityBtn:SetPoint("LEFT", echo, "RIGHT", 120, 0)
    end
  end

  local qualityPosBtn = CreateFrame("Button", nil, lootPanel)
  qualityPosBtn:SetSize(62, 20)
  qualityPosBtn:SetPoint("LEFT", qualityBtn, "RIGHT", 10, 0)

  local qualityPosHL = qualityPosBtn:CreateTexture(nil, "HIGHLIGHT")
  qualityPosHL:SetColorTexture(1, 1, 1, 0.06)
  qualityPosHL:SetAllPoints(qualityPosBtn)

  local qualityPosText = qualityPosBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  qualityPosText:SetPoint("CENTER", qualityPosBtn, "CENTER", 0, 0)
  qualityPosBtn._text = qualityPosText

  local function RefreshQualityButtons()
    EnsureDB()
    local DB = GetDB()
    if not DB then return end

    local on = (DB.lootQualityIconEnabled ~= false)
    qualityBtn:SetOn(on)

    local pos = tostring(DB.lootQualityIconPosition or "before")
    pos = pos:lower():gsub("%s+", "")
    if pos ~= "before" and pos ~= "after" then pos = "before" end
    DB.lootQualityIconPosition = pos

    if qualityPosBtn._text then
      qualityPosBtn._text:SetText((pos == "before") and "Before" or "After")
      qualityPosBtn._text:SetTextColor(1, 0.82, 0, 1)
    end

    if on then
      if qualityPosBtn.Show then qualityPosBtn:Show() end
    else
      if qualityPosBtn.Hide then qualityPosBtn:Hide() end
    end
  end

  qualityBtn:SetScript("OnClick", function(self)
    EnsureDB()
    local DB = GetDB()
    if not DB then return end

    DB.lootQualityIconEnabled = not (DB.lootQualityIconEnabled ~= false)
    RefreshQualityButtons()
  end)

  qualityPosBtn:SetScript("OnClick", function()
    EnsureDB()
    local DB = GetDB()
    if not DB then return end

    local pos = tostring(DB.lootQualityIconPosition or "before")
    pos = pos:lower():gsub("%s+", "")
    DB.lootQualityIconPosition = (pos == "before") and "after" or "before"
    RefreshQualityButtons()
  end)

  local function StripInputBoxBorder(box)
    if not (box and box.GetRegions) then return end
    local regions = { box:GetRegions() }
    for _, r in ipairs(regions) do
      if r and r.GetObjectType and r:GetObjectType() == "Texture" then
        if r.SetTexture then r:SetTexture(nil) end
        if r.Hide then r:Hide() end
      end
    end
  end

  local function AddEditBoxHover(box)
    if not (box and box.CreateTexture and box.HookScript) then return end
    if box._hoverHL then return end

    local hl = box:CreateTexture(nil, "BACKGROUND")
    hl:SetColorTexture(1, 1, 1, 0.06)
    hl:SetAllPoints(box)
    hl:Hide()
    box._hoverHL = hl

    box:HookScript("OnEnter", function(self)
      if self._hoverHL then self._hoverHL:Show() end
    end)
    box:HookScript("OnLeave", function(self)
      if self._hoverHL and not (self.HasFocus and self:HasFocus()) then
        self._hoverHL:Hide()
      end
    end)
    box:HookScript("OnEditFocusGained", function(self)
      if self._hoverHL then self._hoverHL:Show() end
    end)
    box:HookScript("OnEditFocusLost", function(self)
      if self._hoverHL and not (self.IsMouseOver and self:IsMouseOver()) then
        self._hoverHL:Hide()
      end
    end)
  end

  local combineLabel = lootPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  combineLabel:SetPoint("TOPLEFT", hideLootBtn, "BOTTOMLEFT", 2, -10)
  combineLabel:SetText("Loot In Line")

  local combineBox = CreateFrame("EditBox", nil, lootPanel, "InputBoxTemplate")
  combineBox:SetSize(46, 20)
  combineBox:SetPoint("LEFT", combineLabel, "RIGHT", 8, 0)
  StripInputBoxBorder(combineBox)
  AddEditBoxHover(combineBox)
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
  outputDD:SetPoint("LEFT", outputLabel, "RIGHT", 10, -2)
  UIDropDownMenu_SetWidth(outputDD, 64)

  local function ShortenChatWindowName(name)
    name = tostring(name or "")
    if name == "" then return name end
    name = name:gsub("%s*%b()", "")
    name = name:gsub("%s+$", "")
    if name == "" then return "" end
    if #name > 18 then
      name = name:sub(1, 15) .. "..."
    end
    return name
  end

  local function GetChatWindowLabel(i)
    local name = GetChatWindowInfo and GetChatWindowInfo(i)
    if not name or name == "" then name = "Chat " .. i end
    name = ShortenChatWindowName(name)
    if name == "" then name = "Chat " .. i end
    return string.format("%d: %s", i, name)
  end

  local function CompactDropDown(dd, width)
    if not dd then return end
    local w = tonumber(width) or 100
    if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(dd, w) end

    local ddName = dd.GetName and dd:GetName() or nil
    local left = dd.Left or (ddName and _G and rawget(_G, ddName .. "Left"))
    local middle = dd.Middle or (ddName and _G and rawget(_G, ddName .. "Middle"))
    local right = dd.Right or (ddName and _G and rawget(_G, ddName .. "Right"))
    if left and left.Hide then left:Hide() end
    if middle and middle.Hide then middle:Hide() end
    if right and right.Hide then right:Hide() end

    local text = dd.Text or (ddName and _G and rawget(_G, ddName .. "Text"))
    if text and text.SetJustifyH then
      text:SetJustifyH("LEFT")
      if text.ClearAllPoints then text:ClearAllPoints() end
      text:SetPoint("LEFT", dd, "LEFT", 8, 2)
      text:SetPoint("RIGHT", dd, "RIGHT", -22, 2)
    end

    if dd.Button then
      dd.Button:ClearAllPoints()
      dd.Button:SetAllPoints(dd)
      if dd.Button.SetHitRectInsets then
        dd.Button:SetHitRectInsets(0, 0, 0, 0)
      end

      if not dd.Button._hoverHL then
        local hl = dd.Button:CreateTexture(nil, "HIGHLIGHT")
        hl:SetColorTexture(1, 1, 1, 0.06)
        hl:SetAllPoints(dd.Button)
        hl:Hide()
        dd.Button._hoverHL = hl

        dd.Button:HookScript("OnEnter", function(self)
          if self._hoverHL then self._hoverHL:Show() end
        end)
        dd.Button:HookScript("OnLeave", function(self)
          if self._hoverHL then self._hoverHL:Hide() end
        end)
      end
    end
  end

  -- Apply compact styling to the main Output dropdown too.
  CompactDropDown(outputDD, 64)

  do
    local tddm = _G and rawget(_G, "ToggleDropDownMenu")
    local cdm = _G and rawget(_G, "CloseDropDownMenus")
    if UIDropDownMenu_Initialize and tddm then
      UIDropDownMenu_Initialize(outputDD, function(_, level)
        level = level or 1
        if level ~= 1 then return end
        EnsureDB()
        local DB = GetDB()
        if not DB then return end

        for i = 1, (NUM_CHAT_WINDOWS or 1) do
          local info = UIDropDownMenu_CreateInfo()
          info.text = GetChatWindowLabel(i)
          info.checked = (DB.outputChatFrame == i)
          info.func = function()
            EnsureDB()
            local DB2 = GetDB()
            if not DB2 then return end

            DB2.outputChatFrame = i
            UIDropDownMenu_SetSelectedID(outputDD, i)
            if UIDropDownMenu_SetText then UIDropDownMenu_SetText(outputDD, GetChatWindowLabel(i)) end
            if cdm then cdm() end
          end
          UIDropDownMenu_AddButton(info, level)
        end
      end)

      local anchor = outputDD.Button or outputDD
      if anchor and anchor.SetScript then
        anchor:SetScript("OnClick", nil)
        anchor:SetScript("OnMouseDown", function(btn)
          tddm(1, nil, outputDD, btn, 0, 0)
        end)
      end
    else
      local mu = _G and rawget(_G, "MenuUtil")
      if type(mu) == "table" and type(mu.CreateContextMenu) == "function" then
        local anchor = outputDD.Button or outputDD
        if anchor and anchor.SetScript then
          anchor:SetScript("OnClick", nil)
          anchor:SetScript("OnMouseDown", function(btn)
            mu.CreateContextMenu(btn, function(_, root)
              if root and root.CreateTitle then root:CreateTitle("Output") end
              EnsureDB()
              local DB = GetDB()
              if not DB then return end

              for i = 1, (NUM_CHAT_WINDOWS or 1) do
                local label = GetChatWindowLabel(i)
                if root and root.CreateRadio then
                  root:CreateRadio(label, function() return (DB.outputChatFrame == i) end, function()
                    EnsureDB()
                    local DB2 = GetDB()
                    if not DB2 then return end

                    DB2.outputChatFrame = i
                    if UIDropDownMenu_SetSelectedID then UIDropDownMenu_SetSelectedID(outputDD, i) end
                    if UIDropDownMenu_SetText then UIDropDownMenu_SetText(outputDD, GetChatWindowLabel(i)) end
                  end)
                elseif root and root.CreateButton then
                  root:CreateButton(label, function()
                    EnsureDB()
                    local DB2 = GetDB()
                    if not DB2 then return end

                    DB2.outputChatFrame = i
                    if UIDropDownMenu_SetSelectedID then UIDropDownMenu_SetSelectedID(outputDD, i) end
                    if UIDropDownMenu_SetText then UIDropDownMenu_SetText(outputDD, GetChatWindowLabel(i)) end
                  end)
                end
              end
            end)
          end)
        end
      end
    end
  end

  local prefixLabel = lootPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  prefixLabel:SetPoint("LEFT", outputDD, "RIGHT", 6, 2)
  prefixLabel:SetText("Prefix")

  local prefixBox = CreateFrame("EditBox", nil, lootPanel, "InputBoxTemplate")
  prefixBox:SetSize(120, 20)
  prefixBox:SetPoint("LEFT", prefixLabel, "RIGHT", 6, 0)
  StripInputBoxBorder(prefixBox)
  AddEditBoxHover(prefixBox)
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

  -- Bottom-of-tab Info moved into a popout (opened by an Info button).
  -- Use the standard right-docked popout style used elsewhere in the UI.
  local infoPopout = CreateFrame("Frame", nil, lootPanel, "BackdropTemplate")
  infoPopout:SetWidth(420)
  infoPopout:SetPoint("TOPLEFT", lootPanel, "TOPRIGHT", 0, 0)
  infoPopout:SetPoint("BOTTOMLEFT", lootPanel, "BOTTOMRIGHT", 0, 0)
  infoPopout:SetFrameLevel((lootPanel.GetFrameLevel and lootPanel:GetFrameLevel() or 0) + 50)
  infoPopout:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  infoPopout:SetBackdropColor(0, 0, 0, 0.92)
  infoPopout:Hide()

  local infoClose = CreateFrame("Button", nil, infoPopout, "UIPanelCloseButton")
  infoClose:SetPoint("TOPRIGHT", infoPopout, "TOPRIGHT", -3, -3)
  infoClose:SetScript("OnClick", function() infoPopout:Hide() end)

  local infoTitle = infoPopout:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  infoTitle:SetPoint("TOPLEFT", infoPopout, "TOPLEFT", 10, -10)
  infoTitle:SetText("Info")
  infoTitle:SetTextColor(1, 0.82, 0, 1)

  -- Other-tab format examples moved here.
  local exampleTitle = infoPopout:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  exampleTitle:SetPoint("TOPLEFT", infoTitle, "BOTTOMLEFT", 0, -10)
  exampleTitle:SetText("Achievement Format")

  local ex1 = infoPopout:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ex1:SetPoint("TOPLEFT", exampleTitle, "BOTTOMLEFT", 0, -6)
  ex1:SetJustifyH("LEFT")
  ex1:SetText("[Character] has earned the achievement [link]")

  local ex2 = infoPopout:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ex2:SetPoint("TOPLEFT", ex1, "BOTTOMLEFT", 0, -4)
  ex2:SetJustifyH("LEFT")
  ex2:SetText("Character: earned Link!")

  local xpTitle = infoPopout:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  xpTitle:SetPoint("TOPLEFT", ex2, "BOTTOMLEFT", 0, -12)
  xpTitle:SetText("Experience Format")

  local xp1 = infoPopout:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  xp1:SetPoint("TOPLEFT", xpTitle, "BOTTOMLEFT", 0, -6)
  xp1:SetJustifyH("LEFT")
  xp1:SetText("<Character> 1234 XP")

  local xp2 = infoPopout:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  xp2:SetPoint("TOPLEFT", xp1, "BOTTOMLEFT", 0, -4)
  xp2:SetJustifyH("LEFT")
  xp2:SetText("<Character> 94 XP (+47 XP) Rowdy Sparks")

  -- Supported message list (was previously a bottom scroll on the LootIt tab).
  local scroll = CreateFrame("ScrollFrame", nil, infoPopout, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", xp2, "BOTTOMLEFT", -4, -12)
  scroll:SetPoint("BOTTOMRIGHT", infoPopout, "BOTTOMRIGHT", -28, 10)

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

  -- Place Alias/Info buttons on the Reset Defaults row.
  local aliasBtn = CreateFrame("Button", nil, lootPanel, "UIPanelButtonTemplate")
  aliasBtn:SetSize(60, 20)
  aliasBtn:SetPoint("RIGHT", reset, "LEFT", -10, 0)
  aliasBtn:SetText("Alias")
  aliasBtn:SetScript("OnClick", function()
    if type(ToggleAliasPopout) == "function" then
      ToggleAliasPopout()
    end
  end)

  local infoBtn = CreateFrame("Button", nil, lootPanel, "UIPanelButtonTemplate")
  infoBtn:SetSize(60, 20)
  infoBtn:SetPoint("LEFT", reset, "RIGHT", 10, 0)
  infoBtn:SetText("Info")
  infoBtn:SetScript("OnClick", function()
    if infoPopout and infoPopout.IsShown and infoPopout:IsShown() then
      infoPopout:Hide()
    else
      RefreshSupportedList()
      infoPopout:Show()
    end
  end)

  -- Other-tab controls moved to bottom of the LootIt tab.
  do
    local EnsureDB = env.EnsureDB or function() end
    local GetDB = env.GetDB or function() return _G and rawget(_G, "fr0z3nUI_LootItDB") end
    local ApplyFilters = env.ApplyFilters or function() end

    local function SetToggleText(btn, label, on)
      if not (btn and btn._fs and btn._fs.SetText and btn._fs.SetTextColor) then return end
      btn._fs:SetText(label)
      if on then
        local c = rawget(_G, "GREEN_FONT_COLOR")
        if c and type(c.GetRGB) == "function" then
          local r, g, b = c:GetRGB()
          btn._fs:SetTextColor(r or 0.20, g or 1.00, b or 0.20, 1)
        elseif type(c) == "table" and c.r and c.g and c.b then
          btn._fs:SetTextColor(c.r, c.g, c.b, c.a or 1)
        else
          btn._fs:SetTextColor(0.20, 1.00, 0.20, 1)
        end
      else
        btn._fs:SetTextColor(0.55, 0.55, 0.55, 1)
      end
    end

    local function CreateTextToggleButton(parent, w, h)
      local b = CreateFrame("Button", nil, parent)
      b:SetSize(w or 110, h or 20)
      local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      fs:SetJustifyH("CENTER")
      fs:SetPoint("CENTER", b, "CENTER", 0, 2)
      b._fs = fs
      return b
    end

    local function GetChatWindowLabel(i)
      local name = GetChatWindowInfo and GetChatWindowInfo(i)
      if not name or name == "" then name = "Chat " .. i end
      if type(ShortenChatWindowName) == "function" then
        name = ShortenChatWindowName(name)
      end
      if name == "" then name = "Chat " .. i end
      return string.format("%d: %s", i, name)
    end

    local function SetDropDownSelection(dd, i)
      if UIDropDownMenu_SetSelectedID then
        UIDropDownMenu_SetSelectedID(dd, i)
      end
      local label = GetChatWindowLabel(i)
      if UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(dd, label)
      elseif dd and dd.Text and dd.Text.SetText then
        dd.Text:SetText(label)
      end
    end

    local function GetFallbackOtherOutputChatFrame(DB)
      return (DB and DB.other and DB.other.outputChatFrame) or (DB and DB.outputChatFrame) or 1
    end

    local function AttachChatFrameDropDown(dd, menuTitle, getValue, setValue)
      local tddm = _G and rawget(_G, "ToggleDropDownMenu")
      local cdm = _G and rawget(_G, "CloseDropDownMenus")
      if UIDropDownMenu_Initialize and tddm then
        UIDropDownMenu_Initialize(dd, function(_, level)
          level = level or 1
          if level ~= 1 then return end
          EnsureDB()
          local DB = GetDB()
          if not DB then return end

          for i = 1, (NUM_CHAT_WINDOWS or 1) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = GetChatWindowLabel(i)
            info.checked = (getValue(DB) == i)
            info.func = function()
              EnsureDB()
              local DB2 = GetDB()
              if not DB2 then return end
              setValue(DB2, i)
              SetDropDownSelection(dd, i)
              if cdm then cdm() end
            end
            UIDropDownMenu_AddButton(info, level)
          end
        end)

        local anchor = dd.Button or dd
        if anchor and anchor.SetScript then
          anchor:SetScript("OnClick", nil)
          anchor:SetScript("OnMouseDown", function(btn)
            tddm(1, nil, dd, btn, 0, 0)
          end)
        end
      else
        local mu = _G and rawget(_G, "MenuUtil")
        if type(mu) == "table" and type(mu.CreateContextMenu) == "function" then
          local anchor = dd.Button or dd
          if anchor and anchor.SetScript then
            anchor:SetScript("OnClick", nil)
            anchor:SetScript("OnMouseDown", function(btn)
              mu.CreateContextMenu(btn, function(_, root)
                if root and root.CreateTitle then root:CreateTitle(menuTitle or "Output") end
                EnsureDB()
                local DB = GetDB()
                if not DB then return end
                for i = 1, (NUM_CHAT_WINDOWS or 1) do
                  local label = GetChatWindowLabel(i)
                  if root and root.CreateRadio then
                    root:CreateRadio(label, function() return (getValue(DB) == i) end, function()
                      EnsureDB()
                      local DB2 = GetDB()
                      if not DB2 then return end
                      setValue(DB2, i)
                      SetDropDownSelection(dd, i)
                    end)
                  elseif root and root.CreateButton then
                    root:CreateButton(label, function()
                      EnsureDB()
                      local DB2 = GetDB()
                      if not DB2 then return end
                      setValue(DB2, i)
                      SetDropDownSelection(dd, i)
                    end)
                  end
                end
              end)
            end)
          end
        end
      end
    end

    local bottomRow = CreateFrame("Frame", nil, lootPanel)
    -- Keep these controls with the LootIt tab content (directly under Reset Defaults).
    -- The Debug button is anchored to the true bottom separately.
    bottomRow:SetPoint("TOPLEFT", resetRow, "BOTTOMLEFT", 0, -14)
    bottomRow:SetPoint("TOPRIGHT", resetRow, "BOTTOMRIGHT", 0, -14)
    bottomRow:SetHeight(78)

    local achBtn = CreateTextToggleButton(bottomRow, 120, 20)
    achBtn:SetPoint("BOTTOMLEFT", bottomRow, "BOTTOMLEFT", 0, 44)
    achBtn:SetScript("OnClick", function()
      EnsureDB()
      local DB = GetDB()
      if not DB then return end
      DB.other = (type(DB.other) == "table") and DB.other or {}
      DB.other.achievement = (type(DB.other.achievement) == "table") and DB.other.achievement or {}
      DB.other.achievement.enabled = not (DB.other.achievement.enabled == true)
      SetToggleText(achBtn, "Achievement", DB.other.achievement.enabled == true)
      ApplyFilters()
    end)

    local achOutputDD = CreateFrame("Frame", nil, bottomRow, "UIDropDownMenuTemplate")
    achOutputDD:ClearAllPoints()
    achOutputDD:SetPoint("LEFT", outputDD, "LEFT", 0, 0)
    achOutputDD:SetPoint("TOP", bottomRow, "TOP", 0, -8)
    CompactDropDown(achOutputDD, 64)
    AttachChatFrameDropDown(
      achOutputDD,
      "Achievement Output",
      function(DB)
        local v = DB and DB.other and DB.other.achievement and DB.other.achievement.outputChatFrame
        if v == nil then v = GetFallbackOtherOutputChatFrame(DB) end
        return v
      end,
      function(DB, i)
        DB.other = (type(DB.other) == "table") and DB.other or {}
        DB.other.achievement = (type(DB.other.achievement) == "table") and DB.other.achievement or {}
        DB.other.achievement.outputChatFrame = i
      end
    )

    local xpBtn = CreateTextToggleButton(bottomRow, 120, 20)
    xpBtn:SetPoint("TOPLEFT", achBtn, "BOTTOMLEFT", 0, -6)
    xpBtn:SetScript("OnClick", function()
      EnsureDB()
      local DB = GetDB()
      if not DB then return end
      DB.other = (type(DB.other) == "table") and DB.other or {}
      DB.other.experience = (type(DB.other.experience) == "table") and DB.other.experience or {}
      DB.other.experience.enabled = not (DB.other.experience.enabled == true)
      SetToggleText(xpBtn, "Experience", DB.other.experience.enabled == true)
      ApplyFilters()
    end)

    local xpOutputDD = CreateFrame("Frame", nil, bottomRow, "UIDropDownMenuTemplate")
    xpOutputDD:ClearAllPoints()
    xpOutputDD:SetPoint("LEFT", outputDD, "LEFT", 0, 0)
    xpOutputDD:SetPoint("TOP", bottomRow, "TOP", 0, -34)
    CompactDropDown(xpOutputDD, 64)
    AttachChatFrameDropDown(
      xpOutputDD,
      "Experience Output",
      function(DB)
        local v = DB and DB.other and DB.other.experience and DB.other.experience.outputChatFrame
        if v == nil then v = GetFallbackOtherOutputChatFrame(DB) end
        return v
      end,
      function(DB, i)
        DB.other = (type(DB.other) == "table") and DB.other or {}
        DB.other.experience = (type(DB.other.experience) == "table") and DB.other.experience or {}
        DB.other.experience.outputChatFrame = i
      end
    )

    local xpBonusBtn = CreateTextToggleButton(bottomRow, 60, 20)
    xpBonusBtn:SetPoint("LEFT", xpOutputDD, "RIGHT", 2, -2)
    xpBonusBtn:SetScript("OnEnter", function(self)
      local gt = _G and rawget(_G, "GameTooltip")
      if not (gt and gt.SetOwner and gt.SetText) then return end
      gt:SetOwner(self, "ANCHOR_RIGHT")
      gt:SetText("Bonus")
      if gt.AddLine then
        gt:AddLine("Show/hide bonus XP in the Experience output.", 1, 1, 1, true)
        gt:AddLine("When hidden, an asterisk (*) indicates bonus XP was included.", 0.75, 0.75, 0.75, true)
      end
      if gt.Show then gt:Show() end
    end)
    xpBonusBtn:SetScript("OnLeave", function()
      local gt = _G and rawget(_G, "GameTooltip")
      if gt and gt.Hide then gt:Hide() end
    end)
    xpBonusBtn:SetScript("OnClick", function()
      EnsureDB()
      local DB = GetDB()
      if not DB then return end
      DB.other = (type(DB.other) == "table") and DB.other or {}
      DB.other.experience = (type(DB.other.experience) == "table") and DB.other.experience or {}
      if DB.other.experience.showBonus == nil then DB.other.experience.showBonus = true end
      DB.other.experience.showBonus = not (DB.other.experience.showBonus == true)
      SetToggleText(xpBonusBtn, "Bonus", DB.other.experience.showBonus == true)
    end)

    local xpPosBtn = CreateFrame("Button", nil, bottomRow)
    xpPosBtn:SetSize(62, 20)
    -- Keep this fixed so shifting Bonus doesn't move it.
    xpPosBtn:SetPoint("LEFT", xpOutputDD, "RIGHT", 60, -2)

    local xpPosHL = xpPosBtn:CreateTexture(nil, "HIGHLIGHT")
    xpPosHL:SetColorTexture(1, 1, 1, 0.06)
    xpPosHL:SetAllPoints(xpPosBtn)

    local xpPosText = xpPosBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    xpPosText:SetPoint("CENTER", xpPosBtn, "CENTER", 0, 0)
    xpPosBtn._text = xpPosText

    local function RefreshXPPosButton(DB)
      if not DB then return end
      DB.other = (type(DB.other) == "table") and DB.other or {}
      DB.other.experience = (type(DB.other.experience) == "table") and DB.other.experience or {}
      local pos = tostring(DB.other.experience.xpLabelPos or "after")
      pos = pos:lower():gsub("%s+", "")
      if pos ~= "before" and pos ~= "after" then pos = "after" end
      DB.other.experience.xpLabelPos = pos

      if xpPosBtn._text then
        xpPosBtn._text:SetText((pos == "before") and "Before" or "After")
        xpPosBtn._text:SetTextColor(1, 0.82, 0, 1)
      end
    end

    xpPosBtn:SetScript("OnClick", function()
      EnsureDB()
      local DB = GetDB()
      if not DB then return end
      DB.other = (type(DB.other) == "table") and DB.other or {}
      DB.other.experience = (type(DB.other.experience) == "table") and DB.other.experience or {}

      local pos = tostring(DB.other.experience.xpLabelPos or "after")
      pos = pos:lower():gsub("%s+", "")
      if pos ~= "before" and pos ~= "after" then pos = "after" end
      DB.other.experience.xpLabelPos = (pos == "before") and "after" or "before"
      RefreshXPPosButton(DB)
    end)

    local profBtn = CreateTextToggleButton(bottomRow, 120, 20)
    profBtn:SetPoint("TOPLEFT", xpBtn, "BOTTOMLEFT", 0, -6)
    profBtn:SetScript("OnClick", function()
      EnsureDB()
      local DB = GetDB()
      if not DB then return end
      DB.other = (type(DB.other) == "table") and DB.other or {}
      DB.other.profession = (type(DB.other.profession) == "table") and DB.other.profession or {}
      DB.other.profession.enabled = not (DB.other.profession.enabled == true)
      SetToggleText(profBtn, "Professions", DB.other.profession.enabled == true)
      ApplyFilters()
    end)

    local profOutputDD = CreateFrame("Frame", nil, bottomRow, "UIDropDownMenuTemplate")
    profOutputDD:ClearAllPoints()
    profOutputDD:SetPoint("LEFT", outputDD, "LEFT", 0, 0)
    profOutputDD:SetPoint("TOP", bottomRow, "TOP", 0, -60)
    CompactDropDown(profOutputDD, 64)
    AttachChatFrameDropDown(
      profOutputDD,
      "Profession Output",
      function(DB)
        local v = DB and DB.other and DB.other.profession and DB.other.profession.outputChatFrame
        if v == nil then v = GetFallbackOtherOutputChatFrame(DB) end
        return v
      end,
      function(DB, i)
        DB.other = (type(DB.other) == "table") and DB.other or {}
        DB.other.profession = (type(DB.other.profession) == "table") and DB.other.profession or {}
        DB.other.profession.outputChatFrame = i
      end
    )

    local xpDebugBtn = CreateFrame("Button", nil, lootPanel, "UIPanelButtonTemplate")
    -- Match Tax tab Debug sizing/feel (short button)
    xpDebugBtn:SetSize(68, 20)
    -- True bottom of the LootIt tab (avoid covering the main Reload UI button on the frame).
    xpDebugBtn:SetPoint("BOTTOMLEFT", lootPanel, "BOTTOMLEFT", 0, 0)
    xpDebugBtn._fs = (xpDebugBtn.GetFontString and xpDebugBtn:GetFontString()) or nil
    if not xpDebugBtn._fs then
      local fs = xpDebugBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      fs:SetPoint("CENTER", xpDebugBtn, "CENTER", 0, 0)
      xpDebugBtn._fs = fs
    end

    local function SetXPDebugState(DB)
      local on = (DB and DB.debugCapture) == true
      SetToggleText(xpDebugBtn, "Debug", on)
    end

    xpDebugBtn:SetScript("OnClick", function()
      EnsureDB()
      local DB = GetDB()
      if not DB then return end
      DB.debugCapture = not (DB.debugCapture == true)
      SetXPDebugState(DB)
    end)

    local function RefreshOtherButtons(DB)
      DB.other = (type(DB.other) == "table") and DB.other or {}
      DB.other.achievement = (type(DB.other.achievement) == "table") and DB.other.achievement or {}
      DB.other.experience = (type(DB.other.experience) == "table") and DB.other.experience or {}
      DB.other.profession = (type(DB.other.profession) == "table") and DB.other.profession or {}

      SetToggleText(achBtn, "Achievement", DB.other.achievement.enabled == true)
      SetToggleText(xpBtn, "Experience", DB.other.experience.enabled == true)
      SetToggleText(profBtn, "Professions", DB.other.profession.enabled == true)

      local outA = DB.other.achievement.outputChatFrame
      if outA == nil then outA = GetFallbackOtherOutputChatFrame(DB) end
      SetDropDownSelection(achOutputDD, outA or 1)

      local outX = DB.other.experience.outputChatFrame
      if outX == nil then outX = GetFallbackOtherOutputChatFrame(DB) end
      SetDropDownSelection(xpOutputDD, outX or 1)

      if DB.other.experience.showBonus == nil then DB.other.experience.showBonus = true end
      SetToggleText(xpBonusBtn, "Bonus", DB.other.experience.showBonus == true)
      RefreshXPPosButton(DB)

      local outP = DB.other.profession.outputChatFrame
      if outP == nil then outP = GetFallbackOtherOutputChatFrame(DB) end
      SetDropDownSelection(profOutputDD, outP or 1)

      SetXPDebugState(DB)
    end

    lootPanel._refreshOtherButtons = RefreshOtherButtons
  end

  lootPanel.Refresh = function()
    EnsureDB()
    local DB = GetDB()
    if not DB then return end

    RefreshHideLootButton()
    SetCheckBoxChecked(echo, DB.echoItem)
    RefreshQualityButtons()
    SetCheckBoxChecked(selfName, DB.showSelfNameAlways)
    RefreshIlvlButtons()

    combineBox:SetText(tostring(DB.lootCombineCount or 1))
    combineCur:SetOn(DB.lootCombineIncludeCurrency)
    combineGold:SetOn(DB.lootCombineIncludeGold)
    RefreshCombineModeButtons()

    RefreshMoneyButtons()

    UIDropDownMenu_SetSelectedID(outputDD, DB.outputChatFrame or 1)
    if UIDropDownMenu_SetText then UIDropDownMenu_SetText(outputDD, GetChatWindowLabel(DB.outputChatFrame or 1)) end
    prefixBox:SetText(DB.echoPrefix or "")

    if lootPanel._refreshOtherButtons then
      lootPanel._refreshOtherButtons(DB)
    end

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
