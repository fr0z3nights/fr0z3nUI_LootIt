---@diagnostic disable: undefined-global

local LI = fr0z3nUI_LootIt or {}
fr0z3nUI_LootIt = LI

LI.Tax = LI.Tax or {}

do
  local Tax = LI.Tax

  -- Optional UI refresh callback (set by the Tax tab UI when built).
  local function RequestUIRefresh()
    local fn = Tax and rawget(Tax, "_RefreshUI")
    if type(fn) == "function" then
      pcall(fn)
    end
  end

  local DB
  local CHARDB
  local Print = function(...) end

  local state = {
    merchant = { open = false, startMoney = 0, chatMoney = 0 },
    mail = { open = false, startMoney = 0, chatMoney = 0 },
    guildBankOpen = false,
  }

  local goldStr, silverStr, copperStr

  local function GetCurrentGuildKeyAndName()
    if type(IsInGuild) == "function" then
      local ok, inGuild = pcall(IsInGuild)
      if ok and inGuild ~= true then
        return nil, nil
      end
    end
    if type(GetGuildInfo) ~= "function" then
      return nil, nil
    end
    local ok, guildName = pcall(GetGuildInfo, "player")
    guildName = ok and guildName or nil
    if type(guildName) ~= "string" or guildName == "" then
      return nil, nil
    end
    local realm = (type(GetRealmName) == "function") and GetRealmName() or nil
    realm = (type(realm) == "string" and realm ~= "") and realm or ""
    return realm .. "::" .. guildName, guildName
  end

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

    -- Guild-scoped settings/balances.
    t.guilds = (type(t.guilds) == "table") and t.guilds or {}

    -- Legacy account-wide fields (kept for backward compatibility; no longer the active model).
    t.enabled = (t.enabled == true) and true or false
    t.rate = Clamp(t.rate, 0, 100) or 0
    t.quiet = (t.quiet == true) and true or false
    t.due = math.floor(tonumber(t.due) or 0)
    t.paidToDate = math.floor(tonumber(t.paidToDate) or 0)

    -- Split balances: normal tax due vs. guild-withdrawn debt (cannot be cleared).
    -- If old data only has t.due, treat it as normal tax due.
    if t.dueTax == nil and t.dueBorrowed == nil then
      t.dueTax = t.due
      t.dueBorrowed = 0
    end
    t.dueTax = math.floor(tonumber(t.dueTax) or 0)
    t.dueBorrowed = math.floor(tonumber(t.dueBorrowed) or 0)
    if t.dueTax < 0 then t.dueTax = 0 end
    if t.dueBorrowed < 0 then t.dueBorrowed = 0 end
    t.borrowedLastTS = math.floor(tonumber(t.borrowedLastTS) or 0)
    if t.borrowedLastTS < 0 then t.borrowedLastTS = 0 end

    t.due = t.dueTax + t.dueBorrowed

    if t.due < 0 then t.due = 0 end
    if t.paidToDate < 0 then t.paidToDate = 0 end

    t.sources = (type(t.sources) == "table") and t.sources or {}
    if t.sources.vendor == nil then t.sources.vendor = true end
    if t.sources.questLoot == nil then t.sources.questLoot = true end
    if t.sources.systemMoney == nil then t.sources.systemMoney = false end
    if t.sources.mail == nil then t.sources.mail = true end

    if t.autoPayOnGuildBankOpen == nil then t.autoPayOnGuildBankOpen = true end

    -- Normalize: enabled tracks whether the rate is > 0.
    if t.rate <= 0 then
      t.enabled = false
    else
      t.enabled = true
    end

    return t
  end

  local function EnsureGuildTaxDB(guildKey)
    if type(guildKey) ~= "string" or guildKey == "" then return nil end

    local t = EnsureTaxDB()
    if not t then return nil end
    t.guilds = (type(t.guilds) == "table") and t.guilds or {}
    t.guilds[guildKey] = (type(t.guilds[guildKey]) == "table") and t.guilds[guildKey] or {}
    local g = t.guilds[guildKey]

    -- One-time best-effort migration from legacy account-wide tax into the first guild bucket.
    -- This avoids "losing" settings after the Guild-scope refactor.
    if next(g) == nil then
      local legacyRate = Clamp(t.rate, 0, 100) or 0
      local legacyDue = math.floor(tonumber(t.due) or 0)
      local legacyPaid = math.floor(tonumber(t.paidToDate) or 0)
      if legacyRate > 0 or legacyDue > 0 or legacyPaid > 0 then
        g.rate = legacyRate
        g.quiet = (t.quiet == true)
        g.due = legacyDue
        g.paidToDate = legacyPaid
        if type(t.sources) == "table" then
          g.sources = {
            vendor = (t.sources.vendor ~= false),
            questLoot = (t.sources.questLoot ~= false),
            systemMoney = (t.sources.systemMoney == true),
            mail = (t.sources.mail ~= false),
          }
        end
        if t.autoPayOnGuildBankOpen ~= nil then
          g.autoPayOnGuildBankOpen = (t.autoPayOnGuildBankOpen == true)
        end
      end
    end

    g.rate = Clamp(g.rate, 0, 100) or 0
    g.quiet = (g.quiet == true) and true or false
    g.due = math.floor(tonumber(g.due) or 0)
    g.paidToDate = math.floor(tonumber(g.paidToDate) or 0)
    if g.dueTax == nil and g.dueBorrowed == nil then
      g.dueTax = g.due
      g.dueBorrowed = 0
    end
    g.dueTax = math.floor(tonumber(g.dueTax) or 0)
    g.dueBorrowed = math.floor(tonumber(g.dueBorrowed) or 0)
    if g.dueTax < 0 then g.dueTax = 0 end
    if g.dueBorrowed < 0 then g.dueBorrowed = 0 end
    g.borrowedLastTS = math.floor(tonumber(g.borrowedLastTS) or 0)
    if g.borrowedLastTS < 0 then g.borrowedLastTS = 0 end
    g.due = g.dueTax + g.dueBorrowed
    if g.due < 0 then g.due = 0 end
    if g.paidToDate < 0 then g.paidToDate = 0 end

    g.sources = (type(g.sources) == "table") and g.sources or {}
    if g.sources.vendor == nil then g.sources.vendor = true end
    if g.sources.questLoot == nil then g.sources.questLoot = true end
    if g.sources.systemMoney == nil then g.sources.systemMoney = false end
    if g.sources.mail == nil then g.sources.mail = true end

    if g.autoPayOnGuildBankOpen == nil then g.autoPayOnGuildBankOpen = true end

    if g.showOwedSilverCopper == nil then g.showOwedSilverCopper = false end
    g.showOwedSilverCopper = (g.showOwedSilverCopper == true)

    g.enabled = (g.rate > 0)
    return g
  end

  local function EnsureCharTaxDB()
    local cdb = CHARDB or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
    if type(cdb) ~= "table" then return nil end

    cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
    local ct = cdb.tax

    if ct.scope == nil then ct.scope = "guild" end
    ct.scope = tostring(ct.scope or "guild"):lower()
    if ct.scope ~= "guild" and ct.scope ~= "character" then
      ct.scope = "guild"
    end

    ct.cfg = (type(ct.cfg) == "table") and ct.cfg or {}
    local cfg = ct.cfg
    cfg.rate = Clamp(cfg.rate, 0, 100) or 0
    cfg.quiet = (cfg.quiet == true) and true or false
    cfg.sources = (type(cfg.sources) == "table") and cfg.sources or {}
    if cfg.sources.vendor == nil then cfg.sources.vendor = true end
    if cfg.sources.questLoot == nil then cfg.sources.questLoot = true end
    if cfg.sources.systemMoney == nil then cfg.sources.systemMoney = false end
    if cfg.sources.mail == nil then cfg.sources.mail = true end
    if cfg.autoPayOnGuildBankOpen == nil then cfg.autoPayOnGuildBankOpen = true end
    cfg.enabled = (cfg.rate > 0)

    if ct.minGold == nil then ct.minGold = 0 end
    ct.minGold = Clamp(ct.minGold, 0, 9999999) or 0
    if ct.minGold < 0 then ct.minGold = 0 end

    if ct.allowWithdraw == nil then ct.allowWithdraw = false end
    ct.allowWithdraw = (ct.allowWithdraw == true)

    if ct.debug == nil then ct.debug = false end
    ct.debug = (ct.debug == true)

    if ct.showOwedSilverCopper == nil then ct.showOwedSilverCopper = false end
    ct.showOwedSilverCopper = (ct.showOwedSilverCopper == true)

    -- Character-scoped balances.
    ct.bal = (type(ct.bal) == "table") and ct.bal or {}
    ct.bal.due = math.floor(tonumber(ct.bal.due) or 0)
    ct.bal.paidToDate = math.floor(tonumber(ct.bal.paidToDate) or 0)
    if ct.bal.dueTax == nil and ct.bal.dueBorrowed == nil then
      ct.bal.dueTax = ct.bal.due
      ct.bal.dueBorrowed = 0
    end
    ct.bal.dueTax = math.floor(tonumber(ct.bal.dueTax) or 0)
    ct.bal.dueBorrowed = math.floor(tonumber(ct.bal.dueBorrowed) or 0)
    if ct.bal.dueTax < 0 then ct.bal.dueTax = 0 end
    if ct.bal.dueBorrowed < 0 then ct.bal.dueBorrowed = 0 end
    ct.bal.borrowedLastTS = math.floor(tonumber(ct.bal.borrowedLastTS) or 0)
    if ct.bal.borrowedLastTS < 0 then ct.bal.borrowedLastTS = 0 end
    ct.bal.due = ct.bal.dueTax + ct.bal.dueBorrowed
    if ct.bal.due < 0 then ct.bal.due = 0 end
    if ct.bal.paidToDate < 0 then ct.bal.paidToDate = 0 end

    return ct
  end

  local function IsTaxDebugEnabled()
    local ct = EnsureCharTaxDB()
    return (type(ct) == "table") and (ct.debug == true)
  end

  local function GetActiveScopeCfgAndBal()
    local ct = EnsureCharTaxDB()
    local scope = (ct and ct.scope) or "guild"
    if scope == "character" then
      return "character", (ct and ct.cfg) or nil, (ct and ct.bal) or nil
    end

    local guildKey = select(1, GetCurrentGuildKeyAndName())
    if not guildKey then
      return "guild", nil, nil
    end
    local g = EnsureGuildTaxDB(guildKey)
    return "guild", g, g
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

  local BORROW_APR = 0.1149 -- 11.49% per annum
  local YEAR_SECONDS = 31557600 -- 365.25 days

  local function AccrueBorrowedInterest(bal)
    if type(bal) ~= "table" then return end
    local borrowed = math.floor(tonumber(bal.dueBorrowed) or 0)
    if borrowed <= 0 then
      bal.borrowedLastTS = math.floor(tonumber(bal.borrowedLastTS) or 0)
      return
    end
    if type(time) ~= "function" then return end
    local now = math.floor(tonumber(time()) or 0)
    if now <= 0 then return end

    local last = math.floor(tonumber(bal.borrowedLastTS) or 0)
    if last <= 0 or last > now then
      bal.borrowedLastTS = now
      return
    end

    local dt = now - last
    if dt < 60 then return end

    local growth = (1 + BORROW_APR) ^ (dt / YEAR_SECONDS)
    local newBorrowed = math.floor((borrowed * growth) + 0.5)
    if newBorrowed < borrowed then newBorrowed = borrowed end
    if newBorrowed > borrowed then
      bal.dueBorrowed = newBorrowed
      bal.dueTax = math.floor(tonumber(bal.dueTax) or 0)
      if bal.dueTax < 0 then bal.dueTax = 0 end
      bal.due = bal.dueTax + bal.dueBorrowed
    end
    bal.borrowedLastTS = now
  end

  local function AddDue(rawCopper, label)
    rawCopper = math.floor(tonumber(rawCopper) or 0)
    if rawCopper <= 0 then return end

    local _, cfg, bal = GetActiveScopeCfgAndBal()
    if type(cfg) ~= "table" then return end
    if type(bal) ~= "table" then return end
    if not (cfg.enabled == true) then return end

    local rate = Clamp(cfg.rate, 0, 100) or 0
    if rate <= 0 then return end

    local taxCopper = math.floor((rawCopper * rate / 100) + 0.5)
    if taxCopper <= 0 then return end

    bal.dueTax = math.floor((tonumber(bal.dueTax) or 0) + taxCopper)
    if bal.dueTax < 0 then bal.dueTax = 0 end
    bal.dueBorrowed = math.floor(tonumber(bal.dueBorrowed) or 0)
    if bal.dueBorrowed < 0 then bal.dueBorrowed = 0 end
    bal.due = bal.dueTax + bal.dueBorrowed

    -- Tax should only print on deposit; other informational prints are Debug-only.
    if IsTaxDebugEnabled() and not (cfg.quiet == true) then
      Print(string.format("%s Contribution: %s", tostring(label or "Tax"), MoneyToString(taxCopper)))
    end
  end

  local function TryPayGuildBank(isAuto)
    local scope, cfg, bal = GetActiveScopeCfgAndBal()
    if type(cfg) ~= "table" then return end
    if type(bal) ~= "table" then return end

    AccrueBorrowedInterest(bal)

    if scope == "guild" then
      -- No guild = no tax.
      local guildKey = select(1, GetCurrentGuildKeyAndName())
      if not guildKey then
        return
      end
    end

    if isAuto and not (cfg.autoPayOnGuildBankOpen == true) then
      return
    end

    local ct = EnsureCharTaxDB()
    local minGold = ct and (tonumber(ct.minGold) or 0) or 0
    if minGold < 0 then minGold = 0 end
    local minCopper = math.floor(minGold * (COPPER_PER_GOLD or 10000))
    if minCopper < 0 then minCopper = 0 end

    local allowWithdraw = (ct and ct.allowWithdraw == true) and true or false

    local function CanDeposit()
      if type(CanDepositGuildBankMoney) == "function" then
        local ok, can = pcall(CanDepositGuildBankMoney)
        if ok and can == false then
          return false, "Tax deposit failed: cannot deposit to guild bank."
        end
      end
      if type(DepositGuildBankMoney) ~= "function" then
        return false, "Tax deposit failed: guild bank API unavailable."
      end
      return true
    end

    local function DoDeposit()
      local dueTax = math.floor(tonumber(bal.dueTax) or 0)
      local dueBorrowed = math.floor(tonumber(bal.dueBorrowed) or 0)
      if dueTax < 0 then dueTax = 0 end
      if dueBorrowed < 0 then dueBorrowed = 0 end
      local due = dueTax + dueBorrowed
      if due <= 0 then return end

      local okCan, why = CanDeposit()
      if not okCan then
        if IsTaxDebugEnabled() and not (cfg.quiet == true) and why then Print(why) end
        return
      end

      local money = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
      local available = money
      if minCopper > 0 then
        available = money - minCopper
      end
      if available < 0 then available = 0 end

      local toPay = due
      if toPay > available then
        toPay = available
      end
      toPay = math.floor(tonumber(toPay) or 0)
      if toPay <= 0 then
        if IsTaxDebugEnabled() and (not isAuto) and (not (cfg.quiet == true)) and minCopper > 0 then
          Print("Tax deposit skipped: below Min Gold.")
        end
        return
      end

      C_Timer.After(0.30, function()
        local ok = pcall(DepositGuildBankMoney, toPay)
        if ok then
          local payTax = toPay
          if payTax > dueTax then payTax = dueTax end
          local remain = toPay - payTax
          local payBorrowed = remain
          if payBorrowed > dueBorrowed then payBorrowed = dueBorrowed end

          bal.dueTax = math.floor(dueTax - payTax)
          bal.dueBorrowed = math.floor(dueBorrowed - payBorrowed)
          if bal.dueTax < 0 then bal.dueTax = 0 end
          if bal.dueBorrowed < 0 then bal.dueBorrowed = 0 end
          bal.due = bal.dueTax + bal.dueBorrowed
          bal.paidToDate = math.floor((tonumber(bal.paidToDate) or 0) + toPay)
          if not (cfg.quiet == true) then
            if toPay < due then
              Print(string.format("Deposited %s into the guild bank (partial).", MoneyToString(toPay)))
            else
              Print(string.format("Deposited %s into the guild bank.", MoneyToString(toPay)))
            end
          end
          RequestUIRefresh()
        else
          if IsTaxDebugEnabled() and not (cfg.quiet == true) then Print("Tax deposit failed.") end
          RequestUIRefresh()
        end
      end)
    end

    -- If enabled, keep player at or above Min Gold by borrowing from the guild bank.
    -- This debt cannot be cleared, accrues interest, and is paid AFTER normal tax due.
    if allowWithdraw and minCopper > 0 and type(WithdrawGuildBankMoney) == "function" then
      local money = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
      if money < minCopper then
        local need = math.floor(minCopper - money)
        if need > 0 then
          local canWithdraw = true
          if type(CanWithdrawGuildBankMoney) == "function" then
            local okW, can = pcall(CanWithdrawGuildBankMoney)
            if okW and can == false then
              canWithdraw = false
            end
          end
          if canWithdraw then
            local ok = pcall(WithdrawGuildBankMoney, need)
            if ok then
              bal.dueBorrowed = math.floor((tonumber(bal.dueBorrowed) or 0) + need)
              if bal.dueBorrowed < 0 then bal.dueBorrowed = 0 end
              bal.dueTax = math.floor(tonumber(bal.dueTax) or 0)
              if bal.dueTax < 0 then bal.dueTax = 0 end
              bal.due = bal.dueTax + bal.dueBorrowed
              if type(time) == "function" then
                local now = math.floor(tonumber(time()) or 0)
                if now > 0 then
                  bal.borrowedLastTS = now
                end
              end
              if IsTaxDebugEnabled() and not (cfg.quiet == true) then
                Print(string.format("Withdrew %s to meet Min Gold (added to Due).", MoneyToString(need)))
              end
              RequestUIRefresh()
              C_Timer.After(0.60, DoDeposit)
              return
            end
          end
        end
      end
    end
    DoDeposit()
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

    local _, cfg = GetActiveScopeCfgAndBal()
    if type(cfg) ~= "table" then return end
    if not (cfg.sources and cfg.sources.vendor) then return end

    local nowMoney = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
    local delta = nowMoney - (tonumber(state.merchant.startMoney) or 0)

    local chatDuring = math.floor(tonumber(state.merchant.chatMoney) or 0)
    local taxable = delta - chatDuring

    if taxable > 0 then
      AddDue(taxable, "Vendor")
    end
  end

  function Tax.OnMoneyMessage(event, msg)
    local _, cfg = GetActiveScopeCfgAndBal()
    if type(cfg) ~= "table" then return end

    local allow = false
    if event == "CHAT_MSG_MONEY" then
      allow = (cfg.sources and cfg.sources.questLoot) and true or false
    elseif event == "CHAT_MSG_SYSTEM" then
      allow = (cfg.sources and cfg.sources.systemMoney) and true or false
      if allow and type(msg) == "string" then
        local m = msg:lower()
        if m:find("spent", 1, true) or m:find("pay", 1, true) or m:find("paid", 1, true) or m:find("lost", 1, true) or m:find("cost", 1, true) or m:find("repair", 1, true) then
          allow = false
        end
      end
    end

    local copper = 0
    if event == "CHAT_MSG_SYSTEM" then
      -- Prefer LootIt's own system-money detection/parsing (used by the chat reprint) when available.
      local lc = LI and LI.LootChat
      if lc and type(lc.IsLikelyMoneyMessage) == "function" and type(lc.ParseCoinsFromMoneyMessage) == "function" then
        local okLikely, likely = pcall(lc.IsLikelyMoneyMessage, msg)
        if okLikely and likely then
          local okCoins, coins = pcall(lc.ParseCoinsFromMoneyMessage, msg)
          if okCoins and type(coins) == "table" then
            local g = math.floor(tonumber(coins.gold) or 0)
            local s = math.floor(tonumber(coins.silver) or 0)
            local c = math.floor(tonumber(coins.copper) or 0)
            copper = (g * (COPPER_PER_GOLD or 10000)) + (s * (COPPER_PER_SILVER or 100)) + c
          end
        end
      else
        copper = ParseMoneyFromChat(msg)
      end
    else
      copper = ParseMoneyFromChat(msg)
    end
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

        local _, cfg = GetActiveScopeCfgAndBal()
        if type(cfg) ~= "table" then return end
        if not (cfg.sources and cfg.sources.mail) then return end

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
      state.guildBankOpen = (isShow == true)
      if isShow then
        TryPayGuildBank(true)
      end
      RequestUIRefresh()
      return
    end
  end

  function Tax.PayNow()
    if not (state.guildBankOpen == true) then return end
    TryPayGuildBank(false)
  end

  function Tax.ClearDue()
    local _, _, bal = GetActiveScopeCfgAndBal()
    if type(bal) ~= "table" then return end
    bal.dueTax = 0
    bal.dueBorrowed = math.floor(tonumber(bal.dueBorrowed) or 0)
    if bal.dueBorrowed < 0 then bal.dueBorrowed = 0 end
    AccrueBorrowedInterest(bal)
    bal.due = math.floor(tonumber(bal.dueTax) or 0) + math.floor(tonumber(bal.dueBorrowed) or 0)
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

    local function HideEditBoxFrame(box)
      if not box or not box.GetRegions then return end
      for i = 1, select("#", box:GetRegions()) do
        local region = select(i, box:GetRegions())
        if region and region.Hide and region.GetObjectType and region:GetObjectType() == "Texture" then
          region:Hide()
        end
      end
    end

    local function SetFSSize(fs, size)
      if not (fs and fs.GetFont and fs.SetFont) then return end
      local font, _, flags = fs:GetFont()
      if type(font) ~= "string" or font == "" then
        font = "Fonts\\FRIZQT__.TTF"
      end
      fs:SetFont(font, size, flags)
    end

    -- Match FGO's standard in-frame Reload UI button size.
    local BTN_W, BTN_H = 90, 22
    local BTN_GAP = 12
    local GAP_Y = 14

    local GUILDNAME_W, GUILDNAME_H = 240, 28

    -- Coin icon sizing/offsets (used for both EditBox and inline textures).
    -- Coin icon sizing/offsets (used for both EditBox and owed display textures).
    -- Larger text is allowed; do not reduce text size.
    local COIN_W, COIN_H = 16, 16
    local COIN_TEX_Y = -3
    local COIN_TEXT_SIZE_MIN = 18
    local COIN_TEXT_SIZE_OWED = 20

    local function SetFontStringSize(fs, size)
      if not (fs and fs.GetFont and fs.SetFont) then return end
      local font, _, flags = fs:GetFont()
      if type(font) ~= "string" or font == "" then
        font = "Fonts\\FRIZQT__.TTF"
      end
      fs:SetFont(font, size, flags)
    end

    local function FormatIntWithCommas(v)
      v = math.floor(tonumber(v) or 0)
      local sign = ""
      if v < 0 then
        sign = "-"
        v = -v
      end
      local s = tostring(v)
      while true do
        local newS, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
        s = newS
        if k == 0 then break end
      end
      return sign .. s
    end

    -- Scope button (Guild / Character) - copies size/display style from Trade's main scope button.
    local scopeBtn = CreateFrame("Button", nil, panel)
    scopeBtn:SetSize(240, 28)
    scopeBtn:SetPoint("TOP", panel, "TOP", 0, -12)

    local scopeBtnText = scopeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    scopeBtnText:SetPoint("CENTER", scopeBtn, "CENTER", 0, 0)
    SetFontStringSize(scopeBtnText, 16)

    -- Percent input (borderless)
    local rateEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    rateEdit:SetSize(240, 28)
    -- Leave space for the guild name row between Scope and Rate.
    rateEdit:SetPoint("TOP", scopeBtn, "BOTTOM", 0, -(GUILDNAME_H + GAP_Y))
    rateEdit:SetAutoFocus(false)
    rateEdit:SetMaxLetters(3)
    local RATE_INSET_L, RATE_INSET_R = 6, 18
    rateEdit:SetTextInsets(RATE_INSET_L, RATE_INSET_R, 0, 0)
    rateEdit:SetJustifyH("CENTER")
    if rateEdit.SetJustifyV then rateEdit:SetJustifyV("MIDDLE") end
    if rateEdit.SetNumeric then rateEdit:SetNumeric(true) end
    if rateEdit.GetFont and rateEdit.SetFont then
      local fontPath, _, fontFlags = rateEdit:GetFont()
      if fontPath then rateEdit:SetFont(fontPath, 18, fontFlags) end
    end
    HideEditBoxFrame(rateEdit)

    local ratePH = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    ratePH:SetPoint("CENTER", rateEdit, "CENTER", 0, 0)
    ratePH:SetText("Tax %")
    ratePH:SetTextColor(1, 1, 1, 0.35)

    local rateSuffix = rateEdit:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rateSuffix:SetText("%")
    rateSuffix:SetTextColor(1, 1, 1, 0.95)
    SetFontStringSize(rateSuffix, 18)
    rateSuffix:Hide()

    local rateMeasure = rateEdit:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rateMeasure:SetPoint("TOPLEFT", rateEdit, "TOPLEFT", -1000, 0)
    rateMeasure:SetAlpha(0)
    if rateEdit.GetFont and rateMeasure.SetFont then
      local fontPath, fontSize, fontFlags = rateEdit:GetFont()
      if fontPath then rateMeasure:SetFont(fontPath, fontSize or 18, fontFlags) end
    end

    local function GetGuildNameColor()
      local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
      if faction == "Horde" then
        return 0.77, 0.12, 0.23
      elseif faction == "Alliance" then
        return 0.11, 0.39, 0.88
      end
      return 1, 1, 1
    end

    -- Detected guild name (text box) centered between Scope and Rate.
    local guildNameRow = CreateFrame("Frame", nil, panel)
    guildNameRow:SetPoint("TOP", scopeBtn, "BOTTOM", 0, 0)
    guildNameRow:SetPoint("BOTTOM", rateEdit, "TOP", 0, 0)
    guildNameRow:SetSize(GUILDNAME_W, GUILDNAME_H)

    local guildNameEdit = CreateFrame("EditBox", nil, guildNameRow, "InputBoxTemplate")
    guildNameEdit:SetSize(GUILDNAME_W, GUILDNAME_H)
    guildNameEdit:SetPoint("CENTER", guildNameRow, "CENTER", 0, 0)
    guildNameEdit:SetAutoFocus(false)
    guildNameEdit:SetTextInsets(6, 6, 0, 0)
    guildNameEdit:SetJustifyH("CENTER")
    if guildNameEdit.SetJustifyV then guildNameEdit:SetJustifyV("MIDDLE") end
    if guildNameEdit.EnableMouse then guildNameEdit:EnableMouse(false) end
    if guildNameEdit.SetEnabled then guildNameEdit:SetEnabled(true) end
    if guildNameEdit.GetFont and guildNameEdit.SetFont then
      local fontPath, _, fontFlags = guildNameEdit:GetFont()
      if fontPath then guildNameEdit:SetFont(fontPath, 30, fontFlags) end
    end
    HideEditBoxFrame(guildNameEdit)

    local guildNamePH = guildNameRow:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    guildNamePH:SetPoint("CENTER", guildNameEdit, "CENTER", 0, 0)
    guildNamePH:SetText("NO GUILD")
    guildNamePH:SetTextColor(1, 1, 1, 0.35)

    local function PlaceInlineSuffix(edit, measureFS, suffixFS, text, insetL, insetR, gap)
      if not (edit and measureFS and suffixFS and suffixFS.ClearAllPoints and suffixFS.SetPoint) then return end
      text = tostring(text or "")
      if text == "" then
        suffixFS:Hide()
        return
      end
      measureFS:SetText(text)
      local w = measureFS.GetStringWidth and measureFS:GetStringWidth() or 0
      if w < 0 then w = 0 end
      local centerOffset = ((tonumber(insetL) or 0) - (tonumber(insetR) or 0)) / 2
      suffixFS:ClearAllPoints()
      suffixFS:SetPoint("LEFT", edit, "CENTER", centerOffset + (w / 2) + (tonumber(gap) or 0), 0)
      suffixFS:Show()
    end

    local function UpdateRatePlaceholder()
      local txt = rateEdit:GetText() or ""
      local focused = rateEdit.HasFocus and rateEdit:HasFocus() or false
      ratePH:SetShown((txt == "") and (not focused))
      PlaceInlineSuffix(rateEdit, rateMeasure, rateSuffix, txt, RATE_INSET_L, RATE_INSET_R, 2)
    end
    rateEdit:SetScript("OnEditFocusGained", function() ratePH:Hide() end)
    rateEdit:SetScript("OnEditFocusLost", function() UpdateRatePlaceholder() end)

    -- Per-character Min Gold (borderless), matching Trade tab input size/position.
    local minEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    minEdit:SetSize(210, 38)
    minEdit:SetPoint("TOP", rateEdit, "BOTTOM", 0, -GAP_Y)
    minEdit:SetAutoFocus(false)
    minEdit:SetMaxLetters(10)
    local MIN_INSET_L, MIN_INSET_R = 6, 18
    minEdit:SetTextInsets(MIN_INSET_L, MIN_INSET_R, 0, 0)
    minEdit:SetJustifyH("CENTER")
    if minEdit.SetJustifyV then minEdit:SetJustifyV("MIDDLE") end
    if minEdit.SetNumeric then minEdit:SetNumeric(false) end
    if minEdit.EnableMouse then minEdit:EnableMouse(true) end
    if minEdit.SetTextColor then
      -- Match the gold used in the Due display (|cffffd100).
      minEdit:SetTextColor(1.0, 0.82, 0.0, 1)
    end
    if minEdit.GetFont and minEdit.SetFont then
      local fontPath, _, fontFlags = minEdit:GetFont()
      if fontPath then minEdit:SetFont(fontPath, COIN_TEXT_SIZE_MIN, fontFlags) end
    end
    HideEditBoxFrame(minEdit)

    local minPH = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    minPH:SetPoint("CENTER", minEdit, "CENTER", 0, 0)
    minPH:SetText("Min Gold")
    minPH:SetTextColor(1, 1, 1, 0.35)

    local minMeasure = minEdit:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    minMeasure:SetPoint("TOPLEFT", minEdit, "TOPLEFT", -1000, 0)
    minMeasure:SetAlpha(0)
    if minEdit.GetFont and minMeasure.SetFont then
      local fontPath, fontSize, fontFlags = minEdit:GetFont()
      if fontPath then minMeasure:SetFont(fontPath, fontSize or COIN_TEXT_SIZE_MIN, fontFlags) end
    end

    local minGoldIcon = minEdit:CreateTexture(nil, "OVERLAY")
    minGoldIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    minGoldIcon:SetSize(COIN_W, COIN_H)
    minGoldIcon:Hide()

    local function UpdateMinPlaceholder()
      local txt = minEdit:GetText() or ""
      local focused = minEdit.HasFocus and minEdit:HasFocus() or false
      minPH:SetShown((txt == "") and (not focused))
      local clean = txt:gsub("[^%d]", "")
      local v = tonumber(clean) or 0
      if v and v > 0 then
        minMeasure:SetText(txt)
        local w = minMeasure.GetStringWidth and minMeasure:GetStringWidth() or 0
        if w < 0 then w = 0 end
        local centerOffset = (MIN_INSET_L - MIN_INSET_R) / 2
        minGoldIcon:ClearAllPoints()
        -- Add a visible "space" before the icon, and keep it vertically centered on the text line.
        minGoldIcon:SetPoint("CENTER", minEdit, "CENTER", centerOffset + (w / 2) + 6 + (COIN_W / 2), 0)
        minGoldIcon:Show()
      else
        minGoldIcon:Hide()
      end
    end
    -- Owed display (numbers + textures; avoids inline texture baseline issues).
    local owedRow = CreateFrame("Frame", nil, panel)
    owedRow:SetPoint("TOP", rateEdit, "BOTTOM", 0, -GAP_Y) -- final position set after sourcesRow exists
    owedRow:SetSize(240, 28)

    local owedGoldFS = owedRow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    local owedSilverFS = owedRow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    local owedCopperFS = owedRow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    SetFSSize(owedGoldFS, COIN_TEXT_SIZE_OWED)
    SetFSSize(owedSilverFS, COIN_TEXT_SIZE_OWED)
    SetFSSize(owedCopperFS, COIN_TEXT_SIZE_OWED)
    owedGoldFS:SetTextColor(1.0, 0.82, 0.0, 1)
    owedSilverFS:SetTextColor(0.78, 0.78, 0.81, 1)
    owedCopperFS:SetTextColor(0.93, 0.65, 0.37, 1)

    local owedGoldIcon = owedRow:CreateTexture(nil, "OVERLAY")
    owedGoldIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    owedGoldIcon:SetSize(COIN_W, COIN_H)

    local owedSilverIcon = owedRow:CreateTexture(nil, "OVERLAY")
    owedSilverIcon:SetTexture("Interface\\MoneyFrame\\UI-SilverIcon")
    owedSilverIcon:SetSize(COIN_W, COIN_H)

    local owedCopperIcon = owedRow:CreateTexture(nil, "OVERLAY")
    owedCopperIcon:SetTexture("Interface\\MoneyFrame\\UI-CopperIcon")
    owedCopperIcon:SetSize(COIN_W, COIN_H)

    local function UpdateOwedRow(copper, showSilverCopper)
      copper = math.floor(tonumber(copper) or 0)
      if copper < 0 then copper = 0 end

      local g = math.floor(copper / (COPPER_PER_GOLD or 10000))
      local rem = copper - (g * (COPPER_PER_GOLD or 10000))
      local s = math.floor(rem / (COPPER_PER_SILVER or 100))
      local c = math.floor(rem - (s * (COPPER_PER_SILVER or 100)))

      owedGoldFS:SetText(FormatIntWithCommas(g))
      owedSilverFS:SetText(tostring(s))
      owedCopperFS:SetText(tostring(c))

      local preIcon = 4   -- ~1 space
      local postCoin = 10 -- ~2 spaces

      owedGoldFS:ClearAllPoints()
      owedGoldIcon:ClearAllPoints()
      owedSilverFS:ClearAllPoints()
      owedSilverIcon:ClearAllPoints()
      owedCopperFS:ClearAllPoints()
      owedCopperIcon:ClearAllPoints()

      local wG = owedGoldFS.GetStringWidth and owedGoldFS:GetStringWidth() or 0
      if wG < 0 then wG = 0 end

      if showSilverCopper == true then
        owedSilverFS:Show(); owedSilverIcon:Show()
        owedCopperFS:Show(); owedCopperIcon:Show()

        local wS = owedSilverFS.GetStringWidth and owedSilverFS:GetStringWidth() or 0
        local wC = owedCopperFS.GetStringWidth and owedCopperFS:GetStringWidth() or 0
        if wS < 0 then wS = 0 end
        if wC < 0 then wC = 0 end

        local totalW = wG + preIcon + COIN_W + postCoin + wS + preIcon + COIN_W + postCoin + wC + preIcon + COIN_W
        if totalW < 10 then totalW = 10 end
        owedRow:SetWidth(totalW)

        owedGoldFS:SetPoint("LEFT", owedRow, "LEFT", 0, 0)
        -- Center the coin texture to the number text vertically.
        owedGoldIcon:SetPoint("CENTER", owedGoldFS, "RIGHT", preIcon + (COIN_W / 2), 0)

        owedSilverFS:SetPoint("LEFT", owedGoldIcon, "RIGHT", postCoin, 0)
        owedSilverIcon:SetPoint("CENTER", owedSilverFS, "RIGHT", preIcon + (COIN_W / 2), 0)

        owedCopperFS:SetPoint("LEFT", owedSilverIcon, "RIGHT", postCoin, 0)
        owedCopperIcon:SetPoint("CENTER", owedCopperFS, "RIGHT", preIcon + (COIN_W / 2), 0)
      else
        owedSilverFS:Hide(); owedSilverIcon:Hide()
        owedCopperFS:Hide(); owedCopperIcon:Hide()

        local totalW = wG + preIcon + COIN_W
        if totalW < 10 then totalW = 10 end
        owedRow:SetWidth(totalW)

        owedGoldFS:SetPoint("LEFT", owedRow, "LEFT", 0, 0)
        -- Center the coin texture to the number text vertically.
        owedGoldIcon:SetPoint("CENTER", owedGoldFS, "RIGHT", preIcon + (COIN_W / 2), 0)
      end
    end
    minEdit:SetScript("OnEditFocusGained", function()
      minPH:Hide()
      local txt = minEdit:GetText() or ""
      local clean = txt:gsub("[^%d]", "")
      if clean ~= txt then
        minEdit:SetText(clean)
      end
    end)
    minEdit:SetScript("OnEditFocusLost", function()
      local txt = minEdit:GetText() or ""
      local clean = txt:gsub("[^%d]", "")
      local v = tonumber(clean) or 0
      if v > 0 then
        minEdit:SetText(FormatIntWithCommas(v))
      else
        minEdit:SetText("")
      end
      UpdateMinPlaceholder()
    end)
    minEdit:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Minimum gold to keep on the character.\n0 disables this feature.")
      GameTooltip:Show()
    end)
    minEdit:SetScript("OnLeave", function()
      if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    end)

    -- Toggle-as-text helpers
    local function SetToggleText(btn, label, on)
      if not (btn and btn._fs and btn._fs.SetText and btn._fs.SetTextColor) then return end
      btn._fs:SetText(label)
      if on then
        btn._fs:SetTextColor(1.0, 0.82, 0.0, 1)
      else
        btn._fs:SetTextColor(0.55, 0.55, 0.55, 1)
      end
    end

    local function CreateTextToggleButton(parent)
      local b = CreateFrame("Button", nil, parent)
      b:SetSize(BTN_W, BTN_H)
      local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      fs:SetPoint("CENTER", b, "CENTER", 0, 0)
      b._fs = fs
      return b
    end

    local sourcesRow = CreateFrame("Frame", nil, panel)
    sourcesRow:SetPoint("TOP", rateEdit, "BOTTOM", 0, -GAP_Y)
    sourcesRow:SetSize(1, BTN_H)

    local vendorBtn = CreateTextToggleButton(sourcesRow)
    vendorBtn:SetPoint("LEFT", sourcesRow, "LEFT", 0, 0)

    local lootBtn = CreateTextToggleButton(sourcesRow)
    lootBtn:SetPoint("LEFT", vendorBtn, "RIGHT", 14, 0)

    local mailBtn = CreateTextToggleButton(sourcesRow)
    mailBtn:SetPoint("LEFT", lootBtn, "RIGHT", 14, 0)

    local systemBtn = CreateTextToggleButton(sourcesRow)
    systemBtn:SetPoint("LEFT", mailBtn, "RIGHT", 14, 0)

    -- Withdraw toggle (above System), default off.
    local withdrawBtn = CreateTextToggleButton(panel)
    withdrawBtn:SetPoint("BOTTOM", systemBtn, "TOP", 0, 0)

    -- Action-as-text buttons
    local payBtn = CreateTextToggleButton(panel)
    local clearBtn = CreateTextToggleButton(panel)

    -- Auto Pay lives bottom-left (button appearance restored).
    local autoBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    autoBtn:SetSize(BTN_W, BTN_H)
    autoBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    autoBtn:SetText("Auto Pay")

    local scBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    scBtn:SetSize(44, BTN_H)
    scBtn:SetPoint("LEFT", autoBtn, "RIGHT", BTN_GAP, 0)
    scBtn:SetText("")

    local scSilver = scBtn:CreateTexture(nil, "ARTWORK")
    scSilver:SetTexture("Interface\\MoneyFrame\\UI-SilverIcon")
    scSilver:SetSize(COIN_W, COIN_H)
    scSilver:SetPoint("CENTER", scBtn, "CENTER", -(COIN_W / 2) - 2, COIN_TEX_Y)

    local scCopper = scBtn:CreateTexture(nil, "ARTWORK")
    scCopper:SetTexture("Interface\\MoneyFrame\\UI-CopperIcon")
    scCopper:SetSize(COIN_W, COIN_H)
    scCopper:SetPoint("CENTER", scBtn, "CENTER", (COIN_W / 2) + 2, COIN_TEX_Y)

    -- Stack owed + min below the source buttons.
    owedRow:ClearAllPoints()
    owedRow:SetPoint("TOP", sourcesRow, "BOTTOM", 0, -GAP_Y)

    minEdit:ClearAllPoints()
    minEdit:SetPoint("TOP", owedRow, "BOTTOM", 0, -GAP_Y)

    local reloadBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reloadBtn:SetSize(BTN_W, BTN_H)
    reloadBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    reloadBtn:SetText("Reload UI")
    reloadBtn:SetScript("OnClick", function()
      local r = _G and _G["ReloadUI"]
      if r then r() end
    end)

    -- Debug toggle (gates all non-deposit Tax prints) - move next to Reload UI and make it a real button.
    local debugBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    debugBtn:SetSize(BTN_W, BTN_H)
    debugBtn:SetPoint("BOTTOMRIGHT", reloadBtn, "BOTTOMLEFT", -BTN_GAP, 0)
    debugBtn:SetText("Debug")
    debugBtn._fs = (debugBtn.GetFontString and debugBtn:GetFontString()) or nil
    if not debugBtn._fs then
      local fs = debugBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      fs:SetPoint("CENTER", debugBtn, "CENTER", 0, 0)
      debugBtn._fs = fs
    end

    panel:HookScript("OnHide", function() end)

    local function Refresh()
      EnsureDB()
      local db = GetDB()
      if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}

      local guildKey, guildName = GetCurrentGuildKeyAndName()
      if guildNameEdit and guildNameEdit.SetText then
        if type(guildName) == "string" and guildName ~= "" then
          guildNameEdit:SetText(string.upper(guildName))
          if guildNameEdit.SetTextColor then
            guildNameEdit:SetTextColor(GetGuildNameColor())
          end
          guildNamePH:Hide()
        else
          guildNameEdit:SetText("")
          guildNamePH:Show()
        end
      end

      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      local ct = cdb.tax
      local scope = tostring(ct.scope or "guild"):lower()
      if scope ~= "guild" and scope ~= "character" then scope = "guild" end
      ct.scope = scope

      ct.cfg = (type(ct.cfg) == "table") and ct.cfg or {}
      ct.cfg.sources = (type(ct.cfg.sources) == "table") and ct.cfg.sources or {}
      ct.bal = (type(ct.bal) == "table") and ct.bal or {}
      ct.bal.due = math.floor(tonumber(ct.bal.due) or 0)
      ct.bal.paidToDate = math.floor(tonumber(ct.bal.paidToDate) or 0)
      if ct.bal.due < 0 then ct.bal.due = 0 end
      if ct.bal.paidToDate < 0 then ct.bal.paidToDate = 0 end

      local cfg
      local bal
      if scope == "character" then
        cfg = ct.cfg
        bal = ct.bal
      else
        cfg = guildKey and EnsureGuildTaxDB(guildKey) or nil
        bal = cfg
      end

      if type(bal) == "table" then
        AccrueBorrowedInterest(bal)
      end

      -- If guild scope and no guild, treat as disabled with defaults.
      local viewCfg = cfg
      local viewBal = bal
      if type(viewCfg) ~= "table" then
        viewCfg = {
          enabled = false,
          rate = 0,
          quiet = false,
          sources = { vendor = true, questLoot = true, systemMoney = false, mail = true },
          autoPayOnGuildBankOpen = true,
        }
      end
      if type(viewBal) ~= "table" then
        viewBal = { due = 0, paidToDate = 0 }
      end

      viewCfg.sources = (type(viewCfg.sources) == "table") and viewCfg.sources or {}
      if viewCfg.sources.vendor == nil then viewCfg.sources.vendor = true end
      if viewCfg.sources.questLoot == nil then viewCfg.sources.questLoot = true end
      if viewCfg.sources.systemMoney == nil then viewCfg.sources.systemMoney = false end
      if viewCfg.sources.mail == nil then viewCfg.sources.mail = true end
      if viewCfg.autoPayOnGuildBankOpen == nil then viewCfg.autoPayOnGuildBankOpen = true end

      local rate = clampFn(viewCfg.rate, 0, 100) or 0
      viewCfg.rate = rate
      viewCfg.enabled = (rate > 0)

      -- Disable interactive controls when in Guild scope but not currently in a guild.
      local controlsEnabled = true
      if scope == "guild" and not guildKey then
        controlsEnabled = false
      end

      -- Split balances: Clear Due only clears normal tax due (not borrowed/withdrawn debt).
      local viewDueTax = viewBal.dueTax
      if viewDueTax == nil then viewDueTax = viewBal.due end
      local dueTax = math.floor(tonumber(viewDueTax) or 0)
      local dueBorrowed = math.floor(tonumber(viewBal.dueBorrowed) or 0)
      if dueTax < 0 then dueTax = 0 end
      if dueBorrowed < 0 then dueBorrowed = 0 end
      local dueTotal = dueTax + dueBorrowed
      if dueTotal < 0 then dueTotal = 0 end

      local ct = EnsureCharTaxDB()
      local showSilverCopper
      if scope == "guild" then
        showSilverCopper = (type(cfg) == "table") and (cfg.showOwedSilverCopper == true) or false
      else
        showSilverCopper = (ct and ct.showOwedSilverCopper == true)
      end
      UpdateOwedRow(dueTotal, showSilverCopper)

      if scSilver and scSilver.SetDesaturated and scSilver.SetAlpha then
        scSilver:SetDesaturated(not showSilverCopper)
        scSilver:SetAlpha(showSilverCopper and 1 or 0.35)
      end
      if scCopper and scCopper.SetDesaturated and scCopper.SetAlpha then
        scCopper:SetDesaturated(not showSilverCopper)
        scCopper:SetAlpha(showSilverCopper and 1 or 0.35)
      end

      if rateEdit and rateEdit.SetText then
        if rate <= 0 then
          if rateEdit.GetText and rateEdit:GetText() ~= "" then
            rateEdit:SetText("")
          end
        else
          local want = tostring(math.floor(rate))
          if rateEdit.GetText and rateEdit:GetText() ~= want then
            rateEdit:SetText(want)
          end
        end
        UpdateRatePlaceholder()
      end

      ct = ct or EnsureCharTaxDB()
      local minGold = ct and (tonumber(ct.minGold) or 0) or 0
      if minEdit and minEdit.SetText then
        local focused = minEdit.HasFocus and minEdit:HasFocus() or false
        if not focused then
          if minGold <= 0 then
            if minEdit.GetText and minEdit:GetText() ~= "" then
              minEdit:SetText("")
            end
          else
            local want = FormatIntWithCommas(math.floor(minGold))
            if minEdit.GetText and minEdit:GetText() ~= want then
              minEdit:SetText(want)
            end
          end
        end
        UpdateMinPlaceholder()
      end

      SetToggleText(vendorBtn, "Vendor", viewCfg.sources.vendor == true)
      SetToggleText(lootBtn, "Looted", viewCfg.sources.questLoot == true)
      SetToggleText(mailBtn, "Mail", viewCfg.sources.mail == true)
      SetToggleText(systemBtn, "System", viewCfg.sources.systemMoney == true)
      SetToggleText(withdrawBtn, "Withdraw", (ct and ct.allowWithdraw == true))
      SetToggleText(debugBtn, "Debug", (ct and ct.debug == true))

      -- Action button text + state (Pay/Clear are not toggles; they simply enable/disable).
      local canPayNow = controlsEnabled and (dueTotal > 0) and (state.guildBankOpen == true)
      SetToggleText(payBtn, "Pay Now", canPayNow)
      SetToggleText(clearBtn, "Clear Due", controlsEnabled and (dueTax > 0))
      do
        local fs = autoBtn and autoBtn.GetFontString and autoBtn:GetFontString() or nil
        if fs and fs.SetTextColor then
          if viewCfg.autoPayOnGuildBankOpen == true then
            fs:SetTextColor(1.0, 0.82, 0.0, 1)
          else
            fs:SetTextColor(0.55, 0.55, 0.55, 1)
          end
        end
      end

      -- Center the Vendor/Looted/Mail/System row after widths update.
      do
        local gap = 14
        local w1 = vendorBtn.GetWidth and vendorBtn:GetWidth() or 0
        local w2 = lootBtn.GetWidth and lootBtn:GetWidth() or 0
        local w3 = mailBtn.GetWidth and mailBtn:GetWidth() or 0
        local w4 = systemBtn.GetWidth and systemBtn:GetWidth() or 0
        local totalW = w1 + w2 + w3 + w4 + (gap * 3)
        if totalW < 10 then totalW = 10 end
        sourcesRow:SetWidth(totalW)
        vendorBtn:ClearAllPoints()
        lootBtn:ClearAllPoints()
        mailBtn:ClearAllPoints()
        systemBtn:ClearAllPoints()
        vendorBtn:SetPoint("LEFT", sourcesRow, "LEFT", 0, 0)
        lootBtn:SetPoint("LEFT", vendorBtn, "RIGHT", gap, 0)
        mailBtn:SetPoint("LEFT", lootBtn, "RIGHT", gap, 0)
        systemBtn:SetPoint("LEFT", mailBtn, "RIGHT", gap, 0)
      end

      -- Place Withdraw aligned with the Min Gold input row, and horizontally aligned over System.
      do
        local pLeft = panel.GetLeft and panel:GetLeft() or nil
        local pBottom = panel.GetBottom and panel:GetBottom() or nil
        local sLeft = systemBtn.GetLeft and systemBtn:GetLeft() or nil
        local _, mY
        if minEdit and minEdit.GetCenter then
          _, mY = minEdit:GetCenter()
        end

        if pLeft and pBottom and sLeft and mY then
          withdrawBtn:ClearAllPoints()
          withdrawBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", (sLeft - pLeft), (mY - pBottom) - (BTN_H / 2))
        else
          -- Fallback: above System.
          withdrawBtn:ClearAllPoints()
          withdrawBtn:SetPoint("BOTTOM", systemBtn, "TOP", 0, 0)
        end
      end

      -- Place Pay Now above Vendor, Clear Due above System, aligned to the owed row.
      do
        local pLeft = panel.GetLeft and panel:GetLeft() or nil
        local pBottom = panel.GetBottom and panel:GetBottom() or nil

        local vLeft = vendorBtn.GetLeft and vendorBtn:GetLeft() or nil
        local sLeft = systemBtn.GetLeft and systemBtn:GetLeft() or nil

        local _, dY
        if owedRow and owedRow.GetCenter then
          _, dY = owedRow:GetCenter()
        end

        if pLeft and pBottom and vLeft and sLeft and dY then
          payBtn:ClearAllPoints()
          payBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", (vLeft - pLeft), (dY - pBottom) - (BTN_H / 2))

          clearBtn:ClearAllPoints()
          clearBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", (sLeft - pLeft), (dY - pBottom) - (BTN_H / 2))
        else
          -- Fallbacks
          payBtn:ClearAllPoints()
          payBtn:SetPoint("BOTTOM", vendorBtn, "TOP", 0, 0)
          clearBtn:ClearAllPoints()
          clearBtn:SetPoint("BOTTOM", systemBtn, "TOP", 0, 0)
        end
      end

      -- Scope button UI
      scopeBtnText:SetText((scope == "character") and "CHARACTER" or "GUILD")
      if scopeBtnText and scopeBtnText.SetTextColor then
        scopeBtnText:SetTextColor(1.0, 0.82, 0.0, 1)
      end
      if rateEdit and rateEdit.SetEnabled then rateEdit:SetEnabled(controlsEnabled) end
      if vendorBtn and vendorBtn.SetEnabled then vendorBtn:SetEnabled(controlsEnabled) end
      if lootBtn and lootBtn.SetEnabled then lootBtn:SetEnabled(controlsEnabled) end
      if mailBtn and mailBtn.SetEnabled then mailBtn:SetEnabled(controlsEnabled) end
      if systemBtn and systemBtn.SetEnabled then systemBtn:SetEnabled(controlsEnabled) end
      if withdrawBtn and withdrawBtn.SetEnabled then withdrawBtn:SetEnabled(true) end
      if debugBtn and debugBtn.SetEnabled then debugBtn:SetEnabled(true) end
      if autoBtn and autoBtn.SetEnabled then autoBtn:SetEnabled(controlsEnabled) end
      if payBtn and payBtn.SetEnabled then payBtn:SetEnabled(canPayNow) end
      if clearBtn and clearBtn.SetEnabled then clearBtn:SetEnabled(controlsEnabled and (dueTax > 0)) end
    end

    -- Allow core logic to refresh the UI immediately after deposits.
    Tax._RefreshUI = Refresh

    scopeBtn:SetScript("OnClick", function()
      EnsureDB()
      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then return end
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      local cur = tostring(cdb.tax.scope or "guild"):lower()
      local nextScope = (cur == "guild") and "character" or "guild"
      cdb.tax.scope = nextScope
      Refresh()
    end)

    scopeBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      local ct = EnsureCharTaxDB()
      local scope = (ct and tostring(ct.scope or "guild"):lower()) or "guild"
      if scope ~= "guild" and scope ~= "character" then scope = "guild" end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if scope == "guild" then
        GameTooltip:SetText("Scope: GUILD\nEdits tax rate/sources/due for the current guild.")
      else
        GameTooltip:SetText("Scope: CHARACTER\nEdits tax rate/sources/due for this character only.")
      end
      GameTooltip:Show()
    end)
    scopeBtn:SetScript("OnLeave", function()
      if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    end)

    rateEdit:SetScript("OnTextChanged", function(self)
      if self._cleaning == true then return end
      EnsureDB()
      local db = GetDB()
      if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}

      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.cfg = (type(cdb.tax.cfg) == "table") and cdb.tax.cfg or {}
      cdb.tax.scope = tostring(cdb.tax.scope or "guild"):lower()
      if cdb.tax.scope ~= "guild" and cdb.tax.scope ~= "character" then cdb.tax.scope = "guild" end

      local cfg
      if cdb.tax.scope == "character" then
        cfg = cdb.tax.cfg
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        cfg = EnsureGuildTaxDB(guildKey)
        if not cfg then return end
      end

      local txt = self:GetText() or ""
      local clean = txt:gsub("%D+", "")
      if clean ~= txt then
        self._cleaning = true
        self:SetText(clean)
        self._cleaning = false
        txt = clean
      end

      local v = tonumber(txt)
      if not v then v = 0 end
      v = clampFn(v, 0, 100) or 0
      cfg.rate = v
      cfg.enabled = (v > 0)
      Refresh()
    end)

    minEdit:SetScript("OnTextChanged", function(self)
      EnsureDB()
      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then return end
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      local txt = self:GetText() or ""
      local clean = txt:gsub("[^%d]", "")
      if clean ~= txt and not (self._cleaning == true) and (self.HasFocus and self:HasFocus()) then
        self._cleaning = true
        self:SetText(clean)
        self._cleaning = false
        txt = clean
      end

      local v = tonumber(clean)
      if not v then v = 0 end
      v = clampFn(v, 0, 9999999) or 0
      cdb.tax.minGold = v
      Refresh()
    end)

    vendorBtn:SetScript("OnClick", function()
      EnsureDB()
      local db = GetDB(); if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}

      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.cfg = (type(cdb.tax.cfg) == "table") and cdb.tax.cfg or {}
      cdb.tax.scope = tostring(cdb.tax.scope or "guild"):lower()
      if cdb.tax.scope ~= "guild" and cdb.tax.scope ~= "character" then cdb.tax.scope = "guild" end

      local cfg
      if cdb.tax.scope == "character" then
        cfg = cdb.tax.cfg
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        cfg = EnsureGuildTaxDB(guildKey)
        if not cfg then return end
      end
      cfg.sources = (type(cfg.sources) == "table") and cfg.sources or {}
      cfg.sources.vendor = not (cfg.sources.vendor == true)
      Refresh()
    end)

    lootBtn:SetScript("OnClick", function()
      EnsureDB()
      local db = GetDB(); if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}

      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.cfg = (type(cdb.tax.cfg) == "table") and cdb.tax.cfg or {}
      cdb.tax.scope = tostring(cdb.tax.scope or "guild"):lower()
      if cdb.tax.scope ~= "guild" and cdb.tax.scope ~= "character" then cdb.tax.scope = "guild" end

      local cfg
      if cdb.tax.scope == "character" then
        cfg = cdb.tax.cfg
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        cfg = EnsureGuildTaxDB(guildKey)
        if not cfg then return end
      end
      cfg.sources = (type(cfg.sources) == "table") and cfg.sources or {}
      cfg.sources.questLoot = not (cfg.sources.questLoot == true)
      Refresh()
    end)

    mailBtn:SetScript("OnClick", function()
      EnsureDB()
      local db = GetDB(); if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}

      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.cfg = (type(cdb.tax.cfg) == "table") and cdb.tax.cfg or {}
      cdb.tax.scope = tostring(cdb.tax.scope or "guild"):lower()
      if cdb.tax.scope ~= "guild" and cdb.tax.scope ~= "character" then cdb.tax.scope = "guild" end

      local cfg
      if cdb.tax.scope == "character" then
        cfg = cdb.tax.cfg
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        cfg = EnsureGuildTaxDB(guildKey)
        if not cfg then return end
      end
      cfg.sources = (type(cfg.sources) == "table") and cfg.sources or {}
      cfg.sources.mail = not (cfg.sources.mail == true)
      Refresh()
    end)

    systemBtn:SetScript("OnClick", function()
      EnsureDB()
      local db = GetDB(); if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}

      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.cfg = (type(cdb.tax.cfg) == "table") and cdb.tax.cfg or {}
      cdb.tax.scope = tostring(cdb.tax.scope or "guild"):lower()
      if cdb.tax.scope ~= "guild" and cdb.tax.scope ~= "character" then cdb.tax.scope = "guild" end

      local cfg
      if cdb.tax.scope == "character" then
        cfg = cdb.tax.cfg
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        cfg = EnsureGuildTaxDB(guildKey)
        if not cfg then return end
      end
      cfg.sources = (type(cfg.sources) == "table") and cfg.sources or {}
      cfg.sources.systemMoney = not (cfg.sources.systemMoney == true)
      Refresh()
    end)

    autoBtn:SetScript("OnClick", function()
      EnsureDB()
      local db = GetDB(); if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}

      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.cfg = (type(cdb.tax.cfg) == "table") and cdb.tax.cfg or {}
      cdb.tax.scope = tostring(cdb.tax.scope or "guild"):lower()
      if cdb.tax.scope ~= "guild" and cdb.tax.scope ~= "character" then cdb.tax.scope = "guild" end

      local cfg
      if cdb.tax.scope == "character" then
        cfg = cdb.tax.cfg
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        cfg = EnsureGuildTaxDB(guildKey)
        if not cfg then return end
      end
      cfg.autoPayOnGuildBankOpen = not (cfg.autoPayOnGuildBankOpen == true)
      Refresh()
    end)

    scBtn:SetScript("OnClick", function()
      EnsureDB()
      local ct = EnsureCharTaxDB()
      if type(ct) ~= "table" then return end

      local scope = tostring(ct.scope or "guild"):lower()
      if scope == "character" then
        ct.showOwedSilverCopper = not (ct.showOwedSilverCopper == true)
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        local g = EnsureGuildTaxDB(guildKey)
        if type(g) ~= "table" then return end
        g.showOwedSilverCopper = not (g.showOwedSilverCopper == true)
      end
      Refresh()
    end)

    withdrawBtn:SetScript("OnClick", function()
      EnsureDB()
      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then return end
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.allowWithdraw = not (cdb.tax.allowWithdraw == true)
      Refresh()
    end)

    debugBtn:SetScript("OnClick", function()
      EnsureDB()
      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then return end
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.debug = not (cdb.tax.debug == true)
      Refresh()
    end)

    withdrawBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Allows lending Guild funds up to the Min Gold balance.\nRepaid after other Taxes, Interest of 11.49% pa applies.")
      GameTooltip:Show()
    end)
    withdrawBtn:SetScript("OnLeave", function() if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end)

    clearBtn:SetScript("OnEnter", function(self)
      -- Only show this tooltip when Withdraw lending is enabled.
      local ct = EnsureCharTaxDB()
      if not (ct and ct.allowWithdraw == true) then return end
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Clears normal tax due only.\nWithdrawn funds cannot be cleared.")
      GameTooltip:Show()
    end)
    clearBtn:SetScript("OnLeave", function() if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end)

    -- Tooltips
    lootBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Looted includes quest rewards and looted money.")
      GameTooltip:Show()
    end)
    lootBtn:SetScript("OnLeave", function() if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end)

    systemBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("System money can be risky.\nLootIt tries to reuse its own money parsing to reduce false positives.")
      GameTooltip:Show()
    end)
    systemBtn:SetScript("OnLeave", function() if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end)

    payBtn:SetScript("OnClick", function()
      local _, cfg, bal = GetActiveScopeCfgAndBal()
      if type(cfg) ~= "table" then return end
      if type(bal) ~= "table" then return end
      if (tonumber(bal.dueTax) or 0) <= 0 and (tonumber(bal.dueBorrowed) or 0) <= 0 and (tonumber(bal.due) or 0) <= 0 then return end
      Tax.PayNow()
    end)

    clearBtn:SetScript("OnClick", function()
      Tax.ClearDue()
      Refresh()
    end)

    panel:SetScript("OnShow", Refresh)
    Refresh()
  end
end
