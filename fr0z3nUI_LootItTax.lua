---@diagnostic disable: undefined-global

local LI = fr0z3nUI_LootIt or {}
fr0z3nUI_LootIt = LI

LI.Tax = LI.Tax or {}

do
  local Tax = LI.Tax

  local DB
  local CHARDB
  local Print = function(...) end

  local state = {
    merchant = { open = false, startMoney = 0, chatMoney = 0 },
    mail = { open = false, startMoney = 0, chatMoney = 0 },
  }

  local goldStr, silverStr, copperStr

  local function Clamp(v, mn, mx)
    v = tonumber(v)
    mn = tonumber(mn)
    mx = tonumber(mx)
    if not v then return mn end
    if mn and v < mn then return mn end
    if mx and v > mx then return mx end
    return v
  end

  local function EnsureMoneyStrings()
    if goldStr and silverStr and copperStr then return end

    if type(GOLD_AMOUNT) == "string" and strmatch and format then
      goldStr = strmatch(format(GOLD_AMOUNT, 20), "%d+%s(.+)")
    end
    if type(SILVER_AMOUNT) == "string" and strmatch and format then
      silverStr = strmatch(format(SILVER_AMOUNT, 20), "%d+%s(.+)")
    end
    if type(COPPER_AMOUNT) == "string" and strmatch and format then
      copperStr = strmatch(format(COPPER_AMOUNT, 20), "%d+%s(.+)")
    end

    goldStr = goldStr or ""
    silverStr = silverStr or ""
    copperStr = copperStr or ""
  end

  local function ParseMoneyFromChat(msg)
    if type(msg) ~= "string" then return 0 end
    if type(issecretvalue) == "function" and issecretvalue(msg) then return 0 end

    EnsureMoneyStrings()

    local g = 0
    local s = 0
    local c = 0

    if goldStr ~= "" then
      g = tonumber(string.match(msg, "(%d+)%s" .. goldStr)) or 0
    end
    if silverStr ~= "" then
      s = tonumber(string.match(msg, "(%d+)%s" .. silverStr)) or 0
    end
    if copperStr ~= "" then
      c = tonumber(string.match(msg, "(%d+)%s" .. copperStr)) or 0
    end

    local total = (g * (COPPER_PER_GOLD or 10000)) + (s * (COPPER_PER_SILVER or 100)) + c
    total = math.floor(tonumber(total) or 0)
    if total < 0 then total = 0 end
    return total
  end

  local function EnsureTaxDB()
    local db = DB or (_G and rawget(_G, "fr0z3nUI_LootItDB"))
    if type(db) ~= "table" then return nil end

    db.tax = (type(db.tax) == "table") and db.tax or {}
    local t = db.tax

    t.enabled = (t.enabled == true) and true or false
    t.rate = Clamp(t.rate, 0, 100) or 0
    t.quiet = (t.quiet == true) and true or false
    t.due = math.floor(tonumber(t.due) or 0)
    t.paidToDate = math.floor(tonumber(t.paidToDate) or 0)

    if t.due < 0 then t.due = 0 end
    if t.paidToDate < 0 then t.paidToDate = 0 end

    t.sources = (type(t.sources) == "table") and t.sources or {}
    if t.sources.vendor == nil then t.sources.vendor = true end
    if t.sources.questLoot == nil then t.sources.questLoot = true end
    if t.sources.systemMoney == nil then t.sources.systemMoney = false end
    if t.sources.mail == nil then t.sources.mail = true end

    if t.autoPayOnGuildBankOpen == nil then t.autoPayOnGuildBankOpen = false end

    return t
  end

  local function MoneyToString(copper)
    copper = math.floor(tonumber(copper) or 0)
    if copper < 0 then copper = 0 end
    if type(GetMoneyString) == "function" then
      local ok, res = pcall(GetMoneyString, copper)
      if ok and type(res) == "string" then
        return res
      end
    end
    return tostring(copper) .. "c"
  end

  local function AddDue(rawCopper, label)
    rawCopper = math.floor(tonumber(rawCopper) or 0)
    if rawCopper <= 0 then return end

    local t = EnsureTaxDB()
    if not t then return end
    if not t.enabled then return end

    local rate = Clamp(t.rate, 0, 100) or 0
    if rate <= 0 then return end

    local taxCopper = math.floor((rawCopper * rate / 100) + 0.5)
    if taxCopper <= 0 then return end

    t.due = math.floor((tonumber(t.due) or 0) + taxCopper)
    if t.due < 0 then t.due = 0 end

    if not t.quiet then
      Print(string.format("%s Contribution: %s", tostring(label or "Tax"), MoneyToString(taxCopper)))
    end
  end

  local function TryPayGuildBank(isAuto)
    local t = EnsureTaxDB()
    if not t then return end
    if not t.enabled then return end

    local due = math.floor(tonumber(t.due) or 0)
    if due <= 0 then return end

    if isAuto and not t.autoPayOnGuildBankOpen then
      return
    end

    local money = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
    if money < due then
      if not t.quiet then
        Print("Tax deposit failed: insufficient funds.")
      end
      return
    end

    if type(CanDepositGuildBankMoney) == "function" then
      local ok, can = pcall(CanDepositGuildBankMoney)
      if ok and can == false then
        if not t.quiet then
          Print("Tax deposit failed: cannot deposit to guild bank.")
        end
        return
      end
    end

    if type(DepositGuildBankMoney) ~= "function" then
      if not t.quiet then
        Print("Tax deposit failed: guild bank API unavailable.")
      end
      return
    end

    local toPay = due

    C_Timer.After(0.30, function()
      local ok = pcall(DepositGuildBankMoney, toPay)
      if ok then
        t.due = math.floor((tonumber(t.due) or 0) - toPay)
        if t.due < 0 then t.due = 0 end
        t.paidToDate = math.floor((tonumber(t.paidToDate) or 0) + toPay)
        if not t.quiet then
          Print(string.format("Deposited %s into the guild bank.", MoneyToString(toPay)))
        end
      else
        if not t.quiet then
          Print("Tax deposit failed.")
        end
      end
    end)
  end

  function Tax.Init(db, charDb, env)
    DB = (type(db) == "table") and db or DB
    CHARDB = (type(charDb) == "table") and charDb or CHARDB
    env = (type(env) == "table") and env or {}

    Print = env.Print or Print
    if type(Print) ~= "function" then
      Print = function(...) end
    end

    EnsureTaxDB()
  end

  function Tax.OnMerchantShow()
    state.merchant.open = true
    state.merchant.startMoney = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
    state.merchant.chatMoney = 0
  end

  function Tax.OnMerchantClosed()
    if not state.merchant.open then return end
    state.merchant.open = false

    local t = EnsureTaxDB()
    if not t then return end
    if not (t.sources and t.sources.vendor) then return end

    local nowMoney = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
    local delta = nowMoney - (tonumber(state.merchant.startMoney) or 0)

    local chatDuring = math.floor(tonumber(state.merchant.chatMoney) or 0)
    local taxable = delta - chatDuring

    if taxable > 0 then
      AddDue(taxable, "Vendor")
    end
  end

  function Tax.OnMoneyMessage(event, msg)
    local t = EnsureTaxDB()
    if not t then return end

    local allow = false
    if event == "CHAT_MSG_MONEY" then
      allow = (t.sources and t.sources.questLoot) and true or false
    elseif event == "CHAT_MSG_SYSTEM" then
      allow = (t.sources and t.sources.systemMoney) and true or false
      if allow and type(msg) == "string" then
        local m = msg:lower()
        if m:find("spent", 1, true) or m:find("pay", 1, true) or m:find("paid", 1, true) or m:find("lost", 1, true) or m:find("cost", 1, true) or m:find("repair", 1, true) then
          allow = false
        end
      end
    end

    local copper = ParseMoneyFromChat(msg)
    if copper <= 0 then return end

    if state.merchant.open then
      state.merchant.chatMoney = math.floor((tonumber(state.merchant.chatMoney) or 0) + copper)
    end
    if state.mail.open then
      state.mail.chatMoney = math.floor((tonumber(state.mail.chatMoney) or 0) + copper)
    end

    if allow then
      AddDue(copper, "Quest & Loot")
    end
  end

  function Tax.OnInteraction(isShow, interactionType)
    local it = (Enum and Enum.PlayerInteractionType) and Enum.PlayerInteractionType or nil
    if not it then return end

    if interactionType == it.MailInfo then
      if isShow then
        state.mail.open = true
        state.mail.startMoney = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
        state.mail.chatMoney = 0
      else
        if not state.mail.open then return end
        state.mail.open = false

        local t = EnsureTaxDB()
        if not t then return end
        if not (t.sources and t.sources.mail) then return end

        local nowMoney = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
        local delta = nowMoney - (tonumber(state.mail.startMoney) or 0)

        local chatDuring = math.floor(tonumber(state.mail.chatMoney) or 0)
        local taxable = delta - chatDuring

        if taxable > 0 then
          AddDue(taxable, "Mail")
        end
      end
      return
    end

    if interactionType == it.GuildBanker then
      if isShow then
        TryPayGuildBank(true)
      end
      return
    end
  end

  function Tax.PayNow()
    TryPayGuildBank(false)
  end

  function Tax.ClearDue()
    local t = EnsureTaxDB()
    if not t then return end
    t.due = 0
  end

  function Tax.BuildTab(panel, env)
    if not panel then return end
    if panel._taxBuilt then return end
    panel._taxBuilt = true

    env = env or {}

    local EnsureDB = env.EnsureDB or function() end
    local GetDB = env.GetDB or function() return _G and rawget(_G, "fr0z3nUI_LootItDB") end

    local clampFn = env.Clamp
    if type(clampFn) ~= "function" then
      clampFn = Clamp
    end

    local SetCheckBoxText = env.SetCheckBoxText or LI.SetCheckBoxText or function() end

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)
    title:SetText("Tax")

    local dueFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dueFS:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)

    local paidFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    paidFS:SetPoint("TOPLEFT", dueFS, "BOTTOMLEFT", 0, -6)

    local slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", paidFS, "BOTTOMLEFT", 0, -18)
    slider:SetMinMaxValues(0, 100)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(220)

    local sliderName = (slider and slider.GetName and slider:GetName())
    local sliderLow = (sliderName and _G and rawget(_G, sliderName .. "Low")) or slider.Low or slider.low
    local sliderHigh = (sliderName and _G and rawget(_G, sliderName .. "High")) or slider.High or slider.high
    local sliderText = (sliderName and _G and rawget(_G, sliderName .. "Text")) or slider.Text or slider.text
    if sliderLow and sliderLow.SetText then sliderLow:SetText("0%") end
    if sliderHigh and sliderHigh.SetText then sliderHigh:SetText("100%") end
    if sliderText and sliderText.SetText then sliderText:SetText("Rate") end

    local quietCB = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    quietCB:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -12)
    SetCheckBoxText(quietCB, "Quiet")

    local vendorCB = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    vendorCB:SetPoint("TOPLEFT", quietCB, "BOTTOMLEFT", 0, -6)
    SetCheckBoxText(vendorCB, "Vendor")

    local questCB = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    questCB:SetPoint("TOPLEFT", vendorCB, "BOTTOMLEFT", 0, -6)
    SetCheckBoxText(questCB, "Quest & Loot")

    local mailCB = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    mailCB:SetPoint("TOPLEFT", questCB, "BOTTOMLEFT", 0, -6)
    SetCheckBoxText(mailCB, "Mail")

    local systemCB = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    systemCB:SetPoint("TOPLEFT", mailCB, "BOTTOMLEFT", 0, -6)
    SetCheckBoxText(systemCB, "System Money (risky)")

    local autoPayCB = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    autoPayCB:SetPoint("TOPLEFT", systemCB, "BOTTOMLEFT", 0, -10)
    SetCheckBoxText(autoPayCB, "Auto-pay on Guild Bank open")

    local payBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    payBtn:SetPoint("TOPLEFT", autoPayCB, "BOTTOMLEFT", 0, -14)
    payBtn:SetSize(120, 22)
    payBtn:SetText("Pay Now")

    local clearBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clearBtn:SetPoint("LEFT", payBtn, "RIGHT", 10, 0)
    clearBtn:SetSize(120, 22)
    clearBtn:SetText("Clear Due")

    local function Refresh()
      EnsureDB()
      local db = GetDB()
      if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}
      local t = db.tax
      t.sources = (type(t.sources) == "table") and t.sources or {}

      local enabled = (t.enabled == true)
      local rate = clampFn(t.rate, 0, 100) or 0
      t.rate = rate

      dueFS:SetText("Due: " .. MoneyToString(t.due or 0) .. (enabled and "" or " (disabled)"))
      paidFS:SetText("Paid: " .. MoneyToString(t.paidToDate or 0))

      if slider and slider.SetValue then
        slider:SetValue(rate)
      end

      if quietCB and quietCB.SetChecked then quietCB:SetChecked(t.quiet == true) end
      if vendorCB and vendorCB.SetChecked then vendorCB:SetChecked(t.sources.vendor == true) end
      if questCB and questCB.SetChecked then questCB:SetChecked(t.sources.questLoot == true) end
      if mailCB and mailCB.SetChecked then mailCB:SetChecked(t.sources.mail == true) end
      if systemCB and systemCB.SetChecked then systemCB:SetChecked(t.sources.systemMoney == true) end
      if autoPayCB and autoPayCB.SetChecked then autoPayCB:SetChecked(t.autoPayOnGuildBankOpen == true) end

      if payBtn and payBtn.SetEnabled then
        payBtn:SetEnabled(enabled and (rate > 0) and ((tonumber(t.due) or 0) > 0))
      end
    end

    slider:SetScript("OnValueChanged", function(self, value)
      EnsureDB()
      local db = GetDB()
      if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}
      db.tax.rate = clampFn(value, 0, 100) or 0
      db.tax.enabled = (db.tax.rate > 0)
      Refresh()
    end)

    quietCB:SetScript("OnClick", function(self)
      EnsureDB()
      local db = GetDB()
      if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}
      db.tax.quiet = self:GetChecked() and true or false
      Refresh()
    end)

    vendorCB:SetScript("OnClick", function(self)
      EnsureDB()
      local db = GetDB()
      if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}
      db.tax.sources = (type(db.tax.sources) == "table") and db.tax.sources or {}
      db.tax.sources.vendor = self:GetChecked() and true or false
      Refresh()
    end)

    questCB:SetScript("OnClick", function(self)
      EnsureDB()
      local db = GetDB()
      if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}
      db.tax.sources = (type(db.tax.sources) == "table") and db.tax.sources or {}
      db.tax.sources.questLoot = self:GetChecked() and true or false
      Refresh()
    end)

    mailCB:SetScript("OnClick", function(self)
      EnsureDB()
      local db = GetDB()
      if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}
      db.tax.sources = (type(db.tax.sources) == "table") and db.tax.sources or {}
      db.tax.sources.mail = self:GetChecked() and true or false
      Refresh()
    end)

    systemCB:SetScript("OnClick", function(self)
      EnsureDB()
      local db = GetDB()
      if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}
      db.tax.sources = (type(db.tax.sources) == "table") and db.tax.sources or {}
      db.tax.sources.systemMoney = self:GetChecked() and true or false
      Refresh()
    end)

    autoPayCB:SetScript("OnClick", function(self)
      EnsureDB()
      local db = GetDB()
      if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}
      db.tax.autoPayOnGuildBankOpen = self:GetChecked() and true or false
      Refresh()
    end)

    payBtn:SetScript("OnClick", function()
      EnsureDB()
      local db = GetDB()
      if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}
      if not (db.tax.enabled == true) then return end
      Tax.PayNow()
      C_Timer.After(0.60, Refresh)
    end)

    clearBtn:SetScript("OnClick", function()
      EnsureDB()
      local db = GetDB()
      if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}
      db.tax.due = 0
      Refresh()
    end)

    panel:SetScript("OnShow", Refresh)
    Refresh()
  end
end
