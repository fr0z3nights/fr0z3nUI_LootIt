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

  edit:SetScript("OnEditFocusGained", function() placeholder:Hide() end)
  edit:SetScript("OnEditFocusLost", function() UpdatePlaceholder() end)
  if edit.HookScript then
    edit:HookScript("OnTextChanged", function() UpdatePlaceholder() end)
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

  local bankBtn = CreateFrame("Button", nil, depositPanel, "UIPanelButtonTemplate")
  bankBtn:SetSize(BTN_W, BTN_H)
  bankBtn:SetPoint("BOTTOM", depositPanel, "BOTTOM", -((BTN_W + BTN_GAP) / 2), ROW_Y + BTN_H + 2)
  bankBtn:SetText("Bank")

  local guildTabBtn = CreateFrame("Button", nil, depositPanel, "UIPanelButtonTemplate")
  guildTabBtn:SetSize(BTN_W, BTN_H)
  guildTabBtn:SetPoint("BOTTOM", depositPanel, "BOTTOM", ((BTN_W + BTN_GAP) / 2), ROW_Y + BTN_H + 2)
  guildTabBtn:SetText("Current")

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

  Tip(bankBtn, "Deposit Target", "Bank = whichever bank is open", "Cycles: Bank / Guild / Warbank")
  Tip(guildTabBtn, "Guild Tab", "Current / Tab 1..8", "Disabled on Warbank")
  Tip(targetBox, "Target (bags)", "Buy: buy up to target", "Sell: sell down to target (0 = sell all)")
  Tip(restockBtn, "Restock", "When enabled: also sells low-level food (<= player-10)", "Matching food is grouped by tooltip Use: lines")

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

  local function UpdateScopeButtons(id)
    depositPanel._liScopeID = id

    local mode = GetTradeMode()
    local stores = GetScopeStores(mode)

    id = tonumber(id)
    if not id or id <= 0 then
      btnAcc:Disable()
      btnChar:Disable()
      btnRealm:Disable()
      stackLabel:SetText("")
      reasonLabel:SetText("")
      restockBtn:Disable()
      return
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
    if mode ~= "deposit" then
      local rAcc = NormalizeRule(type(stores.accTbl) == "table" and stores.accTbl[id])
      local rChar = NormalizeRule(type(stores.charTbl) == "table" and stores.charTbl[id])
      local rRealm = NormalizeRule(type(stores.realmTbl) == "table" and stores.realmTbl[id])
      restockOn = ((rAcc and rAcc.restock) or (rChar and rChar.restock) or (rRealm and rRealm.restock)) and true or false
      if (not hasAccRule) and (not hasCharRule) and (not hasRealmRule) then
        restockOn = (depositPanel._pendingRestockID == id and depositPanel._pendingRestock == true) and true or false
      end
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
        UpdateScopeButtons(id)
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
        UpdateScopeButtons(id)
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
        UpdateScopeButtons(id)
        return
      end

      if canAdd == false then
        UpdateScopeButtons(id)
        return
      end

      st.charTbl = EnsureTable(st.charTbl)
      if not AddRule(st.charTbl) then
        UpdateScopeButtons(id)
        return
      end
      Print("Added to Character " .. GetTradeMode() .. " list: " .. (GetItemNameSafe(id) or tostring(id)))
      UpdateScopeButtons(id)
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
        UpdateScopeButtons(id)
        return
      end

      if hasRealmRule then
        RemoveRealmRuleAndDisables(st)
      end
      if hasCharRule then
        RemoveCharRuleAndDisables(st)
      end

      if canAdd == false then
        UpdateScopeButtons(id)
        return
      end

      st.accTbl = EnsureTable(st.accTbl)
      if not AddRule(st.accTbl) then
        UpdateScopeButtons(id)
        return
      end

      ClearPerID(st.accDisabledTbl)
      ClearPerID(st.accDisableRealmTbl)
      ClearPerID(st.disableAccTbl)
      Print("Added to Account " .. GetTradeMode() .. " list: " .. (GetItemNameSafe(id) or tostring(id)))
      UpdateScopeButtons(id)
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
        UpdateScopeButtons(id)
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
        UpdateScopeButtons(id)
        return
      end

      if hasCharRule then
        RemoveCharRuleAndDisables(st)
      end

      if canAdd == false then
        UpdateScopeButtons(id)
        return
      end

      st.realmTbl = EnsureTable(st.realmTbl)
      if not AddRule(st.realmTbl) then
        UpdateScopeButtons(id)
        return
      end

      ClearPerID(st.realmDisabledTbl)
      ClearPerID(st.disableRealmTbl)
      Print("Added to Realm " .. GetTradeMode() .. " list: " .. (GetItemNameSafe(id) or tostring(id)))
      UpdateScopeButtons(id)
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

    restockBtn:Enable()
    restockBtn:SetText(restockOn and "|cffffff00Restock|r" or "Restock")
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
    if t == "guild" and not IsGuildBankOpen() then
      t = "bank"
    elseif t == "warbank" and not IsWarbankOpen() then
      t = "bank"
    end
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
    guildTabBtn:SetText((v <= 0) and "Current" or ("Tab " .. tostring(v)))
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

  guildTabBtn:SetScript("OnClick", function()
    local cfg = DepositCfgAcc()
    cfg.target = NormalizeBankTarget(cfg.target)
    if cfg.target == "warbank" then
      RefreshBankAndTabButtons()
      return
    end

    local rk = GetCurrentRealmKey()
    local v = nil
    if rk ~= "" and cfg.guildTabByRealm and cfg.guildTabByRealm[rk] ~= nil then
      v = tonumber(cfg.guildTabByRealm[rk])
    end
    if v == nil then v = tonumber(cfg.guildTab) or 0 end
    if not v or v < 0 then v = 0 end
    if v > 8 then v = 8 end
    v = math.floor(v)
    v = v + 1
    if v > 8 then v = 0 end

    if rk ~= "" then
      cfg.guildTabByRealm = (type(cfg.guildTabByRealm) == "table") and cfg.guildTabByRealm or {}
      cfg.guildTabByRealm[rk] = v
    else
      cfg.guildTab = v
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

  local function TrySetIDFromCursor()
    if type(GetCursorInfo) ~= "function" then return false end
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" then return false end
    itemID = tonumber(itemID)
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
      TogglePendingForID(id)
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

    UpdateScopeButtons(id)
  end)

  depositPanel._RefreshModeUI = function(self)
    local m = GetTradeMode()
    local isDeposit = (m == "deposit")
    bankBtn:SetShown(isDeposit)
    guildTabBtn:SetShown(isDeposit)
    targetBox:SetShown(not isDeposit)
    restockBtn:SetShown(not isDeposit)
    if isDeposit then restockBtn:Disable() else restockBtn:Enable() end
    UpdateTargetPlaceholder()

    local id = GetCurrentID()
    if id then
      UpdateScopeButtons(id)
    else
      UpdateScopeButtons(nil)
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
