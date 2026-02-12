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
  btnChar:Disable()

  local btnRealm = CreateFrame("Button", nil, depositPanel, "UIPanelButtonTemplate")
  btnRealm:SetSize(BTN_W, BTN_H)
  btnRealm:SetPoint("BOTTOM", depositPanel, "BOTTOM", (BTN_W + BTN_GAP), ROW_Y)
  btnRealm:SetText("Realm")
  btnRealm:Disable()

  local btnAcc = CreateFrame("Button", nil, depositPanel, "UIPanelButtonTemplate")
  btnAcc:SetSize(BTN_W, BTN_H)
  btnAcc:SetPoint("BOTTOM", depositPanel, "BOTTOM", 0, ROW_Y)
  btnAcc:SetText("Account")
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

  local function SetButtonState(btn, label, isDisabled)
    if not btn then return end
    if isDisabled then
      btn:SetText("|cffffff00" .. label .. "|r")
    else
      btn:SetText("|cffff0000" .. label .. "|r")
    end
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

  local function GetScopeStores(mode)
    local cfg = DepositCfgAcc()
    local ch = DepositCfgChar()
    local realmTbl, realmKey = EnsureRealmRuleTable(cfg, mode)

    if mode == "buy" then
      return {
        cfg = cfg,
        ch = ch,
        accTbl = cfg.buyItemsAcc,
        realmTbl = realmTbl,
        realmKey = realmKey,
        charTbl = ch.buyItemsChar,
        disableAccTbl = ch.buyDisableAcc,
      }
    end
    if mode == "sell" then
      return {
        cfg = cfg,
        ch = ch,
        accTbl = cfg.sellItemsAcc,
        realmTbl = realmTbl,
        realmKey = realmKey,
        charTbl = ch.sellItemsChar,
        disableAccTbl = ch.sellDisableAcc,
      }
    end

    return {
      cfg = cfg,
      ch = ch,
      accTbl = cfg.itemsAcc,
      realmTbl = realmTbl,
      realmKey = realmKey,
      charTbl = ch.itemsChar,
      disableAccTbl = ch.disableAcc,
    }
  end

  local function UpdateScopeButtons(id)
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

    local inAcc = false
    local accDisabledOnChar = false
    local inChar = false
    local inRealm = false
    local restockOn = false

    if mode == "deposit" then
      inAcc = (stores.accTbl and stores.accTbl[id] == true) and true or false
      accDisabledOnChar = (stores.disableAccTbl and stores.disableAccTbl[id] == true) and true or false
      inChar = (stores.charTbl and stores.charTbl[id] == true) and true or false
      inRealm = (type(stores.realmTbl) == "table" and stores.realmTbl[id] == true) and true or false
    else
      inAcc = (NormalizeRule(stores.accTbl and stores.accTbl[id]) ~= nil)
      accDisabledOnChar = (stores.disableAccTbl and stores.disableAccTbl[id] == true) and true or false
      inChar = (NormalizeRule(stores.charTbl and stores.charTbl[id]) ~= nil)
      inRealm = (NormalizeRule(type(stores.realmTbl) == "table" and stores.realmTbl[id]) ~= nil)

      local rAcc = NormalizeRule(stores.accTbl and stores.accTbl[id])
      local rChar = NormalizeRule(stores.charTbl and stores.charTbl[id])
      local rRealm = NormalizeRule(type(stores.realmTbl) == "table" and stores.realmTbl[id])
      restockOn = ((rAcc and rAcc.restock) or (rChar and rChar.restock) or (rRealm and rRealm.restock)) and true or false

      if (not inAcc) and (not inChar) and (not inRealm) then
        restockOn = (depositPanel._pendingRestockID == id and depositPanel._pendingRestock == true) and true or false
      end
    end

    local flags = GetDepositItemFlags(id)
    local bankTarget = tostring(stores.cfg.target or "bank")
    bankTarget = bankTarget:lower():gsub("%s+", "")

    if flags.warbound and bankTarget ~= "warbank" then
      stores.cfg.target = "warbank"
      bankTarget = "warbank"
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
      if mode == "deposit" then
        if inAcc or inChar or inRealm then
          lines[#lines + 1] = "|cffaaaaaaAccount: Red=disable on this character, Yellow=enable, Right-click=remove. Realm: Red=remove. Character: Red=remove.|r"
        end
      else
        local tgt = tonumber(targetBox:GetText() or "")
        if tgt ~= nil then
          lines[#lines + 1] = "|cffaaaaaaTarget (bags): " .. tostring(math.floor(tgt)) .. "|r"
        end
        if inAcc or inChar or inRealm then
          lines[#lines + 1] = "|cffaaaaaaAccount: Red=disable on this character, Yellow=enable, Right-click=remove. Realm: Red=remove. Character: Red=remove.|r"
        end
      end
      reasonLabel:SetText(table.concat(lines, "\n"))
    end

    if (not inAcc) and (not inChar) and (not inRealm) and (canAdd == false) then
      btnAcc:Disable()
      btnChar:Disable()
      if stores.realmKey and stores.realmKey ~= "" then
        btnRealm:Disable()
      end
    end

    if inAcc then
      SetButtonState(btnAcc, "Account", accDisabledOnChar)
      btnAcc:SetScript("OnClick", function(_, button)
        local mode2 = GetTradeMode()
        local stores2 = GetScopeStores(mode2)
        if button == "RightButton" then
          stores2.accTbl[id] = nil
          if stores2.disableAccTbl then stores2.disableAccTbl[id] = nil end
          Print("Removed from Account " .. mode2 .. " list: " .. (GetItemNameSafe(id) or tostring(id)))
        else
          stores2.disableAccTbl = (type(stores2.disableAccTbl) == "table") and stores2.disableAccTbl or {}
          if stores2.disableAccTbl[id] == true then
            stores2.disableAccTbl[id] = nil
            Print("Enabled on this character: " .. (GetItemNameSafe(id) or tostring(id)))
          else
            stores2.disableAccTbl[id] = true
            Print("Disabled on this character: " .. (GetItemNameSafe(id) or tostring(id)))
          end
        end
        UpdateScopeButtons(id)
      end)
    else
      btnAcc:SetText("Account")
      btnAcc:SetScript("OnClick", function()
        local mode2 = GetTradeMode()
        local stores2 = GetScopeStores(mode2)
        if mode2 == "deposit" then
          stores2.accTbl[id] = true
          if stores2.disableAccTbl then stores2.disableAccTbl[id] = nil end
          Print("Added to Account deposit list: " .. (GetItemNameSafe(id) or tostring(id)))
        else
          local n = tonumber(targetBox:GetText() or "")
          n = (n ~= nil) and math.floor(n) or nil
          if mode2 == "buy" and (not n or n <= 0) then
            Print("Enter a target count first.")
            return
          end
          if not n or n < 0 then
            Print("Enter a target count first.")
            return
          end
          stores2.accTbl[id] = { count = n, restock = restockOn and true or false }
          if stores2.disableAccTbl then stores2.disableAccTbl[id] = nil end
          Print("Added to Account " .. mode2 .. " list: " .. (GetItemNameSafe(id) or tostring(id)) .. " (" .. tostring(n) .. ")")
        end
        UpdateScopeButtons(id)
      end)
    end

    if inChar then
      SetButtonState(btnChar, "Character", false)
      btnChar:SetScript("OnClick", function()
        local mode2 = GetTradeMode()
        local stores2 = GetScopeStores(mode2)
        stores2.charTbl[id] = nil
        Print("Removed from Character " .. mode2 .. " list: " .. (GetItemNameSafe(id) or tostring(id)))
        UpdateScopeButtons(id)
      end)
    else
      btnChar:SetText("Character")
      btnChar:SetScript("OnClick", function()
        local mode2 = GetTradeMode()
        local stores2 = GetScopeStores(mode2)
        if mode2 == "deposit" then
          stores2.charTbl[id] = true
          Print("Added to Character deposit list: " .. (GetItemNameSafe(id) or tostring(id)))
        else
          local n = tonumber(targetBox:GetText() or "")
          n = (n ~= nil) and math.floor(n) or nil
          if mode2 == "buy" and (not n or n <= 0) then
            Print("Enter a target count first.")
            return
          end
          if not n or n < 0 then
            Print("Enter a target count first.")
            return
          end
          stores2.charTbl[id] = { count = n, restock = restockOn and true or false }
          Print("Added to Character " .. mode2 .. " list: " .. (GetItemNameSafe(id) or tostring(id)) .. " (" .. tostring(n) .. ")")
        end
        UpdateScopeButtons(id)
      end)
    end

    if inRealm then
      SetButtonState(btnRealm, "Realm", false)
      btnRealm:SetScript("OnClick", function()
        local mode2 = GetTradeMode()
        local stores2 = GetScopeStores(mode2)
        if not (stores2.realmTbl and stores2.realmKey and stores2.realmKey ~= "") then return end
        stores2.realmTbl[id] = nil
        Print("Removed from Realm " .. mode2 .. " list: " .. (GetItemNameSafe(id) or tostring(id)))
        UpdateScopeButtons(id)
      end)
    else
      btnRealm:SetText("Realm")
      btnRealm:SetScript("OnClick", function()
        local mode2 = GetTradeMode()
        local stores2 = GetScopeStores(mode2)
        if not (stores2.realmTbl and stores2.realmKey and stores2.realmKey ~= "") then return end
        if mode2 == "deposit" then
          stores2.realmTbl[id] = true
          Print("Added to Realm deposit list: " .. (GetItemNameSafe(id) or tostring(id)))
        else
          local n = tonumber(targetBox:GetText() or "")
          n = (n ~= nil) and math.floor(n) or nil
          if mode2 == "buy" and (not n or n <= 0) then
            Print("Enter a target count first.")
            return
          end
          if not n or n < 0 then
            Print("Enter a target count first.")
            return
          end
          stores2.realmTbl[id] = { count = n, restock = restockOn and true or false }
          Print("Added to Realm " .. mode2 .. " list: " .. (GetItemNameSafe(id) or tostring(id)) .. " (" .. tostring(n) .. ")")
        end
        UpdateScopeButtons(id)
      end)
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

  RefreshBankAndTabButtons = function()
    local cfg = DepositCfgAcc()
    cfg.target = NormalizeBankTarget(cfg.target)

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
