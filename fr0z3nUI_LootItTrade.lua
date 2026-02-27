local LI = fr0z3nUI_LootIt or {}
fr0z3nUI_LootIt = LI

LI.Trade = LI.Trade or {}

function LI.Trade.BuildTab(depositPanel)
  if not depositPanel then return end

  local function Print(msg)
    if LI and type(LI.Print) == "function" then
      LI.Print(msg)
    end
  end

  local function DepositCfgAcc()
    if LI and type(LI.DepositCfgAcc) == "function" then
      return LI.DepositCfgAcc()
    end
    return {}
  end

  local function DepositCfgChar()
    if LI and type(LI.DepositCfgChar) == "function" then
      return LI.DepositCfgChar()
    end
    return {}
  end

  local function GetCurrentRealmKey()
    local rn = (type(GetRealmName) == "function") and GetRealmName() or nil
    rn = (type(rn) == "string" and rn ~= "") and rn or ""
    return rn
  end

  local modeBtn = CreateFrame("Button", nil, depositPanel)
  modeBtn:SetSize(240, 28)
  modeBtn:SetPoint("TOP", depositPanel, "TOP", 0, -12)

  local modeBtnText = modeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  modeBtnText:SetPoint("CENTER", modeBtn, "CENTER", 0, 0)

  local function SetFontStringSize(fs, size)
    if not (fs and fs.GetFont and fs.SetFont) then return end
    local font, _, flags = fs:GetFont()
    if type(font) ~= "string" or font == "" then
      font = "Fonts\\FRIZQT__.TTF"
    end
    fs:SetFont(font, size, flags)
  end
  SetFontStringSize(modeBtnText, 18)

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

  local function SetTradeMode(mode)
    local cfg = DepositCfgAcc()
    cfg.tradeMode = NormalizeTradeMode(mode)
  end

  local function RefreshModeButton()
    local m = GetTradeMode()
    local txt = (m == "buy") and "Purchase Item" or ((m == "sell") and "Sell Item" or "Deposit Item")
    modeBtnText:SetText(txt)
    if modeBtnText and modeBtnText.SetTextColor then
      if m == "deposit" then
        modeBtnText:SetTextColor(1.0, 0.82, 0.0, 1)
      else
        modeBtnText:SetTextColor(0.85, 0.85, 0.85, 1)
      end
    end
  end

  modeBtn:SetScript("OnClick", function()
    local cur = GetTradeMode()
    local nextMode = (cur == "deposit") and "buy" or ((cur == "buy") and "sell" or "deposit")
    SetTradeMode(nextMode)
    RefreshModeButton()
    if depositPanel and depositPanel._RefreshModeUI then
      depositPanel:_RefreshModeUI()
    end
  end)
  modeBtn:SetScript("OnEnter", function(self)
    if modeBtnText and modeBtnText.SetTextColor then
      modeBtnText:SetTextColor(1, 1, 1, 1)
    end
    if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Click to Change")
    GameTooltip:Show()
  end)
  modeBtn:SetScript("OnLeave", function()
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    RefreshModeButton()
  end)

  local function BumpFont(fs, delta)
    if not (fs and fs.GetFont and fs.SetFont) then return end
    local fontPath, fontSize, fontFlags = fs:GetFont()
    if fontPath and fontSize then
      fs:SetFont(fontPath, fontSize + (delta or 0), fontFlags)
    end
  end

  local edit = CreateFrame("EditBox", nil, depositPanel, "InputBoxTemplate")
  edit:SetSize(210, 38)
  edit:SetPoint("TOP", modeBtn, "BOTTOM", 0, -18)
  edit:SetAutoFocus(false)
  edit:SetMaxLetters(10)
  edit:SetTextInsets(6, 6, 0, 0)
  edit:SetJustifyH("CENTER")
  if edit.SetJustifyV then edit:SetJustifyV("MIDDLE") end
  if edit.SetNumeric then edit:SetNumeric(true) end
  if edit.EnableMouse then edit:EnableMouse(true) end
  if edit.GetFont and edit.SetFont then
    local fontPath, _, fontFlags = edit:GetFont()
    if fontPath then edit:SetFont(fontPath, 16, fontFlags) end
  end

  local function HideEditBoxFrame(box)
    if not box or not box.GetRegions then return end
    for i = 1, select("#", box:GetRegions()) do
      local region = select(i, box:GetRegions())
      if region and region.Hide and region.GetObjectType and region:GetObjectType() == "Texture" then
        region:Hide()
      end
    end
  end
  HideEditBoxFrame(edit)

  local placeholder = depositPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  placeholder:SetPoint("CENTER", edit, "CENTER", 0, 0)
  placeholder:SetText("Enter ItemID")
  placeholder:SetTextColor(1, 1, 1, 0.35)

  local function UpdatePlaceholder()
    local txt = edit:GetText() or ""
    local hasText = txt ~= ""
    local focused = edit.HasFocus and edit:HasFocus() or false
    placeholder:SetShown((not hasText) and (not focused))
  end

  local SetStatus = function(_) end

  edit:SetScript("OnEditFocusGained", function()
    placeholder:Hide()
    SetStatus("")
  end)
  edit:SetScript("OnEditFocusLost", function() UpdatePlaceholder() end)
  if edit.HookScript then
    edit:HookScript("OnTextChanged", function()
      UpdatePlaceholder()
      SetStatus("")
    end)
  end

  local textArea = CreateFrame("Frame", nil, depositPanel)
  textArea:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", 0, -2)
  textArea:SetPoint("TOPRIGHT", edit, "BOTTOMRIGHT", 0, -2)
  textArea:SetPoint("BOTTOM", depositPanel, "BOTTOM", 0, 130)
  if textArea.SetClipsChildren then textArea:SetClipsChildren(true) end

  local nameLabel = depositPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  nameLabel:SetPoint("TOP", textArea, "TOP", 0, 0)
  nameLabel:SetPoint("LEFT", textArea, "LEFT", 0, 0)
  nameLabel:SetPoint("RIGHT", textArea, "RIGHT", 0, 0)
  nameLabel:SetJustifyH("CENTER")
  nameLabel:SetWordWrap(true)
  nameLabel:SetText("")
  BumpFont(nameLabel, 1)

  local stackLabel = depositPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  stackLabel:SetPoint("TOP", nameLabel, "BOTTOM", 0, -2)
  stackLabel:SetPoint("LEFT", textArea, "LEFT", 0, 0)
  stackLabel:SetPoint("RIGHT", textArea, "RIGHT", 0, 0)
  stackLabel:SetJustifyH("CENTER")
  stackLabel:SetWordWrap(true)
  stackLabel:SetText("")

  local reasonLabel = depositPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  reasonLabel:SetPoint("TOP", stackLabel, "BOTTOM", 0, -2)
  reasonLabel:SetPoint("LEFT", textArea, "LEFT", 0, 0)
  reasonLabel:SetPoint("RIGHT", textArea, "RIGHT", 0, 0)
  reasonLabel:SetJustifyH("CENTER")
  reasonLabel:SetWordWrap(true)
  reasonLabel:SetText("")
  BumpFont(reasonLabel, 1)

  local BTN_W, BTN_H = 110, 22
  local BTN_GAP = 12
  local ROW_Y = 84

  local btnChar = CreateFrame("Button", nil, depositPanel, "UIPanelButtonTemplate")
  btnChar:SetSize(BTN_W, BTN_H)
  btnChar:SetPoint("BOTTOM", depositPanel, "BOTTOM", -(BTN_W + BTN_GAP), ROW_Y)
  btnChar:SetText("Character")
  if btnChar.RegisterForClicks then btnChar:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
  btnChar:Disable()

  local btnRealm = CreateFrame("Button", nil, depositPanel, "UIPanelButtonTemplate")
  btnRealm:SetSize(BTN_W, BTN_H)
  btnRealm:SetPoint("BOTTOM", depositPanel, "BOTTOM", (BTN_W + BTN_GAP), ROW_Y)
  btnRealm:SetText("Realm")
  if btnRealm.RegisterForClicks then btnRealm:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
  btnRealm:Disable()

  local btnAcc = CreateFrame("Button", nil, depositPanel, "UIPanelButtonTemplate")
  btnAcc:SetSize(BTN_W, BTN_H)
  btnAcc:SetPoint("BOTTOM", depositPanel, "BOTTOM", 0, ROW_Y)
  btnAcc:SetText("Account")
  if btnAcc.RegisterForClicks then btnAcc:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
  btnAcc:Disable()

  local statusLabel = depositPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  statusLabel:SetPoint("TOP", btnAcc, "BOTTOM", 0, -6)
  statusLabel:SetJustifyH("CENTER")
  statusLabel:SetText("")
  statusLabel:Hide()

  SetStatus = function(msg)
    msg = tostring(msg or "")
    if msg == "" then
      statusLabel:SetText("")
      statusLabel:Hide()
      return
    end
    statusLabel:SetText("|cff00ff00" .. msg .. "|r")
    statusLabel:Show()
  end

  local bankBtn = CreateFrame("Button", nil, depositPanel, "UIPanelButtonTemplate")
  bankBtn:SetSize(BTN_W, BTN_H)
  bankBtn:SetPoint("BOTTOM", depositPanel, "BOTTOM", -((BTN_W + BTN_GAP) / 2), ROW_Y + BTN_H + 2)
  bankBtn:SetText("Bank")

  local guildTabBtn = CreateFrame("Button", nil, depositPanel, "UIPanelButtonTemplate")
  guildTabBtn:SetSize(BTN_W, BTN_H)
  guildTabBtn:SetPoint("BOTTOM", depositPanel, "BOTTOM", ((BTN_W + BTN_GAP) / 2), ROW_Y + BTN_H + 2)
  guildTabBtn:SetText("Current")
  if guildTabBtn.RegisterForClicks then guildTabBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp") end

  -- Guild enable/disable list (account-wide)
  local guildListBtn = CreateFrame("Button", nil, depositPanel, "UIPanelButtonTemplate")
  guildListBtn:SetSize(90, 22)
  guildListBtn:SetPoint("TOP", bankBtn, "BOTTOM", 0, -6)
  guildListBtn:SetText("Guild")

  local guildPop = CreateFrame("Frame", nil, depositPanel, "BackdropTemplate")
  -- Pop out from the left side of the window.
  guildPop:SetPoint("TOPRIGHT", depositPanel, "TOPLEFT", -8, -24)
  guildPop:SetSize(240, 220)
  guildPop:SetFrameStrata("DIALOG")
  guildPop:Hide()

  if guildPop.SetBackdrop then
    guildPop:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      tile = true,
      tileSize = 32,
      insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
  end

  local guildPopTitle = guildPop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  guildPopTitle:SetPoint("TOPLEFT", guildPop, "TOPLEFT", 14, -12)
  guildPopTitle:SetText("Detected Guilds")

  local guildPopClose = CreateFrame("Button", nil, guildPop, "UIPanelCloseButton")
  guildPopClose:SetPoint("TOPRIGHT", guildPop, "TOPRIGHT", -4, -4)

  local listFrame = CreateFrame("Frame", nil, guildPop)
  listFrame:SetPoint("TOPLEFT", guildPop, "TOPLEFT", 12, -34)
  listFrame:SetPoint("BOTTOMRIGHT", guildPop, "BOTTOMRIGHT", -12, 12)

  local function GetGuildRecords()
    local cfg = DepositCfgAcc()
    if not cfg then return {}, {} end
    cfg.guildsSeen = (type(cfg.guildsSeen) == "table") and cfg.guildsSeen or {}
    cfg.guildEnabled = (type(cfg.guildEnabled) == "table") and cfg.guildEnabled or {}
    return cfg.guildsSeen, cfg.guildEnabled
  end

  local function BuildGuildList()
    local seen, enabled = GetGuildRecords()

    guildPop._items = guildPop._items or {}
    local items = guildPop._items

    local keys = {}
    for k, v in pairs(seen) do
      if type(k) == "string" and k ~= "" and type(v) == "table" then
        keys[#keys + 1] = k
      end
    end
    table.sort(keys, function(a, b)
      local va, vb = seen[a], seen[b]
      local na = (type(va.name) == "string" and va.name) or a
      local nb = (type(vb.name) == "string" and vb.name) or b
      na = na:lower()
      nb = nb:lower()
      if na == nb then
        return a:lower() < b:lower()
      end
      return na < nb
    end)

    local rowH = 22
    local maxRows = 8
    local rows = #keys
    if rows < 1 then rows = 1 end
    local visibleRows = rows
    if visibleRows > maxRows then visibleRows = maxRows end

    for i = 1, #items do
      items[i]:Hide()
    end

    if #keys == 0 then
      local cb = items[1]
      if not cb then
        cb = CreateFrame("CheckButton", nil, listFrame, "UICheckButtonTemplate")
        items[1] = cb
      end
      cb:ClearAllPoints()
      cb:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, 0)
      cb.Text:SetText("No guilds detected yet")
      cb:SetChecked(true)
      cb:Disable()
      cb:Show()
      guildPop:SetHeight(120)
      return
    end

    for i = 1, #keys do
      local key = keys[i]
      local rec = seen[key] or {}
      local name = (type(rec.name) == "string" and rec.name ~= "") and rec.name or key
      local realm = (type(rec.realm) == "string" and rec.realm ~= "") and rec.realm or ""
      local label = name
      if realm ~= "" then
        label = label .. " (" .. realm .. ")"
      end

      local cb = items[i]
      if not cb then
        cb = CreateFrame("CheckButton", nil, listFrame, "UICheckButtonTemplate")
        items[i] = cb
      end
      cb:Enable()
      cb:ClearAllPoints()
      cb:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, -((i - 1) * rowH))
      cb.Text:SetText(label)

      local on = enabled[key]
      if on == nil then on = true end
      cb:SetChecked(on == true)

      cb:SetScript("OnClick", function(self)
        local cfg = DepositCfgAcc()
        if not cfg then return end
        cfg.guildEnabled = (type(cfg.guildEnabled) == "table") and cfg.guildEnabled or {}
        cfg.guildEnabled[key] = (self:GetChecked() == true)
      end)

      cb:Show()
    end

    local height = 70 + (visibleRows * rowH)
    if height < 140 then height = 140 end
    guildPop:SetHeight(height)
  end

  guildListBtn:SetScript("OnClick", function()
    if guildPop:IsShown() then
      guildPop:Hide()
      return
    end
    BuildGuildList()
    guildPop:Show()
  end)

  depositPanel:HookScript("OnHide", function()
    if guildPop and guildPop.Hide then guildPop:Hide() end
  end)

  -- Buy/Sell mode controls
  local targetBox = CreateFrame("EditBox", nil, depositPanel, "InputBoxTemplate")
  targetBox:SetSize(BTN_W, BTN_H)
  targetBox:SetPoint("BOTTOM", depositPanel, "BOTTOM", -((BTN_W + BTN_GAP) / 2), ROW_Y + BTN_H + 2)
  targetBox:SetAutoFocus(false)
  targetBox:SetNumeric(true)
  targetBox:SetMaxLetters(4)
  targetBox:SetJustifyH("CENTER")
  if targetBox.SetTextInsets then targetBox:SetTextInsets(6, 6, 0, 0) end
  targetBox:Hide()

  local targetPH = depositPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  targetPH:SetPoint("CENTER", targetBox, "CENTER", 0, 0)
  targetPH:SetText("Target")
  targetPH:SetTextColor(1, 1, 1, 0.35)
  targetPH:Hide()

  local function UpdateTargetPlaceholder()
    local txt = targetBox:GetText() or ""
    local hasText = txt ~= ""
    local focused = targetBox.HasFocus and targetBox:HasFocus() or false
    targetPH:SetShown((targetBox.IsShown and targetBox:IsShown() or false) and (not hasText) and (not focused))
  end
  targetBox:SetScript("OnEditFocusGained", function() targetPH:Hide() end)
  targetBox:SetScript("OnEditFocusLost", function() UpdateTargetPlaceholder() end)

  local restockBtn = CreateFrame("Button", nil, depositPanel, "UIPanelButtonTemplate")
  restockBtn:SetSize(BTN_W, BTN_H)
  restockBtn:SetPoint("BOTTOM", depositPanel, "BOTTOM", ((BTN_W + BTN_GAP) / 2), ROW_Y + BTN_H + 2)
  restockBtn:SetText("Restock")
  restockBtn:Hide()

  local function _GetColorRGB(c)
    if type(c) ~= "table" then return nil end
    if type(c.GetRGB) == "function" then
      local ok, r, g, b = pcall(c.GetRGB, c)
      if ok and r and g and b then return r, g, b end
    end
    if c.r and c.g and c.b then
      return c.r, c.g, c.b
    end
    if c[1] and c[2] and c[3] then
      return c[1], c[2], c[3]
    end
    return nil
  end

  local function SetRestockBtnVisual(on)
    if not (restockBtn and restockBtn.SetText) then return end
    restockBtn._liRestockOn = (on == true)
    restockBtn:SetText("Restock")

    -- Prefer font objects: UIPanelButtonTemplate's OnEnter/OnLeave will otherwise
    -- overwrite text colors and make the button look permanently yellow.
    if restockBtn.SetNormalFontObject then
      local gfNormal = rawget(_G, "GameFontNormal")
      local gfDis = rawget(_G, "GameFontDisable")
      if gfDis and restockBtn.SetDisabledFontObject then
        restockBtn:SetDisabledFontObject(gfDis)
      end
      if on == true then
        -- ON: yellow
        if gfNormal then restockBtn:SetNormalFontObject(gfNormal) end
        if gfNormal and restockBtn.SetHighlightFontObject then restockBtn:SetHighlightFontObject(gfNormal) end
      else
        -- OFF: grey
        if gfDis then restockBtn:SetNormalFontObject(gfDis) end
        if gfDis and restockBtn.SetHighlightFontObject then restockBtn:SetHighlightFontObject(gfDis) end
      end
      return
    end

    local fs = (restockBtn.GetFontString and restockBtn:GetFontString())
    if not (fs and fs.SetTextColor) then return end

    -- NOTE: UIPanelButtonTemplate uses yellow-ish text by default (GameFontNormal),
    -- so embedding a yellow color code makes it look permanently "on".
    -- Use Blizzard's standard font colors to make on/off obvious.
    local enabled = (restockBtn.IsEnabled and restockBtn:IsEnabled()) and true or false
    local r, g, b
    if not enabled then
      r, g, b = _GetColorRGB(rawget(_G, "DISABLED_FONT_COLOR") or rawget(_G, "GRAY_FONT_COLOR"))
    else
      local onColor = rawget(_G, "NORMAL_FONT_COLOR")
      local offColor = rawget(_G, "GRAY_FONT_COLOR") or rawget(_G, "DISABLED_FONT_COLOR")
      r, g, b = _GetColorRGB((on == true) and onColor or offColor)
    end
    if r and g and b then
      fs:SetTextColor(r, g, b, 1)
    end
  end

  -- Keep visual state consistent when other code enables/disables the button.
  if restockBtn and restockBtn.HookScript then
    restockBtn:HookScript("OnEnable", function() SetRestockBtnVisual(restockBtn._liRestockOn == true) end)
    restockBtn:HookScript("OnDisable", function() SetRestockBtnVisual(restockBtn._liRestockOn == true) end)
  end

  local actionBtn = CreateFrame("Button", nil, depositPanel, "UIPanelButtonTemplate")
  actionBtn:SetSize(90, 22)
  actionBtn:SetPoint("BOTTOMLEFT", depositPanel, "BOTTOMLEFT", 10, 10)
  actionBtn:SetText("Deposit")
  actionBtn:Hide()

  -- Keep amount (Deposit mode): withdraw up to this amount after deposit.
  local keepBox = CreateFrame("EditBox", nil, depositPanel, "InputBoxTemplate")
  keepBox:SetSize(44, BTN_H)
  keepBox:SetAutoFocus(false)
  keepBox:SetNumeric(true)
  keepBox:SetMaxLetters(4)
  keepBox:SetJustifyH("CENTER")
  if keepBox.SetTextInsets then keepBox:SetTextInsets(6, 6, 0, 0) end
  do
    local left = keepBox.Left
    local middle = keepBox.Middle
    local right = keepBox.Right
    if left and left.Hide then left:Hide() end
    if middle and middle.Hide then middle:Hide() end
    if right and right.Hide then right:Hide() end
  end
  keepBox:Hide()

  -- Stack Pull toggle (Deposit mode): optional workaround to reduce stacking issues.
  local spBtn = CreateFrame("Button", nil, depositPanel, "UIPanelButtonTemplate")
  spBtn:SetSize(28, BTN_H)
  spBtn:SetText("SP")
  spBtn:Hide()

  local keepPH = depositPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  keepPH:SetPoint("CENTER", keepBox, "CENTER", 0, 0)
  keepPH:SetText("Keep")
  keepPH:SetTextColor(1, 1, 1, 0.35)
  keepPH:Hide()

  local function UpdateKeepPlaceholder()
    local txt = keepBox:GetText() or ""
    local hasText = txt ~= ""
    local focused = keepBox.HasFocus and keepBox:HasFocus() or false
    keepPH:SetShown((keepBox.IsShown and keepBox:IsShown() or false) and (not hasText) and (not focused))
  end
  keepBox:SetScript("OnEditFocusGained", function() keepPH:Hide() end)
  keepBox:SetScript("OnEditFocusLost", function() UpdateKeepPlaceholder() end)
  if keepBox.HookScript then
    keepBox:HookScript("OnTextChanged", function() UpdateKeepPlaceholder() end)
  end

  local function ApplyKeepFromBox()
    local cfg = DepositCfgAcc()
    if not cfg then return end

    local id = tonumber(edit and edit.GetText and edit:GetText() or "")
    if not id or id <= 0 then
      UpdateKeepPlaceholder()
      return
    end
    cfg.keepByItem = (type(cfg.keepByItem) == "table") and cfg.keepByItem or {}

    local v = tonumber(keepBox:GetText() or "")
    v = v and math.floor(v) or 0
    if v < 1 then v = 0 end
    if v > 9999 then v = 9999 end
    if v == 0 then
      cfg.keepByItem[id] = nil
    else
      cfg.keepByItem[id] = v
    end
    if v == 0 then
      keepBox:SetText("")
    else
      keepBox:SetText(tostring(v))
    end
    UpdateKeepPlaceholder()
  end

  keepBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    ApplyKeepFromBox()
  end)
  keepBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    ApplyKeepFromBox()
  end)

  -- Place Guild button above the Deposit button.
  if guildListBtn and guildListBtn.ClearAllPoints and guildListBtn.SetPoint then
    guildListBtn:ClearAllPoints()
    if actionBtn and actionBtn.GetWidth and actionBtn.GetHeight and guildListBtn.SetSize then
      guildListBtn:SetSize(actionBtn:GetWidth(), actionBtn:GetHeight())
    end
    guildListBtn:SetPoint("BOTTOMLEFT", actionBtn, "TOPLEFT", 0, 6)
  end

  local foodDiffBox = CreateFrame("EditBox", nil, depositPanel, "InputBoxTemplate")
  foodDiffBox:SetSize(44, BTN_H)
  foodDiffBox:SetPoint("LEFT", actionBtn, "RIGHT", 6, 0)
  foodDiffBox:SetAutoFocus(false)
  foodDiffBox:SetNumeric(true)
  foodDiffBox:SetMaxLetters(2)
  foodDiffBox:SetJustifyH("CENTER")
  if foodDiffBox.SetTextInsets then foodDiffBox:SetTextInsets(6, 6, 0, 0) end
  do
    local left = foodDiffBox.Left
    local middle = foodDiffBox.Middle
    local right = foodDiffBox.Right
    if left and left.Hide then left:Hide() end
    if middle and middle.Hide then middle:Hide() end
    if right and right.Hide then right:Hide() end
  end
  foodDiffBox:Hide()

  local foodDiffPH = depositPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  foodDiffPH:SetPoint("CENTER", foodDiffBox, "CENTER", 0, 0)
  foodDiffPH:SetText("10")
  foodDiffPH:SetTextColor(1, 1, 1, 0.35)
  foodDiffPH:Hide()

  local function UpdateFoodDiffPlaceholder()
    local txt = foodDiffBox:GetText() or ""
    local hasText = txt ~= ""
    local focused = foodDiffBox.HasFocus and foodDiffBox:HasFocus() or false
    foodDiffPH:SetShown((foodDiffBox.IsShown and foodDiffBox:IsShown() or false) and (not hasText) and (not focused))
  end
  foodDiffBox:SetScript("OnEditFocusGained", function() foodDiffPH:Hide() end)
  foodDiffBox:SetScript("OnEditFocusLost", function() UpdateFoodDiffPlaceholder() end)

  local function SetButtonColor(btn, label, state)
    if not btn then return end
    local s = tostring(state or "inactive")
    if s == "active" then
      btn:SetText("|cff00ff00" .. label .. "|r")
      return
    end
    if s == "disabled" then
      btn:SetText("|cffffa500" .. label .. "|r")
      return
    end
    btn:SetText("|cffffff00" .. label .. "|r")
  end

  local function Tip(frame, title, line1, line2)
    if not (frame and frame.SetScript) then return end
    frame:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(title or "")
      if line1 then GameTooltip:AddLine(line1, 0.85, 0.85, 0.85, true) end
      if line2 then GameTooltip:AddLine(line2, 0.85, 0.85, 0.85, true) end
      GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
      if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    end)
  end

  Tip(bankBtn, "List Target", "Affects where entries are added/managed; deposit uses the currently open bank.", "Cycles: Bank / Guild / Warbank")
  Tip(guildTabBtn, "Guild Tab", "Left-click: cycle tabs (or pick random)", "Right-click: toggle Random; disabled on Warbank")
  Tip(keepBox, "Keep (Deposit)", "For this item: if bags have less than Keep, withdraw the difference", "Empty/0 disables")
  Tip(spBtn, "SP (Stack Pull)", "Per-item toggle: pull partial stacks before depositing", "Default: Off")
  Tip(restockBtn, "Restock", "When enabled: restock matches by Use: lines", "(Lets different foods count toward the same target)")
  Tip(foodDiffBox, "Food level diff", "Sell old food <= player level - diff", "Default: 10")

  local function IsStackPullEnabledForID(id)
    id = tonumber(id)
    if not id or id <= 0 then return false end
    local cfg = DepositCfgAcc()
    return (cfg and type(cfg.stackPullByItem) == "table" and cfg.stackPullByItem[id] == true) and true or false
  end

  local function RefreshSPBtn()
    if not spBtn then return end
    local id = tonumber(edit and edit.GetText and edit:GetText() or "")
    local on = IsStackPullEnabledForID(id)
    if on then
      spBtn:SetText("|cff00ff00SP|r")
    else
      spBtn:SetText("|cff999999SP|r")
    end
  end

  spBtn:SetScript("OnClick", function()
    local cfg = DepositCfgAcc()
    if not cfg then return end
    local id = tonumber(edit and edit.GetText and edit:GetText() or "")
    if not id or id <= 0 then
      RefreshSPBtn()
      return
    end
    cfg.stackPullByItem = (type(cfg.stackPullByItem) == "table") and cfg.stackPullByItem or {}
    if cfg.stackPullByItem[id] == true then
      cfg.stackPullByItem[id] = nil
    else
      cfg.stackPullByItem[id] = true
    end
    RefreshSPBtn()
  end)

  local function SetDynamicTip(frame, get)
    if not (frame and frame.SetScript) then return end
    frame:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      local title, line1, line2, line3 = nil, nil, nil, nil
      if type(get) == "function" then
        title, line1, line2, line3 = get()
      end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(title or "")
      if line1 then GameTooltip:AddLine(line1, 0.85, 0.85, 0.85, true) end
      if line2 then GameTooltip:AddLine(line2, 0.85, 0.85, 0.85, true) end
      if line3 then GameTooltip:AddLine(line3, 0.85, 0.85, 0.85, true) end
      GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
      if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    end)
  end

  SetDynamicTip(actionBtn, function()
    local mode = GetTradeMode()
    if mode == "sell" then
      local cfgAcc = DepositCfgAcc()
      local cfgChar = DepositCfgChar()
      local onAcc = (cfgAcc and cfgAcc.sellFoodEnabledAcc == true) and true or false
      local onChar = (not onAcc) and (cfgChar and cfgChar.sellFoodEnabledChar == true) and true or false
      local state = onAcc and "On Acc" or (onChar and "On" or "Off")
      local d = (cfgAcc and tonumber(cfgAcc.sellFoodLevelDiff)) or 10
      d = d and math.floor(d) or 10
      if d < 1 then d = 1 end
      if d > 80 then d = 80 end
      return "Food selling", "State: " .. state, "Threshold: <= player-" .. tostring(d), "Cycles: Off -> On -> On Acc"
    end
    if mode == "deposit" then
      local cfg = DepositCfgAcc()
      local on = not (cfg and cfg.showButton == false)
      return "Deposit", on and "State: On" or "State: Off", "Toggles the on-screen Deposit button", nil
    end
    return "Action", "No action for this mode.", nil, nil
  end)

  SetDynamicTip(targetBox, function()
    local mode = GetTradeMode()
    if mode == "buy" then
      return "Target (Buy)", "Buy up to this count in bags.", "Must be > 0."
    end
    if mode == "sell" then
      return "Target (Sell)", "Sell down to this count in bags.", "0 = sell all."
    end
    return "Target", "Used in Buy/Sell modes.", nil
  end)

  local function GetItemNameSafe(id)
    id = tonumber(id)
    if not id then return nil end
    if C_Item then
      if type(C_Item.GetItemNameByID) == "function" then
        local ok, name = pcall(C_Item.GetItemNameByID, id)
        if ok and type(name) == "string" and name ~= "" then
          return name
        end
      end
      if type(C_Item.GetItemInfo) == "function" then
        local ok, name = pcall(C_Item.GetItemInfo, id)
        name = ok and name or nil
        if type(name) == "string" and name ~= "" then
          return name
        end
      end
    end
    return nil
  end

  local _depositScanTip
  local function ScanItemTooltipText(link, scanText)
    if type(link) ~= "string" or link == "" then return end
    if not (CreateFrame and UIParent) then return end
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

  local function GetDepositItemFlags(id)
    id = tonumber(id)
    if not id or id <= 0 then return {} end

    local out = {
      soulbound = false,
      warbound = false,
      maxStack = nil,
    }

    if C_Item and type(C_Item.GetItemMaxStackSizeByID) == "function" then
      local ok, v = pcall(C_Item.GetItemMaxStackSizeByID, id)
      v = ok and tonumber(v) or nil
      if v and v > 0 then out.maxStack = math.floor(v) end
    end

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
      local ok, tip = pcall(C_TooltipInfo.GetHyperlink, "item:" .. tostring(id))
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
      ScanItemTooltipText("item:" .. tostring(id), scanText)
    end

    return out
  end

  local RefreshBankAndTabButtons

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

  local function EnsureRealmRuleTable(cfg, mode)
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

  local function EnsureAccDisableRealmTable(cfg, mode)
    local rk = GetCurrentRealmKey()
    if rk == "" then return nil, nil end

    if mode == "buy" then
      cfg.buyItemsAccDisableRealm = (type(cfg.buyItemsAccDisableRealm) == "table") and cfg.buyItemsAccDisableRealm or {}
      cfg.buyItemsAccDisableRealm[rk] = (type(cfg.buyItemsAccDisableRealm[rk]) == "table") and cfg.buyItemsAccDisableRealm[rk] or {}
      return cfg.buyItemsAccDisableRealm[rk], rk
    end
    if mode == "sell" then
      cfg.sellItemsAccDisableRealm = (type(cfg.sellItemsAccDisableRealm) == "table") and cfg.sellItemsAccDisableRealm or {}
      cfg.sellItemsAccDisableRealm[rk] = (type(cfg.sellItemsAccDisableRealm[rk]) == "table") and cfg.sellItemsAccDisableRealm[rk] or {}
      return cfg.sellItemsAccDisableRealm[rk], rk
    end

    cfg.itemsAccDisableRealm = (type(cfg.itemsAccDisableRealm) == "table") and cfg.itemsAccDisableRealm or {}
    cfg.itemsAccDisableRealm[rk] = (type(cfg.itemsAccDisableRealm[rk]) == "table") and cfg.itemsAccDisableRealm[rk] or {}
    return cfg.itemsAccDisableRealm[rk], rk
  end

  local function EnsureRealmDisabledTable(cfg, mode)
    local rk = GetCurrentRealmKey()
    if rk == "" then return nil, nil end

    if mode == "buy" then
      cfg.buyItemsRealmDisabled = (type(cfg.buyItemsRealmDisabled) == "table") and cfg.buyItemsRealmDisabled or {}
      cfg.buyItemsRealmDisabled[rk] = (type(cfg.buyItemsRealmDisabled[rk]) == "table") and cfg.buyItemsRealmDisabled[rk] or {}
      return cfg.buyItemsRealmDisabled[rk], rk
    end
    if mode == "sell" then
      cfg.sellItemsRealmDisabled = (type(cfg.sellItemsRealmDisabled) == "table") and cfg.sellItemsRealmDisabled or {}
      cfg.sellItemsRealmDisabled[rk] = (type(cfg.sellItemsRealmDisabled[rk]) == "table") and cfg.sellItemsRealmDisabled[rk] or {}
      return cfg.sellItemsRealmDisabled[rk], rk
    end

    cfg.itemsRealmDisabled = (type(cfg.itemsRealmDisabled) == "table") and cfg.itemsRealmDisabled or {}
    cfg.itemsRealmDisabled[rk] = (type(cfg.itemsRealmDisabled[rk]) == "table") and cfg.itemsRealmDisabled[rk] or {}
    return cfg.itemsRealmDisabled[rk], rk
  end

  local function GetScopeStores(mode)
    local cfg = DepositCfgAcc()
    local ch = DepositCfgChar()
    local realmTbl, realmKey = EnsureRealmRuleTable(cfg, mode)
    local accDisableRealmTbl = nil
    local realmDisabledTbl = nil
    if realmKey and realmKey ~= "" then
      accDisableRealmTbl = EnsureAccDisableRealmTable(cfg, mode)
      realmDisabledTbl = EnsureRealmDisabledTable(cfg, mode)
    end

    if mode == "buy" then
      return {
        cfg = cfg,
        ch = ch,
        accTbl = cfg.buyItemsAcc,
        accDisabledTbl = cfg.buyItemsAccDisabled,
        accDisableRealmTbl = accDisableRealmTbl,
        realmTbl = realmTbl,
        realmKey = realmKey,
        realmDisabledTbl = realmDisabledTbl,
        charTbl = ch.buyItemsChar,
        charDisabledTbl = ch.buyItemsCharDisabled,
        disableAccTbl = ch.buyDisableAcc,
        disableRealmTbl = ch.buyDisableRealm,
      }
    end
    if mode == "sell" then
      return {
        cfg = cfg,
        ch = ch,
        accTbl = cfg.sellItemsAcc,
        accDisabledTbl = cfg.sellItemsAccDisabled,
        accDisableRealmTbl = accDisableRealmTbl,
        realmTbl = realmTbl,
        realmKey = realmKey,
        realmDisabledTbl = realmDisabledTbl,
        charTbl = ch.sellItemsChar,
        charDisabledTbl = ch.sellItemsCharDisabled,
        disableAccTbl = ch.sellDisableAcc,
        disableRealmTbl = ch.sellDisableRealm,
      }
    end

    return {
      cfg = cfg,
      ch = ch,
      accTbl = cfg.itemsAcc,
      accDisabledTbl = cfg.itemsAccDisabled,
      accDisableRealmTbl = accDisableRealmTbl,
      realmTbl = realmTbl,
      realmKey = realmKey,
      realmDisabledTbl = realmDisabledTbl,
      charTbl = ch.itemsChar,
      charDisabledTbl = ch.itemsCharDisabled,
      disableAccTbl = ch.disableAcc,
      disableRealmTbl = ch.disableRealm,
    }
  end

  local UpdateScopeButtons

  local function ResetTradeEntry(clearStatus)
    if clearStatus then
      SetStatus("")
    end

    depositPanel._liScopeID = nil
    depositPanel._pendingRestockID = nil
    depositPanel._pendingRestock = nil

    if keepBox and keepBox.IsShown and keepBox:IsShown() then
      if keepBox.ClearFocus then keepBox:ClearFocus() end
      if ApplyKeepFromBox then
        pcall(ApplyKeepFromBox)
      end
    end

    if edit and edit.SetText then
      edit:SetText("")
    end
    if edit and edit.ClearFocus then
      edit:ClearFocus()
    end

    if nameLabel and nameLabel.SetText then
      nameLabel:SetText("")
    end
    if stackLabel and stackLabel.SetText then
      stackLabel:SetText("")
    end
    if reasonLabel and reasonLabel.SetText then
      reasonLabel:SetText("")
    end

    if UpdatePlaceholder then
      pcall(UpdatePlaceholder)
    end
    if UpdateKeepPlaceholder then
      pcall(UpdateKeepPlaceholder)
    end
    if UpdateTargetPlaceholder then
      pcall(UpdateTargetPlaceholder)
    end
    if UpdateFoodDiffPlaceholder then
      pcall(UpdateFoodDiffPlaceholder)
    end

    if RefreshBankAndTabButtons then
      pcall(RefreshBankAndTabButtons)
    end

    if UpdateScopeButtons then
      UpdateScopeButtons(nil)
    end
  end

  UpdateScopeButtons = function(id)
    depositPanel._liScopeID = id

    local mode = GetTradeMode()
    local stores = GetScopeStores(mode)

    id = tonumber(id)
    if not id or id <= 0 then
      btnAcc:Disable()
      btnChar:Disable()
      btnRealm:Disable()
      if btnAcc and btnAcc.SetText then btnAcc:SetText("Account") end
      if btnRealm and btnRealm.SetText then btnRealm:SetText("Realm") end
      if btnChar and btnChar.SetText then btnChar:SetText("Character") end
      stackLabel:SetText("")
      reasonLabel:SetText("")
      restockBtn:Disable()
      SetRestockBtnVisual(false)

      if keepBox and keepBox.SetText then
        keepBox:SetText("")
      end
      if UpdateKeepPlaceholder then
        pcall(UpdateKeepPlaceholder)
      end
      return
    end

    if mode == "deposit" and keepBox and keepBox.SetText then
      local cfg = DepositCfgAcc()
      local v = (cfg and type(cfg.keepByItem) == "table") and tonumber(cfg.keepByItem[id]) or 0
      v = v and math.floor(v) or 0
      if v < 1 then v = 0 end
      if v > 9999 then v = 9999 end
      keepBox:SetText((v > 0) and tostring(v) or "")
      if UpdateKeepPlaceholder then pcall(UpdateKeepPlaceholder) end
    end

    btnAcc:Enable()
    btnChar:Enable()
    if stores.realmKey and stores.realmKey ~= "" then
      btnRealm:Enable()
    else
      btnRealm:Disable()
    end

    local function HasRule(tbl)
      if mode == "deposit" then
        return (type(tbl) == "table" and tbl[id] == true) and true or false
      end
      return (NormalizeRule(type(tbl) == "table" and tbl[id]) ~= nil)
    end

    local hasAccRule = HasRule(stores.accTbl)
    local hasCharRule = HasRule(stores.charTbl)
    local hasRealmRule = (stores.realmKey and stores.realmKey ~= "") and HasRule(stores.realmTbl) or false

    local accDisabled = (type(stores.accDisabledTbl) == "table" and stores.accDisabledTbl[id] == true) and true or false
    local accDisabledOnRealm = (type(stores.accDisableRealmTbl) == "table" and stores.accDisableRealmTbl[id] == true) and true or false
    local accDisabledOnChar = (type(stores.disableAccTbl) == "table" and stores.disableAccTbl[id] == true) and true or false

    local realmDisabled = (type(stores.realmDisabledTbl) == "table" and stores.realmDisabledTbl[id] == true) and true or false
    local realmDisabledOnChar = (type(stores.disableRealmTbl) == "table" and stores.disableRealmTbl[id] == true) and true or false

    local charDisabled = (type(stores.charDisabledTbl) == "table" and stores.charDisabledTbl[id] == true) and true or false

    local restockOn = false
    local effectiveSource = nil
    local effectiveCount = nil
    if mode ~= "deposit" then
      local rAcc = NormalizeRule(type(stores.accTbl) == "table" and stores.accTbl[id])
      local rChar = NormalizeRule(type(stores.charTbl) == "table" and stores.charTbl[id])
      local rRealm = NormalizeRule(type(stores.realmTbl) == "table" and stores.realmTbl[id])

      -- Restock should reflect the *effective active* rule (ignores disabled rules),
      -- otherwise it can look permanently "on" even though the rule is disabled.
      if hasAccRule and (not accDisabled) and (not accDisabledOnRealm) and (not accDisabledOnChar) then
        effectiveSource = "acc"
      elseif hasRealmRule and (not realmDisabled) and (not realmDisabledOnChar) then
        effectiveSource = "realm"
      elseif hasCharRule and (not charDisabled) then
        effectiveSource = "char"
      end

      if effectiveSource == "acc" then
        restockOn = (rAcc and rAcc.restock == true) and true or false
        effectiveCount = (rAcc and rAcc.count ~= nil) and tonumber(rAcc.count) or nil
      elseif effectiveSource == "realm" then
        restockOn = (rRealm and rRealm.restock == true) and true or false
        effectiveCount = (rRealm and rRealm.count ~= nil) and tonumber(rRealm.count) or nil
      elseif effectiveSource == "char" then
        restockOn = (rChar and rChar.restock == true) and true or false
        effectiveCount = (rChar and rChar.count ~= nil) and tonumber(rChar.count) or nil
      else
        restockOn = false
        effectiveCount = nil
      end

      if (not hasAccRule) and (not hasCharRule) and (not hasRealmRule) then
        restockOn = (depositPanel._pendingRestockID == id and depositPanel._pendingRestock == true) and true or false
      end
    end

    -- Keep the Target box in sync with the effective active rule.
    -- This prevents confusing cases where a rule exists but the Target field looks empty.
    if targetBox and targetBox.SetText and (mode == "buy" or mode == "sell") then
      local n = tonumber(effectiveCount)
      if n ~= nil then
        n = math.floor(n)
        if n < 0 then n = 0 end
        if n > 9999 then n = 9999 end
      end
      targetBox:SetText((n ~= nil and n > 0) and tostring(n) or "")
      if UpdateTargetPlaceholder then pcall(UpdateTargetPlaceholder) end
    end

    local flags = GetDepositItemFlags(id)
    local bankTarget = tostring(stores.cfg.target or "bank")
    bankTarget = bankTarget:lower():gsub("%s+", "")

    if flags.warbound and bankTarget ~= "warbank" then
      stores.cfg.target = "warbank"
      if RefreshBankAndTabButtons then RefreshBankAndTabButtons() end
    end

    local canAdd = true
    do
      local warnLines = {}
      if flags.warbound then
        warnLines[#warnLines + 1] = "Warbound"
      end
      if flags.soulbound then
        warnLines[#warnLines + 1] = "Soulbound: cannot deposit"
        canAdd = false
      end

      if flags.maxStack and flags.maxStack > 1 then
        stackLabel:SetText("|cffaaaaaaMax stack: " .. tostring(flags.maxStack) .. "|r")
      else
        stackLabel:SetText("")
      end

      local lines = {}
      for i = 1, #warnLines do
        lines[#lines + 1] = "|cffffa500" .. warnLines[i] .. "|r"
      end
      reasonLabel:SetText(table.concat(lines, "\n"))
    end

    local function RequireTargetCount()
      local n = tonumber(targetBox:GetText() or "")
      n = (n ~= nil) and math.floor(n) or nil
      if mode == "buy" and (not n or n <= 0) then
        Print("Target must be > 0 for Buy.")
        return nil
      end
      if not n or n < 0 then
        Print("Enter a target count first.")
        return nil
      end
      return n
    end

    local function AddRule(tbl)
      if mode == "deposit" then
        tbl[id] = true
        return true
      end
      local n = RequireTargetCount()
      if n == nil then return false end
      tbl[id] = { count = n, restock = restockOn and true or false }
      return true
    end

    local function RemoveRule(tbl)
      if type(tbl) ~= "table" then return end
      tbl[id] = nil
    end

    local function ClearPerID(t)
      if type(t) == "table" then t[id] = nil end
    end

    local function EnsureTable(t)
      return (type(t) == "table") and t or {}
    end

    local function RemoveAccountRuleAndDisables(st)
      RemoveRule(st.accTbl)
      ClearPerID(st.accDisabledTbl)
      ClearPerID(st.accDisableRealmTbl)
      ClearPerID(st.disableAccTbl)
    end

    local function RemoveRealmRuleAndDisables(st)
      RemoveRule(st.realmTbl)
      ClearPerID(st.realmDisabledTbl)
      ClearPerID(st.disableRealmTbl)
    end

    local function RemoveCharRuleAndDisables(st)
      RemoveRule(st.charTbl)
      ClearPerID(st.charDisabledTbl)
    end

    local function GetAccState()
      if not hasAccRule then return "inactive" end
      return accDisabled and "disabled" or "active"
    end

    local function GetRealmState()
      if hasRealmRule then
        return realmDisabled and "disabled" or "active"
      end
      if hasAccRule and not accDisabled then
        return accDisabledOnRealm and "disabled" or "active"
      end
      return "inactive"
    end

    local function GetCharState()
      if hasCharRule then
        return charDisabled and "disabled" or "active"
      end
      if hasAccRule and not accDisabled then
        return accDisabledOnChar and "disabled" or "active"
      end
      if hasRealmRule and not realmDisabled then
        return realmDisabledOnChar and "disabled" or "active"
      end
      return "inactive"
    end

    local function GetEffectiveSource()
      if hasAccRule and not accDisabled and not accDisabledOnRealm and not accDisabledOnChar then
        return "acc"
      end
      if hasRealmRule and not realmDisabled and not realmDisabledOnChar then
        return "realm"
      end
      if hasCharRule and not charDisabled then
        return "char"
      end
      return nil
    end

    local effectiveSource = GetEffectiveSource()

    if (not hasAccRule) and (not hasCharRule) and (not hasRealmRule) and (canAdd == false) then
      btnAcc:Disable()
      btnChar:Disable()
      if stores.realmKey and stores.realmKey ~= "" then
        btnRealm:Disable()
      end
    end

    SetButtonColor(btnAcc, "Account", GetAccState())
    SetButtonColor(btnRealm, "Realm", GetRealmState())
    SetButtonColor(btnChar, "Character", GetCharState())

    btnChar:SetScript("OnClick", function(_, mouseButton)
      local st = GetScopeStores(GetTradeMode())

      if hasCharRule then
        if mouseButton == "RightButton" then
          RemoveCharRuleAndDisables(st)
          Print("Removed from Character " .. GetTradeMode() .. " list: " .. (GetItemNameSafe(id) or tostring(id)))
        else
          st.charDisabledTbl = EnsureTable(st.charDisabledTbl)
          if st.charDisabledTbl[id] == true then
            st.charDisabledTbl[id] = nil
            Print("Enabled on this character: " .. (GetItemNameSafe(id) or tostring(id)))
          else
            st.charDisabledTbl[id] = true
            Print("Disabled on this character: " .. (GetItemNameSafe(id) or tostring(id)))
          end
        end
        ResetTradeEntry(true)
        return
      end

      if hasAccRule and not accDisabled then
        st.disableAccTbl = EnsureTable(st.disableAccTbl)
        if st.disableAccTbl[id] == true then
          st.disableAccTbl[id] = nil
          Print("Enabled on this character: " .. (GetItemNameSafe(id) or tostring(id)))
        else
          st.disableAccTbl[id] = true
          Print("Disabled on this character: " .. (GetItemNameSafe(id) or tostring(id)))
        end
        ResetTradeEntry(true)
        return
      end

      if hasRealmRule and not realmDisabled then
        st.disableRealmTbl = EnsureTable(st.disableRealmTbl)
        if st.disableRealmTbl[id] == true then
          st.disableRealmTbl[id] = nil
          Print("Enabled on this character: " .. (GetItemNameSafe(id) or tostring(id)))
        else
          st.disableRealmTbl[id] = true
          Print("Disabled on this character: " .. (GetItemNameSafe(id) or tostring(id)))
        end
        ResetTradeEntry(true)
        return
      end

      if canAdd == false then
        ResetTradeEntry(true)
        return
      end

      st.charTbl = EnsureTable(st.charTbl)
      if not AddRule(st.charTbl) then
        ResetTradeEntry(true)
        return
      end
      Print("Added to Character " .. GetTradeMode() .. " list: " .. (GetItemNameSafe(id) or tostring(id)))
      ResetTradeEntry(false)
      SetStatus("Successfully added")
    end)

    btnAcc:SetScript("OnClick", function(_, mouseButton)
      local st = GetScopeStores(GetTradeMode())

      if hasAccRule then
        if mouseButton == "RightButton" then
          RemoveAccountRuleAndDisables(st)
          Print("Removed from Account " .. GetTradeMode() .. " list: " .. (GetItemNameSafe(id) or tostring(id)))
        else
          st.accDisabledTbl = EnsureTable(st.accDisabledTbl)
          if st.accDisabledTbl[id] == true then
            st.accDisabledTbl[id] = nil
            Print("Enabled account-wide: " .. (GetItemNameSafe(id) or tostring(id)))
          else
            st.accDisabledTbl[id] = true
            Print("Disabled account-wide: " .. (GetItemNameSafe(id) or tostring(id)))
          end
        end
        ResetTradeEntry(true)
        return
      end

      if hasRealmRule then
        RemoveRealmRuleAndDisables(st)
      end
      if hasCharRule then
        RemoveCharRuleAndDisables(st)
      end

      if canAdd == false then
        ResetTradeEntry(true)
        return
      end

      st.accTbl = EnsureTable(st.accTbl)
      if not AddRule(st.accTbl) then
        ResetTradeEntry(true)
        return
      end

      ClearPerID(st.accDisabledTbl)
      ClearPerID(st.accDisableRealmTbl)
      ClearPerID(st.disableAccTbl)
      Print("Added to Account " .. GetTradeMode() .. " list: " .. (GetItemNameSafe(id) or tostring(id)))
      ResetTradeEntry(false)
      SetStatus("Successfully added")
    end)

    btnRealm:SetScript("OnClick", function(_, mouseButton)
      local st = GetScopeStores(GetTradeMode())
      if not (st.realmKey and st.realmKey ~= "") then return end

      if hasRealmRule then
        if mouseButton == "RightButton" then
          RemoveRealmRuleAndDisables(st)
          Print("Removed from Realm " .. GetTradeMode() .. " list: " .. (GetItemNameSafe(id) or tostring(id)))
        else
          st.realmDisabledTbl = EnsureTable(st.realmDisabledTbl)
          if st.realmDisabledTbl[id] == true then
            st.realmDisabledTbl[id] = nil
            Print("Enabled on this realm: " .. (GetItemNameSafe(id) or tostring(id)))
          else
            st.realmDisabledTbl[id] = true
            Print("Disabled on this realm: " .. (GetItemNameSafe(id) or tostring(id)))
          end
        end
        ResetTradeEntry(true)
        return
      end

      if hasAccRule and not accDisabled then
        st.accDisableRealmTbl = EnsureTable(st.accDisableRealmTbl)
        if st.accDisableRealmTbl[id] == true then
          st.accDisableRealmTbl[id] = nil
          Print("Enabled on this realm: " .. (GetItemNameSafe(id) or tostring(id)))
        else
          st.accDisableRealmTbl[id] = true
          Print("Disabled on this realm: " .. (GetItemNameSafe(id) or tostring(id)))
        end
        ResetTradeEntry(true)
        return
      end

      if hasCharRule then
        RemoveCharRuleAndDisables(st)
      end

      if canAdd == false then
        ResetTradeEntry(true)
        return
      end

      st.realmTbl = EnsureTable(st.realmTbl)
      if not AddRule(st.realmTbl) then
        ResetTradeEntry(true)
        return
      end

      ClearPerID(st.realmDisabledTbl)
      ClearPerID(st.disableRealmTbl)
      Print("Added to Realm " .. GetTradeMode() .. " list: " .. (GetItemNameSafe(id) or tostring(id)))
      ResetTradeEntry(false)
      SetStatus("Successfully added")
    end)

    SetDynamicTip(btnAcc, function()
      local st = GetScopeStores(GetTradeMode())
      local curID = tonumber(depositPanel._liScopeID)
      if not curID or curID <= 0 then
        return "Account", "Enter an ItemID first."
      end

      local aState = GetAccState()
      if aState == "inactive" then
        if hasCharRule or hasRealmRule then
          return "Account (Inactive)", "Left-click: convert to Account-wide", "(Moves from Character/Realm to Account)"
        end
        return "Account (Inactive)", "Left-click: add Account-wide"
      end
      if aState == "disabled" then
        return "Account (Disabled)", "Left-click: re-enable Account-wide", "Right-click: remove (back to Inactive)"
      end
      return "Account (Active)", "Left-click: disable Account-wide", "Click Character: disable on this character", "Click Realm: disable on this realm"
    end)

    SetDynamicTip(btnRealm, function()
      local curID = tonumber(depositPanel._liScopeID)
      if not curID or curID <= 0 then
        return "Realm", "Enter an ItemID first."
      end

      if hasRealmRule then
        local rState = GetRealmState()
        if rState == "disabled" then
          return "Realm (Disabled)", "Left-click: re-enable on this realm", "Right-click: remove from Realm"
        end
        return "Realm (Active)", "Left-click: disable on this realm", "Right-click: remove from Realm"
      end

      if hasAccRule and not accDisabled then
        if accDisabledOnRealm then
          return "Realm (Disabled)", "Account rule is disabled on this realm", "Left-click: re-enable on this realm"
        end
        return "Realm (Active)", "Account rule is active on this realm", "Left-click: disable on this realm"
      end

      if hasCharRule then
        return "Realm (Inactive)", "Left-click: move to Realm (this realm)", "(Removes from Character)"
      end
      return "Realm (Inactive)", "Left-click: add for this realm"
    end)

    SetDynamicTip(btnChar, function()
      local curID = tonumber(depositPanel._liScopeID)
      if not curID or curID <= 0 then
        return "Character", "Enter an ItemID first."
      end

      if hasCharRule then
        local cState = GetCharState()
        if cState == "disabled" then
          return "Character (Disabled)", "Left-click: re-enable on this character", "Right-click: remove from Character"
        end
        return "Character (Active)", "Left-click: disable on this character", "Right-click: remove from Character"
      end

      if hasAccRule and not accDisabled then
        if accDisabledOnChar then
          return "Character (Disabled)", "Account rule is disabled on this character", "Left-click: re-enable on this character"
        end
        return "Character (Active)", "Account rule is active on this character", "Left-click: disable on this character"
      end

      if hasRealmRule and not realmDisabled then
        if realmDisabledOnChar then
          return "Character (Disabled)", "Realm rule is disabled on this character", "Left-click: re-enable on this character"
        end
        return "Character (Active)", "Realm rule is active on this character", "Left-click: disable on this character"
      end

      if hasRealmRule and realmDisabled then
        return "Character (Inactive)", "Realm rule exists but is disabled", "Re-enable Realm first"
      end
      if hasAccRule and accDisabled then
        return "Character (Inactive)", "Account rule exists but is disabled", "Re-enable Account first"
      end
      return "Character (Inactive)", "Left-click: add for this character"
    end)

    if effectiveSource == "char" then
      -- Character scope active: clicking Account/Realm moves the rule.
      -- (Move behavior is implemented in those buttons' click handlers.)
    end

    local isBuy = (mode == "buy")
    if isBuy then
      restockBtn:Enable()
      SetRestockBtnVisual(restockOn)
    else
      restockBtn:Disable()
      SetRestockBtnVisual(false)
    end
  end

  local function NormalizeBankTarget(t)
    t = tostring(t or "")
    t = t:lower():gsub("%s+", "")
    if t == "either" then t = "bank" end
    if t == "warband" then t = "warbank" end
    if t ~= "bank" and t ~= "guild" and t ~= "warbank" then
      t = "bank"
    end
    return t
  end

  local function IsGuildBankOpen()
    local f = _G and rawget(_G, "GuildBankFrame")
    if f and f.IsShown and f:IsShown() then
      return true
    end
    return false
  end

  local _warbankInteractionOpen = false

  local function IsWarbankOpen()
    if _warbankInteractionOpen then
      return true
    end

    local candidates = {
      "AccountBankFrame",
      "AccountBankPanel",
      "WarbandBankFrame",
      "WarbandBankPanel",
    }

    for i = 1, #candidates do
      local f = _G and rawget(_G, candidates[i])
      if f and f.IsShown and f:IsShown() then
        return true
      end
    end
    return false
  end

  RefreshBankAndTabButtons = function()
    local cfg = DepositCfgAcc()
    local t = NormalizeBankTarget(cfg.target)
    cfg.target = t

    if cfg.target == "guild" then
      bankBtn:SetText("Guild")
    elseif cfg.target == "warbank" then
      bankBtn:SetText("Warbank")
    else
      bankBtn:SetText("Bank")
    end

    if cfg.target == "warbank" then
      guildTabBtn:Disable()
    else
      guildTabBtn:Enable()
    end

    local rk = GetCurrentRealmKey()
    local v = nil
    if rk ~= "" and cfg.guildTabByRealm and cfg.guildTabByRealm[rk] ~= nil then
      v = tonumber(cfg.guildTabByRealm[rk])
    end
    if v == nil then
      v = tonumber(cfg.guildTab) or 0
    end
    if not v or v < 0 then v = 0 end
    if v > 8 then v = 8 end
    v = math.floor(v)

    local isRandom = false
    if rk ~= "" and type(cfg.guildTabRandomByRealm) == "table" and cfg.guildTabRandomByRealm[rk] ~= nil then
      isRandom = (cfg.guildTabRandomByRealm[rk] == true)
    else
      isRandom = (cfg.guildTabRandom == true)
    end

    if isRandom then
      guildTabBtn:SetText("Random")
    else
      guildTabBtn:SetText((v <= 0) and "Current" or ("Tab " .. tostring(v)))
    end
  end

  do
    if depositPanel and not depositPanel._liTradeBankEvents then
      local ev = CreateFrame("Frame")
      depositPanel._liTradeBankEvents = ev

      ev:RegisterEvent("BANKFRAME_OPENED")
      ev:RegisterEvent("BANKFRAME_CLOSED")
      ev:RegisterEvent("GUILDBANKFRAME_OPENED")
      ev:RegisterEvent("GUILDBANKFRAME_CLOSED")
      ev:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
      ev:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")

      ev:SetScript("OnEvent", function(_, event, arg1)
        if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
          local it = (Enum and Enum.PlayerInteractionType) and Enum.PlayerInteractionType or nil
          local isAccountBanker = (it and it.AccountBanker and arg1 == it.AccountBanker) and true or false
          if isAccountBanker then
            _warbankInteractionOpen = (event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
          end
        end

        if RefreshBankAndTabButtons then
          RefreshBankAndTabButtons()
        end
      end)
    end
  end

  bankBtn:SetScript("OnClick", function()
    local cfg = DepositCfgAcc()
    local t = NormalizeBankTarget(cfg.target)
    local order = { "bank", "guild", "warbank" }
    local idx = 1
    for i = 1, #order do
      if order[i] == t then idx = i break end
    end
    idx = idx + 1
    if idx > #order then idx = 1 end
    cfg.target = order[idx]
    RefreshBankAndTabButtons()
  end)

  local function GetGuildTabCount()
    local n = (GetNumGuildBankTabs and GetNumGuildBankTabs()) or 8
    n = tonumber(n) or 8
    n = math.floor(n)
    if n < 1 then n = 1 end
    if n > 8 then n = 8 end
    return n
  end

  local function GetRandomFlag(cfg, rk)
    if rk ~= "" and type(cfg.guildTabRandomByRealm) == "table" and cfg.guildTabRandomByRealm[rk] ~= nil then
      return (cfg.guildTabRandomByRealm[rk] == true)
    end
    return (cfg.guildTabRandom == true)
  end

  local function SetRandomFlag(cfg, rk, flag)
    flag = (flag == true) and true or false
    if rk ~= "" then
      cfg.guildTabRandomByRealm = (type(cfg.guildTabRandomByRealm) == "table") and cfg.guildTabRandomByRealm or {}
      cfg.guildTabRandomByRealm[rk] = flag
    else
      cfg.guildTabRandom = flag
    end
  end

  local function SetGuildTabValue(cfg, rk, v)
    if rk ~= "" then
      cfg.guildTabByRealm = (type(cfg.guildTabByRealm) == "table") and cfg.guildTabByRealm or {}
      cfg.guildTabByRealm[rk] = v
    else
      cfg.guildTab = v
    end
  end

  local function GetGuildTabValue(cfg, rk)
    local v = nil
    if rk ~= "" and cfg.guildTabByRealm and cfg.guildTabByRealm[rk] ~= nil then
      v = tonumber(cfg.guildTabByRealm[rk])
    end
    if v == nil then v = tonumber(cfg.guildTab) or 0 end
    if not v or v < 0 then v = 0 end
    if v > 8 then v = 8 end
    return math.floor(v)
  end

  local function PickRandomTab(cfg, rk)
    local n = GetGuildTabCount()
    local v = math.random(1, n)
    SetGuildTabValue(cfg, rk, v)
  end

  guildTabBtn:SetScript("OnClick", function(_, button)
    local cfg = DepositCfgAcc()
    cfg.target = NormalizeBankTarget(cfg.target)
    if cfg.target == "warbank" then
      RefreshBankAndTabButtons()
      return
    end

    local rk = GetCurrentRealmKey()

    local isRandom = GetRandomFlag(cfg, rk)
    button = tostring(button or "LeftButton")

    if button == "RightButton" then
      isRandom = not isRandom
      SetRandomFlag(cfg, rk, isRandom)
      if isRandom then
        PickRandomTab(cfg, rk)
      else
        SetGuildTabValue(cfg, rk, 0)
      end
      RefreshBankAndTabButtons()
      return
    end

    if isRandom then
      PickRandomTab(cfg, rk)
      RefreshBankAndTabButtons()
      return
    end

    local v = GetGuildTabValue(cfg, rk)
    v = v + 1
    if v > 8 then
      -- After Tab 8, enter Random mode.
      SetRandomFlag(cfg, rk, true)
      PickRandomTab(cfg, rk)
    else
      SetGuildTabValue(cfg, rk, v)
    end
    RefreshBankAndTabButtons()
  end)

  local function DoValidate()
    local id = tonumber(edit:GetText() or "")
    if id and id > 0 then
      local name = GetItemNameSafe(id)
      nameLabel:SetText(name or ("ID " .. tostring(id)))
      UpdateScopeButtons(id)
    else
      nameLabel:SetText("")
      UpdateScopeButtons(nil)
    end
    if RefreshSPBtn then
      pcall(RefreshSPBtn)
    end
    UpdatePlaceholder()
  end

  edit:SetScript("OnTextChanged", function()
    DoValidate()
  end)
  edit:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    DoValidate()
  end)

  local function GetCurrentID()
    local id = tonumber(edit:GetText() or "")
    if id and id > 0 then return id end
    return nil
  end

  local function ExtractItemIDFromLink(link)
    if type(link) ~= "string" or link == "" then return nil end
    local id = link:match("Hitem:(%d+):")
    if not id then id = link:match("item:(%d+)") end
    id = id and tonumber(id) or nil
    if id and id > 0 then return id end
    return nil
  end

  local function TrySetIDFromCursor()
    if type(GetCursorInfo) ~= "function" then return false end
    local kind, a1, a2 = GetCursorInfo()
    local itemID = nil

    if kind == "item" then
      itemID = tonumber(a1) or ExtractItemIDFromLink(a2) or ExtractItemIDFromLink(a1)
    elseif kind == "merchant" then
      local idx = tonumber(a1)
      if idx and idx > 0 and type(GetMerchantItemLink) == "function" then
        local link = GetMerchantItemLink(idx)
        itemID = ExtractItemIDFromLink(link)
      end
    else
      return false
    end

    if not itemID or itemID <= 0 then return false end
    if type(ClearCursor) == "function" then
      ClearCursor()
    end
    edit:SetText(tostring(itemID))
    edit:ClearFocus()
    DoValidate()
    return true
  end

  edit:SetScript("OnReceiveDrag", function()
    TrySetIDFromCursor()
  end)
  edit:SetScript("OnMouseUp", function(_, button)
    if button ~= "LeftButton" then return end
    TrySetIDFromCursor()
  end)

  -- Let you drop onto the Trade panel too (useful for dragging from the merchant window).
  if depositPanel and depositPanel.EnableMouse then
    depositPanel:EnableMouse(true)
  end
  if depositPanel and depositPanel.SetScript then
    depositPanel:SetScript("OnMouseUp", function(_, button)
      if button ~= "LeftButton" then return end
      TrySetIDFromCursor()
    end)
  end

  local function ApplyTargetToExistingRules()
    local id = GetCurrentID()
    if not id then return end
    local mode = GetTradeMode()
    if mode == "deposit" then return end
    local stores = GetScopeStores(mode)
    local n = tonumber(targetBox:GetText() or "")
    n = (n ~= nil) and math.floor(n) or nil
    if mode == "buy" and (not n or n <= 0) then
      Print("Target must be > 0 for Buy.")
      return
    end
    if not n or n < 0 then
      Print("Enter a target count first.")
      return
    end

    local changed = false
    if NormalizeRule(stores.accTbl and stores.accTbl[id]) ~= nil then
      stores.accTbl[id] = { count = n, restock = NormalizeRule(stores.accTbl[id]).restock == true }
      changed = true
    end
    if NormalizeRule(stores.charTbl and stores.charTbl[id]) ~= nil then
      stores.charTbl[id] = { count = n, restock = NormalizeRule(stores.charTbl[id]).restock == true }
      changed = true
    end
    if NormalizeRule(type(stores.realmTbl) == "table" and stores.realmTbl[id]) ~= nil then
      stores.realmTbl[id] = { count = n, restock = NormalizeRule(stores.realmTbl[id]).restock == true }
      changed = true
    end

    if changed then
      UpdateScopeButtons(id)
    end
  end

  targetBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    ApplyTargetToExistingRules()
    UpdateTargetPlaceholder()
  end)
  targetBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    UpdateTargetPlaceholder()
  end)

  restockBtn:SetScript("OnClick", function()
    local id = GetCurrentID()
    if not id then return end
    local mode = GetTradeMode()
    if mode == "deposit" then return end
    if mode == "sell" then return end
    local stores = GetScopeStores(mode)

    local pendingRestockID = depositPanel._pendingRestockID
    local pendingRestock = depositPanel._pendingRestock
    local function TogglePendingForID(x)
      if pendingRestockID ~= x then
        pendingRestockID = x
        pendingRestock = false
      end
      pendingRestock = not pendingRestock
      depositPanel._pendingRestockID = pendingRestockID
      depositPanel._pendingRestock = pendingRestock
      return pendingRestock
    end

    local cur = false
    do
      local rAcc = NormalizeRule(stores.accTbl and stores.accTbl[id])
      local rChar = NormalizeRule(stores.charTbl and stores.charTbl[id])
      local rRealm = NormalizeRule(type(stores.realmTbl) == "table" and stores.realmTbl[id])
      cur = ((rAcc and rAcc.restock) or (rChar and rChar.restock) or (rRealm and rRealm.restock)) and true or false
    end

    local hasAnyRule = false
    do
      local rAcc = NormalizeRule(stores.accTbl and stores.accTbl[id])
      local rChar = NormalizeRule(stores.charTbl and stores.charTbl[id])
      local rRealm = NormalizeRule(type(stores.realmTbl) == "table" and stores.realmTbl[id])
      hasAnyRule = (rAcc ~= nil) or (rChar ~= nil) or (rRealm ~= nil)
    end
    if not hasAnyRule then
      local on = TogglePendingForID(id)
      SetRestockBtnVisual(on)
      UpdateScopeButtons(id)
      return
    end

    local nextVal = not cur

    local function set(tbl)
      local r = NormalizeRule(tbl and tbl[id])
      if not r then return end
      tbl[id] = { count = r.count or 0, restock = nextVal }
    end
    set(stores.accTbl)
    set(stores.charTbl)
    if type(stores.realmTbl) == "table" then set(stores.realmTbl) end

    depositPanel._pendingRestockID = id
    depositPanel._pendingRestock = nextVal

    -- Update the button immediately even if some other UI refresh is delayed.
    SetRestockBtnVisual(nextVal)

    UpdateScopeButtons(id)
  end)

  depositPanel._RefreshModeUI = function(self)
    local m = GetTradeMode()
    local isDeposit = (m == "deposit")
    local isSell = (m == "sell")
    local isBuy = (m == "buy")
    bankBtn:SetShown(isDeposit)
    guildTabBtn:SetShown(isDeposit)
    keepBox:SetShown(isDeposit)
    spBtn:SetShown(isDeposit)
    targetBox:SetShown(not isDeposit)
    restockBtn:SetShown(isBuy)
    if isBuy then restockBtn:Enable() else restockBtn:Disable() end
    actionBtn:SetShown(isDeposit or isSell)
    foodDiffBox:SetShown(isSell)
    UpdateFoodDiffPlaceholder()
    UpdateTargetPlaceholder()
    UpdateKeepPlaceholder()

    -- Ensure Restock visual state isn't stale when switching modes.
    if isBuy then
      local id = GetCurrentID()
      if id then
        UpdateScopeButtons(id)
      else
        SetRestockBtnVisual(false)
      end
    end

    if isDeposit then
      -- Bank + GBTab above the Character/Realm/Account row, with one button-height gap.
      local rowY = ROW_Y + (BTN_H * 2)
      bankBtn:ClearAllPoints()
      bankBtn:SetPoint("BOTTOMLEFT", depositPanel, "BOTTOMLEFT", 10, rowY)
      guildTabBtn:ClearAllPoints()
      guildTabBtn:SetPoint("BOTTOMRIGHT", depositPanel, "BOTTOMRIGHT", -10, rowY)
      keepBox:ClearAllPoints()
      -- Keep + SP are centered as a group.
      local spGap = 4
      local spW = (spBtn and spBtn.GetWidth and spBtn:GetWidth()) or 28
      keepBox:SetPoint("BOTTOM", depositPanel, "BOTTOM", -((spW + spGap) / 2), rowY)
      spBtn:ClearAllPoints()
      spBtn:SetPoint("LEFT", keepBox, "RIGHT", spGap, 0)

      local cfg = DepositCfgAcc()
      local id = tonumber(edit and edit.GetText and edit:GetText() or "")
      local v = (id and id > 0 and cfg and type(cfg.keepByItem) == "table") and tonumber(cfg.keepByItem[id]) or 0
      v = v and math.floor(v) or 0
      if v > 0 then
        keepBox:SetText(tostring(v))
      else
        keepBox:SetText("")
      end
      UpdateKeepPlaceholder()
      RefreshSPBtn()
    end

    if isSell then
      local cfgAcc = DepositCfgAcc()
      local cfgChar = DepositCfgChar()
      local onAcc = (cfgAcc and cfgAcc.sellFoodEnabledAcc == true) and true or false
      local onChar = (not onAcc) and (cfgChar and cfgChar.sellFoodEnabledChar == true) and true or false
      actionBtn:SetText(onAcc and "On Acc" or (onChar and "On" or "Off"))
      local d = (cfgAcc and tonumber(cfgAcc.sellFoodLevelDiff)) or 10
      d = d and math.floor(d) or 10
      if d < 1 then d = 1 end
      if d > 80 then d = 80 end
      foodDiffBox:SetText(tostring(d))
    else
      local cfg = DepositCfgAcc()
      local on = not (cfg and cfg.showButton == false)
      actionBtn:SetText(on and "|cffffd100Deposit|r" or "|cffd9d9d9Deposit|r")
    end

    local id = GetCurrentID()
    if id then
      UpdateScopeButtons(id)
    else
      UpdateScopeButtons(nil)
    end
  end

  local function SetSellFoodLevelDiffFromBox()
    local cfg = DepositCfgAcc()
    local d = tonumber(foodDiffBox:GetText() or "")
    d = d and math.floor(d) or nil
    if not d then
      d = (cfg and tonumber(cfg.sellFoodLevelDiff)) or 10
      d = d and math.floor(d) or 10
    end
    if d < 1 then d = 1 end
    if d > 80 then d = 80 end
    if cfg then
      cfg.sellFoodLevelDiff = d
    end
    foodDiffBox:SetText(tostring(d))
    UpdateFoodDiffPlaceholder()
  end

  foodDiffBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    SetSellFoodLevelDiffFromBox()
  end)
  foodDiffBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    SetSellFoodLevelDiffFromBox()
  end)

  actionBtn:SetScript("OnClick", function()
    local mode = GetTradeMode()
    if mode == "deposit" then
      local cfg = DepositCfgAcc()
      if not cfg then return end
      cfg.showButton = (cfg.showButton == false) and true or false
      if LI and type(LI.UpdateDepositButtonVisibility) == "function" then
        LI.UpdateDepositButtonVisibility()
      end
      if depositPanel and depositPanel._RefreshModeUI then
        depositPanel:_RefreshModeUI()
      end
      return
    end

    if mode ~= "sell" then return end

    SetSellFoodLevelDiffFromBox()

    local cfgAcc = DepositCfgAcc()
    local cfgChar = DepositCfgChar()
    if not (cfgAcc and cfgChar) then return end

    local onAcc = (cfgAcc.sellFoodEnabledAcc == true)
    local onChar = (not onAcc) and (cfgChar.sellFoodEnabledChar == true)

    if (not onAcc) and (not onChar) then
      cfgChar.sellFoodEnabledChar = true
      cfgAcc.sellFoodEnabledAcc = false
      Print("Food selling: On (this character)")
    elseif onChar then
      cfgChar.sellFoodEnabledChar = false
      cfgAcc.sellFoodEnabledAcc = true
      Print("Food selling: On Acc")
    else
      cfgAcc.sellFoodEnabledAcc = false
      cfgChar.sellFoodEnabledChar = false
      Print("Food selling: Off")
    end

    if depositPanel and depositPanel._RefreshModeUI then
      depositPanel:_RefreshModeUI()
    end
  end)

  -- Items list popout (Trade tab): lets you delete rules without having the item.
  do
    local parent = depositPanel.GetParent and depositPanel:GetParent() or nil
    local reloadBtn = parent and parent._reloadBtn

    if parent and reloadBtn and reloadBtn.SetPoint then
      local dbgBtn = CreateFrame("Button", nil, depositPanel, "UIPanelButtonTemplate")
      dbgBtn:SetSize(70, 22)
      dbgBtn:SetPoint("RIGHT", reloadBtn, "LEFT", -6, 0)

      local function RefreshTradeDebugBtn()
        local on = (LI and LI.Trade and LI.Trade._debugOn == true) and true or false
        dbgBtn._liDbgOn = (on == true)
        dbgBtn:SetText("Debug")

        -- Stable toggle colors (UIPanelButtonTemplate defaults to yellow).
        if dbgBtn.SetNormalFontObject then
          local gfOn = rawget(_G, "GameFontNormal")
          local gfOff = rawget(_G, "GameFontDisable")
          local gfDis = rawget(_G, "GameFontDisable")
          if gfDis and dbgBtn.SetDisabledFontObject then
            dbgBtn:SetDisabledFontObject(gfDis)
          end
          if on == true then
            if gfOn then dbgBtn:SetNormalFontObject(gfOn) end
            if gfOn and dbgBtn.SetHighlightFontObject then dbgBtn:SetHighlightFontObject(gfOn) end
          else
            if gfOff then dbgBtn:SetNormalFontObject(gfOff) end
            if gfOff and dbgBtn.SetHighlightFontObject then dbgBtn:SetHighlightFontObject(gfOff) end
          end
          return
        end

        local fs = (dbgBtn.GetFontString and dbgBtn:GetFontString())
        if fs and fs.SetTextColor then
          if on == true then
            fs:SetTextColor(1, 0.82, 0, 1)
          else
            fs:SetTextColor(0.5, 0.5, 0.5, 1)
          end
        end
      end

      RefreshTradeDebugBtn()
      dbgBtn:SetScript("OnClick", function()
        LI.Trade = LI.Trade or {}
        LI.Trade._debugOn = (LI.Trade._debugOn ~= true) and true or false
        RefreshTradeDebugBtn()
        Print("Trade debug: " .. (LI.Trade._debugOn and "On" or "Off"))
      end)

      if dbgBtn and dbgBtn.HookScript then
        dbgBtn:HookScript("OnEnable", function() RefreshTradeDebugBtn() end)
        dbgBtn:HookScript("OnDisable", function() RefreshTradeDebugBtn() end)
        dbgBtn:HookScript("OnEnter", function() RefreshTradeDebugBtn() end)
        dbgBtn:HookScript("OnLeave", function() RefreshTradeDebugBtn() end)
      end

      local itemsBtn = CreateFrame("Button", nil, depositPanel, "UIPanelButtonTemplate")
      itemsBtn:SetSize(90, 22)
      itemsBtn:SetPoint("BOTTOMRIGHT", reloadBtn, "TOPRIGHT", 0, 6)
      itemsBtn:SetText("Item")

      local itemPop = CreateFrame("Frame", nil, depositPanel, "BackdropTemplate")
      local POP_W, POP_H = 320, 360
      local POP_TOP_PAD = -10
      local POP_BOTTOM_PAD = 10
      local POP_X_PAD = -6

      local anchor = parent or depositPanel

      itemPop:SetPoint("TOPLEFT", anchor, "TOPRIGHT", POP_X_PAD, POP_TOP_PAD)
      itemPop:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", POP_X_PAD, POP_BOTTOM_PAD)
      itemPop:SetWidth(0)
      itemPop:SetClipsChildren(true)
      itemPop:Hide()

      if itemPop.SetBackdrop then
        itemPop:SetBackdrop({
          bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
          tile = true,
          tileSize = 32,
          insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
      end

      local title = itemPop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      title:SetPoint("TOPLEFT", itemPop, "TOPLEFT", 14, -12)
      title:SetText("Items")

      local subtitle = itemPop:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
      subtitle:SetText("")

      local keepLine = itemPop:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      keepLine:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -2)
      keepLine:SetText("")
      keepLine:Hide()

      local listContainer = CreateFrame("Frame", nil, itemPop)
      listContainer:SetPoint("TOPLEFT", itemPop, "TOPLEFT", 12, -56)
      listContainer:SetPoint("BOTTOMRIGHT", itemPop, "BOTTOMRIGHT", -12, 12)

      local scroll = CreateFrame("ScrollFrame", nil, itemPop, "UIPanelScrollFrameTemplate")
      scroll:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, 0)
      scroll:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", 0, 0)

      -- Hide the visible scrollbar/slider but keep scroll functionality.
      if scroll.ScrollBar then
        if scroll.ScrollBar.ScrollUpButton then scroll.ScrollBar.ScrollUpButton:Hide() end
        if scroll.ScrollBar.ScrollDownButton then scroll.ScrollBar.ScrollDownButton:Hide() end
        scroll.ScrollBar:Hide()
        scroll.ScrollBar.Show = function() end
      end

      scroll:EnableMouseWheel(true)
      scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll() or 0
        local range = self:GetVerticalScrollRange() or 0
        local step = 28
        local next = cur - (delta * step)
        if next < 0 then next = 0 end
        if next > range then next = range end
        self:SetVerticalScroll(next)
      end)

      local content = CreateFrame("Frame", nil, scroll)
      content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
      content:SetSize(1, 1)
      content:SetWidth(POP_W - 24)
      scroll:SetScrollChild(content)

      itemPop._rows = itemPop._rows or {}

      local BuildItemsList

      -- Slide animation: expand/collapse width while keeping the left edge attached
      -- to the main Trade panel.
      local function StopSlide()
        itemPop._slideActive = false
        itemPop:SetScript("OnUpdate", nil)
      end

      local function SlideToW(targetW, onDone)
        targetW = tonumber(targetW) or 0
        if targetW < 0 then targetW = 0 end
        if targetW > POP_W then targetW = POP_W end

        local from = tonumber(itemPop._slideCurW)
        if from == nil then
          from = itemPop:IsShown() and POP_W or 0
        end
        local to = targetW
        if from == to then
          if type(onDone) == "function" then pcall(onDone) end
          return
        end

        itemPop._slideActive = true
        itemPop._slideFromW = from
        itemPop._slideToW = to
        itemPop._slideStart = GetTime()
        itemPop._slideDur = 0.18

        itemPop:SetScript("OnUpdate", function(self)
          if not self._slideActive then return end
          local now = GetTime()
          local t = (now - (self._slideStart or now)) / (self._slideDur or 0.18)
          if t >= 1 then
            self._slideCurW = self._slideToW or to
            self:SetWidth(self._slideCurW)
            StopSlide()
            if type(onDone) == "function" then pcall(onDone) end
            return
          end

          if t < 0 then t = 0 end
          local e = t * t * (3 - 2 * t)
          local w = (self._slideFromW or from) + ((self._slideToW or to) - (self._slideFromW or from)) * e
          self._slideCurW = w
          self:SetWidth(w)
        end)
      end

      local function SlideShow()
        if itemPop._slideActive then StopSlide() end
        itemPop:Show()
        itemPop._slideCurW = 0
        itemPop:SetWidth(0)
        if content and content.SetWidth then
          content:SetWidth(POP_W - 24)
        end
        BuildItemsList()
        SlideToW(POP_W)
      end

      local function SlideHide()
        if not itemPop:IsShown() then return end
        if itemPop._slideActive then StopSlide() end
        SlideToW(0, function()
          itemPop:Hide()
        end)
      end

      local function ClearInTable(t, id)
        if type(t) == "table" then t[id] = nil end
      end

      local function DeleteIDFromCurrentMode(id)
        id = tonumber(id)
        if not id or id <= 0 then return end

        local mode = GetTradeMode()
        local st = GetScopeStores(mode)

        -- Remove rules.
        ClearInTable(st.accTbl, id)
        ClearInTable(st.charTbl, id)
        ClearInTable(st.realmTbl, id)

        -- Remove disable flags.
        ClearInTable(st.accDisabledTbl, id)
        ClearInTable(st.accDisableRealmTbl, id)
        ClearInTable(st.disableAccTbl, id)
        ClearInTable(st.realmDisabledTbl, id)
        ClearInTable(st.disableRealmTbl, id)
        ClearInTable(st.charDisabledTbl, id)

        -- Pending restock UI state.
        if depositPanel._pendingRestockID == id then
          depositPanel._pendingRestockID = nil
          depositPanel._pendingRestock = nil
        end

        -- Per-item keep: only clear when removing a Deposit rule.
        if mode == "deposit" then
          local cfg = DepositCfgAcc()
          if cfg and type(cfg.keepByItem) == "table" then
            cfg.keepByItem[id] = nil
          end
        end
      end

      local function HasRule(tbl, id)
        if type(tbl) ~= "table" then return false end
        if GetTradeMode() == "deposit" then
          return (tbl[id] == true)
        end
        return (tbl[id] ~= nil)
      end

      BuildItemsList = function()
        local mode = GetTradeMode()
        local st = GetScopeStores(mode)

        local ids = {}
        local info = {}

        local function mark(id, scope)
          id = tonumber(id)
          if not id or id <= 0 then return end
          ids[id] = true
          info[id] = info[id] or { acc = false, realm = false, char = false }
          info[id][scope] = true
        end

        if type(st.accTbl) == "table" then
          for id in pairs(st.accTbl) do
            if HasRule(st.accTbl, id) then mark(id, "acc") end
          end
        end
        if type(st.realmTbl) == "table" then
          for id in pairs(st.realmTbl) do
            if HasRule(st.realmTbl, id) then mark(id, "realm") end
          end
        end
        if type(st.charTbl) == "table" then
          for id in pairs(st.charTbl) do
            if HasRule(st.charTbl, id) then mark(id, "char") end
          end
        end

        local list = {}
        for id in pairs(ids) do
          list[#list + 1] = id
        end
        table.sort(list, function(a, b)
          local na = GetItemNameSafe(a) or ""
          local nb = GetItemNameSafe(b) or ""
          na = na:lower()
          nb = nb:lower()
          if na == nb then
            return a < b
          end
          if na == "" then return false end
          if nb == "" then return true end
          return na < nb
        end)

        local modeLabel = (mode == "buy") and "Buy" or ((mode == "sell") and "Sell" or "Deposit")
        subtitle:SetText(modeLabel .. " rules: " .. tostring(#list))

        keepLine:SetText("")
        keepLine:Hide()

        local rowH = 22
        local pad = 2

        for i = 1, #itemPop._rows do
          itemPop._rows[i]:Hide()
        end

        if #list == 0 then
          local row = itemPop._rows[1]
          if not row then
            row = CreateFrame("Frame", nil, content)
            row:SetHeight(rowH)
            row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            row.txt:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.txt:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            row.txt:SetJustifyH("LEFT")
            itemPop._rows[1] = row
          end
          row:ClearAllPoints()
          row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
          row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
          row.txt:SetText("No items in this list")
          row:Show()
          content:SetHeight(rowH)
          return
        end

        for i = 1, #list do
          local id = list[i]
          local row = itemPop._rows[i]
          if not row then
            row = CreateFrame("Frame", nil, content)
            row:SetHeight(rowH)

            row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.txt:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.txt:SetJustifyH("LEFT")
            row.txt:SetWordWrap(false)

            row.del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.del:SetSize(38, 18)
            row.del:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            row.del:SetText("Del")

            row.edit = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.edit:SetSize(38, 18)
            row.edit:SetPoint("RIGHT", row.del, "LEFT", -2, 0)
            row.edit:SetText("Edit")

            row.txt:SetPoint("RIGHT", row.edit, "LEFT", -6, 0)

            itemPop._rows[i] = row
          end

          row:ClearAllPoints()
          row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((i - 1) * (rowH + pad)))
          row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -((i - 1) * (rowH + pad)))

          local name = GetItemNameSafe(id) or ("ID " .. tostring(id))
          local flags = info[id] or {}
          local scopeTxt = (flags.acc and "A" or "-") .. (flags.realm and "R" or "-") .. (flags.char and "C" or "-")
          local keepTxt = ""
          if mode == "deposit" then
            local cfg = DepositCfgAcc()
            local k = (cfg and type(cfg.keepByItem) == "table") and tonumber(cfg.keepByItem[id]) or 0
            k = k and math.floor(k) or 0
            if k < 1 then k = 0 end
            if k > 9999 then k = 9999 end
            keepTxt = "  K:" .. tostring(k)
          end
          row.txt:SetText(name .. " (" .. tostring(id) .. ")  [" .. scopeTxt .. "]" .. keepTxt)

          row.del:SetScript("OnClick", function()
            DeleteIDFromCurrentMode(id)
            BuildItemsList()
            local cur = tonumber(edit and edit.GetText and edit:GetText() or "")
            if cur == id then
              ResetTradeEntry(true)
            else
              if UpdateScopeButtons then
                local keepID = tonumber(edit and edit.GetText and edit:GetText() or "")
                UpdateScopeButtons(keepID)
              end
            end
          end)

          row.edit:SetScript("OnClick", function()
            if edit and edit.SetText then
              edit:SetText(tostring(id))
            end
            if edit and edit.ClearFocus then
              edit:ClearFocus()
            end
            DoValidate()
          end)

          row:Show()
        end

        content:SetHeight(#list * (rowH + pad))
      end

      itemsBtn:SetScript("OnClick", function()
        if itemPop:IsShown() then
          SlideHide()
        else
          SlideShow()
        end
      end)

      depositPanel:HookScript("OnHide", function()
        if itemPop then
          StopSlide()
          itemPop._slideCurW = 0
          if itemPop.SetWidth then itemPop:SetWidth(0) end
          if itemPop.Hide then itemPop:Hide() end
        end
      end)
    end
  end

  depositPanel:SetScript("OnShow", function()
    RefreshBankAndTabButtons()

    RefreshModeButton()
    if depositPanel and depositPanel._RefreshModeUI then
      depositPanel:_RefreshModeUI()
    end

    DoValidate()
  end)
end
