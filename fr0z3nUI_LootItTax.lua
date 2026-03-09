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
    warbankOpen = false,
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

    -- Balances are per-character by default (stored in character savedvars).
    -- Optionally, guild scope can use a shared per-guild balance bucket (behind a per-guild toggle).
    -- Clear legacy account-wide balances once to avoid stale/phantom owed values.
    if t._balanceMode ~= "character" then
      t._balanceMode = "character"

      -- Legacy account-wide fields.
      t.due = 0
      t.dueTax = 0
      t.dueBorrowed = 0
      t.paidToDate = 0
      t.borrowedLastTS = 0
    end

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

    -- Bank move prints (deposit/withdraw). Scope-scoped; stored per guild when in Guild scope.
    if g.bankPrintEnabled == nil then g.bankPrintEnabled = true end
    g.bankPrintEnabled = (g.bankPrintEnabled == true)

    -- Manual bank move tracking (deposit/withdraw). Scope-scoped; stored per guild when in Guild scope.
    if g.manualBankMovesEnabled == nil then g.manualBankMovesEnabled = false end
    g.manualBankMovesEnabled = (g.manualBankMovesEnabled == true)

    -- Owed-scope toggle (saved per guild; only meaningful when viewing in Guild scope).
    if g.owedScope == nil then g.owedScope = "character" end
    g.owedScope = tostring(g.owedScope or "character"):lower()
    if g.owedScope ~= "character" and g.owedScope ~= "characters" then
      g.owedScope = "character"
    end

    -- Shared per-guild balance bucket (used when owedScope == "characters").
    g.sharedBal = (type(g.sharedBal) == "table") and g.sharedBal or {}
    local sb = g.sharedBal
    sb.due = math.floor(tonumber(sb.due) or 0)
    sb.paidToDate = math.floor(tonumber(sb.paidToDate) or 0)
    if sb.dueTax == nil and sb.dueBorrowed == nil then
      sb.dueTax = sb.due
      sb.dueBorrowed = 0
    end
    sb.dueTax = math.floor(tonumber(sb.dueTax) or 0)
    sb.dueBorrowed = math.floor(tonumber(sb.dueBorrowed) or 0)
    if sb.dueTax < 0 then sb.dueTax = 0 end
    if sb.dueBorrowed < 0 then sb.dueBorrowed = 0 end
    sb.borrowedLastTS = math.floor(tonumber(sb.borrowedLastTS) or 0)
    if sb.borrowedLastTS < 0 then sb.borrowedLastTS = 0 end
    sb.due = sb.dueTax + sb.dueBorrowed
    if sb.due < 0 then sb.due = 0 end
    if sb.paidToDate < 0 then sb.paidToDate = 0 end

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

    -- One-time migration: if legacy guild-bucket balances exist, seed sharedBal.
    if sb._migratedLegacy ~= true then
      local legacyDueTax = math.floor(tonumber(g.dueTax) or 0)
      local legacyDueBorrowed = math.floor(tonumber(g.dueBorrowed) or 0)
      local legacyPaid = math.floor(tonumber(g.paidToDate) or 0)
      local legacyLastTS = math.floor(tonumber(g.borrowedLastTS) or 0)
      if legacyDueTax < 0 then legacyDueTax = 0 end
      if legacyDueBorrowed < 0 then legacyDueBorrowed = 0 end
      if legacyPaid < 0 then legacyPaid = 0 end
      if legacyLastTS < 0 then legacyLastTS = 0 end

      if (sb.dueTax + sb.dueBorrowed + sb.paidToDate) <= 0 and (legacyDueTax + legacyDueBorrowed + legacyPaid) > 0 then
        sb.dueTax = legacyDueTax
        sb.dueBorrowed = legacyDueBorrowed
        sb.paidToDate = legacyPaid
        sb.borrowedLastTS = legacyLastTS
        sb.due = sb.dueTax + sb.dueBorrowed
      end
      sb._migratedLegacy = true
    end

    g.sources = (type(g.sources) == "table") and g.sources or {}
    if g.sources.vendor == nil then g.sources.vendor = true end
    if g.sources.questLoot == nil then g.sources.questLoot = true end
    if g.sources.systemMoney == nil then g.sources.systemMoney = false end
    if g.sources.mail == nil then g.sources.mail = true end

    -- Auto Pay is the only supported mode now; keep the field for backward compatibility,
    -- but enforce it on so there is no “manual-only” state.
    g.autoPayOnGuildBankOpen = true

    if g.showOwedSilverCopper == nil then g.showOwedSilverCopper = false end
    g.showOwedSilverCopper = (g.showOwedSilverCopper == true)

    -- Warbank support toggle (scope-scoped; stored per guild when in Guild scope).
    if g.warBankEnabled == nil then g.warBankEnabled = false end
    g.warBankEnabled = (g.warBankEnabled == true)

    -- Scope-scoped safety/borrowing controls.
    if g.minGold == nil then g.minGold = 0 end
    g.minGold = Clamp(g.minGold, 0, 9999999) or 0
    if g.minGold < 0 then g.minGold = 0 end
    if g.allowWithdraw == nil then g.allowWithdraw = false end
    g.allowWithdraw = (g.allowWithdraw == true)

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

    -- Bank move prints (deposit/withdraw). Scope-scoped; stored per character when in Character scope.
    if cfg.bankPrintEnabled == nil then cfg.bankPrintEnabled = true end
    cfg.bankPrintEnabled = (cfg.bankPrintEnabled == true)

    -- Manual bank move tracking (deposit/withdraw). Scope-scoped; stored per character when in Character scope.
    if cfg.manualBankMovesEnabled == nil then cfg.manualBankMovesEnabled = false end
    cfg.manualBankMovesEnabled = (cfg.manualBankMovesEnabled == true)
    cfg.sources = (type(cfg.sources) == "table") and cfg.sources or {}
    if cfg.sources.vendor == nil then cfg.sources.vendor = true end
    if cfg.sources.questLoot == nil then cfg.sources.questLoot = true end
    if cfg.sources.systemMoney == nil then cfg.sources.systemMoney = false end
    if cfg.sources.mail == nil then cfg.sources.mail = true end
    -- Auto Pay is the only supported mode now; keep the field for backward compatibility,
    -- but enforce it on so there is no “manual-only” state.
    cfg.autoPayOnGuildBankOpen = true
    cfg.enabled = (cfg.rate > 0)

    if cfg.warBankEnabled == nil then cfg.warBankEnabled = false end
    cfg.warBankEnabled = (cfg.warBankEnabled == true)

    -- Scope-scoped safety/borrowing controls live on the active cfg.
    -- Migrate legacy per-character fields (ct.minGold/ct.allowWithdraw) into cfg if present.
    if cfg.minGold == nil and ct.minGold ~= nil then cfg.minGold = ct.minGold end
    if cfg.allowWithdraw == nil and ct.allowWithdraw ~= nil then cfg.allowWithdraw = ct.allowWithdraw end
    if cfg.minGold == nil then cfg.minGold = 0 end
    cfg.minGold = Clamp(cfg.minGold, 0, 9999999) or 0
    if cfg.minGold < 0 then cfg.minGold = 0 end
    if cfg.allowWithdraw == nil then cfg.allowWithdraw = false end
    cfg.allowWithdraw = (cfg.allowWithdraw == true)

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

    -- Warbank balances are ALWAYS character-scoped.
    ct.warBal = (type(ct.warBal) == "table") and ct.warBal or {}
    ct.warBal.due = math.floor(tonumber(ct.warBal.due) or 0)
    ct.warBal.paidToDate = math.floor(tonumber(ct.warBal.paidToDate) or 0)
    if ct.warBal.dueTax == nil and ct.warBal.dueBorrowed == nil then
      ct.warBal.dueTax = ct.warBal.due
      ct.warBal.dueBorrowed = 0
    end
    ct.warBal.dueTax = math.floor(tonumber(ct.warBal.dueTax) or 0)
    ct.warBal.dueBorrowed = math.floor(tonumber(ct.warBal.dueBorrowed) or 0)
    if ct.warBal.dueTax < 0 then ct.warBal.dueTax = 0 end
    if ct.warBal.dueBorrowed < 0 then ct.warBal.dueBorrowed = 0 end
    ct.warBal.due = ct.warBal.dueTax + ct.warBal.dueBorrowed
    if ct.warBal.due < 0 then ct.warBal.due = 0 end
    if ct.warBal.paidToDate < 0 then ct.warBal.paidToDate = 0 end

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
      -- Config is guild-scoped, but without a guild we only have character balances.
      return "guild", nil, (ct and ct.bal) or nil
    end
    local g = EnsureGuildTaxDB(guildKey)
    if type(g) == "table" and g.owedScope == "characters" then
      return "guild", g, (g.sharedBal)
    end
    return "guild", g, (ct and ct.bal) or nil
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

  local function GetClassColoredPlayerName()
    local n = (UnitName and UnitName("player")) or ""
    n = tostring(n or "")
    local short = n:match("^(.-)%-%") or n
    if short == "" then short = "Player" end

    local classFile = nil
    if type(UnitClass) == "function" then
      local _, c = UnitClass("player")
      classFile = c
    end

    local r, g, b = 1, 1, 1
    if classFile and type(C_ClassColor) == "table" and type(C_ClassColor.GetClassColor) == "function" then
      local ok, colorObj = pcall(C_ClassColor.GetClassColor, classFile)
      if ok and type(colorObj) == "table" then
        if type(colorObj.GetRGB) == "function" then
          local rr, gg, bb = colorObj:GetRGB()
          r, g, b = tonumber(rr) or r, tonumber(gg) or g, tonumber(bb) or b
        elseif type(colorObj.r) == "number" then
          r, g, b = colorObj.r or r, colorObj.g or g, colorObj.b or b
        end
      end
    elseif classFile and type(RAID_CLASS_COLORS) == "table" and type(RAID_CLASS_COLORS[classFile]) == "table" then
      local c = RAID_CLASS_COLORS[classFile]
      r, g, b = tonumber(c.r) or r, tonumber(c.g) or g, tonumber(c.b) or b
    end

    local function toHex(x)
      x = tonumber(x) or 0
      if x < 0 then x = 0 end
      if x > 1 then x = 1 end
      return string.format("%02x", math.floor(x * 255 + 0.5))
    end

    return "|cff" .. toHex(r) .. toHex(g) .. toHex(b) .. short .. ":|r"
  end

  local function FormatGoldOnly(totalCopper)
    local copper = tonumber(totalCopper) or 0
    if copper < 0 then copper = 0 end
    local gold = math.floor(copper / 10000)
    if gold < 1 then gold = 1 end
    return tostring(gold) .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
  end

  local function PrintBankMove(cfg, copper, direction, bank)
    if type(cfg) ~= "table" then return end
    if cfg.quiet == true then return end
    if not (cfg.bankPrintEnabled == true) then return end
    copper = math.floor(tonumber(copper) or 0)
    if copper <= 0 then return end
    Print(GetClassColoredPlayerName() .. " " .. FormatGoldOnly(copper) .. " " .. tostring(direction or "") .. " " .. tostring(bank or ""))
  end

  local function PushPendingDelta(queue, delta)
    if type(queue) ~= "table" then return end
    delta = math.floor(tonumber(delta) or 0)
    if delta == 0 then return end
    queue[#queue + 1] = delta
  end

  local function PopIfMatches(queue, delta)
    if type(queue) ~= "table" or #queue == 0 then return false end
    delta = math.floor(tonumber(delta) or 0)
    if delta == 0 then return false end
    if queue[1] ~= delta then return false end
    table.remove(queue, 1)
    return true
  end

  local function ApplyManualDepositOrWithdraw(cfg, bal, delta, bankLabel)
    if type(cfg) ~= "table" or type(bal) ~= "table" then return end
    if not (cfg.manualBankMovesEnabled == true) then
      if IsTaxDebugEnabled() and not (cfg.quiet == true) then
        Print("Manual " .. tostring(bankLabel or "Bank") .. " ignored: Manual OFF.")
      end
      return
    end

    delta = math.floor(tonumber(delta) or 0)
    if delta == 0 then return end

    if IsTaxDebugEnabled() and not (cfg.quiet == true) then
      Print("Manual " .. tostring(bankLabel or "Bank") .. " delta: " .. tostring(delta))
    end

    -- delta > 0 => player gained money => withdrew from bank.
    if delta > 0 then
      bal.dueBorrowed = math.floor((tonumber(bal.dueBorrowed) or 0) + delta)
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
      PrintBankMove(cfg, delta, "withdrawn from", bankLabel)
      RequestUIRefresh()
      return
    end

    -- delta < 0 => player spent money => deposited to bank.
    local deposit = -delta
    if deposit <= 0 then return end

    local dueTax = math.floor(tonumber(bal.dueTax) or 0)
    local dueBorrowed = math.floor(tonumber(bal.dueBorrowed) or 0)
    if dueTax < 0 then dueTax = 0 end
    if dueBorrowed < 0 then dueBorrowed = 0 end
    local due = dueTax + dueBorrowed
    if due <= 0 then
      if IsTaxDebugEnabled() and not (cfg.quiet == true) then
        Print("Manual " .. tostring(bankLabel or "Bank") .. " deposit ignored: nothing owed.")
      end
      return
    end

    local pay = deposit
    if pay > due then pay = due end
    if pay <= 0 then return end

    local payTax = pay
    if payTax > dueTax then payTax = dueTax end
    local remain = pay - payTax
    local payBorrowed = remain
    if payBorrowed > dueBorrowed then payBorrowed = dueBorrowed end

    bal.dueTax = math.floor(dueTax - payTax)
    bal.dueBorrowed = math.floor(dueBorrowed - payBorrowed)
    if bal.dueTax < 0 then bal.dueTax = 0 end
    if bal.dueBorrowed < 0 then bal.dueBorrowed = 0 end
    bal.due = bal.dueTax + bal.dueBorrowed
    bal.paidToDate = math.floor((tonumber(bal.paidToDate) or 0) + pay)

    PrintBankMove(cfg, pay, "deposited to", bankLabel)
    RequestUIRefresh()
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

    -- Warbank: when enabled, accrue the same tax percentage to the character-only warbank bucket.
    if cfg.warBankEnabled == true then
      local ct = EnsureCharTaxDB()
      local wb = ct and ct.warBal
      if type(wb) == "table" then
        wb.dueTax = math.floor((tonumber(wb.dueTax) or 0) + taxCopper)
        if wb.dueTax < 0 then wb.dueTax = 0 end
        wb.dueBorrowed = math.floor(tonumber(wb.dueBorrowed) or 0)
        if wb.dueBorrowed < 0 then wb.dueBorrowed = 0 end
        wb.due = wb.dueTax + wb.dueBorrowed
      end
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
    local minGold
    if type(cfg) == "table" and cfg.minGold ~= nil then
      minGold = tonumber(cfg.minGold) or 0
    else
      -- Backward compatibility fallback (pre-scope-scoped Min Gold).
      minGold = ct and (tonumber(ct.minGold) or 0) or 0
    end
    if minGold < 0 then minGold = 0 end
    local minCopper = math.floor(minGold * (COPPER_PER_GOLD or 10000))
    if minCopper < 0 then minCopper = 0 end

    local allowWithdraw
    if type(cfg) == "table" and cfg.allowWithdraw ~= nil then
      allowWithdraw = (cfg.allowWithdraw == true)
    else
      -- Backward compatibility fallback (pre-scope-scoped Withdraw).
      allowWithdraw = (ct and ct.allowWithdraw == true) and true or false
    end

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
        state._pendingGuildDeltas = (type(state._pendingGuildDeltas) == "table") and state._pendingGuildDeltas or {}
        PushPendingDelta(state._pendingGuildDeltas, -toPay)
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
          PrintBankMove(cfg, toPay, "deposited to", "Guild Bank")
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
            state._pendingGuildDeltas = (type(state._pendingGuildDeltas) == "table") and state._pendingGuildDeltas or {}
            PushPendingDelta(state._pendingGuildDeltas, need)
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
                PrintBankMove(cfg, need, "withdrawn from", "Guild Bank")
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

  local function TryPayWarbank(isAuto)
    local _, cfg = GetActiveScopeCfgAndBal()
    if type(cfg) ~= "table" then return end
    if not (cfg.warBankEnabled == true) then return end

    -- Throttle: WarBank open detection can fire from multiple UI paths (tab switches,
    -- interaction manager, money updates). Prevent overlapping deposit timers.
    do
      local now = 0
      if type(GetTime) == "function" then
        now = tonumber(GetTime()) or 0
      elseif type(time) == "function" then
        now = tonumber(time()) or 0
      end
      state._tryPayWarbankTS = tonumber(state._tryPayWarbankTS) or 0
      if now > 0 and (now - state._tryPayWarbankTS) < 0.35 then
        return
      end
      if now > 0 then
        state._tryPayWarbankTS = now
      end
    end

    local ct = EnsureCharTaxDB()
    local wb = ct and ct.warBal
    if type(wb) ~= "table" then return end

    local bankType = (Enum and Enum.BankType) and Enum.BankType or nil
    if not (bankType and bankType.Account) then return end
    if not (C_Bank and type(C_Bank.DepositMoney) == "function" and type(C_Bank.WithdrawMoney) == "function") then return end

    local minGold = tonumber(cfg.minGold) or 0
    if minGold < 0 then minGold = 0 end
    local minCopper = math.floor(minGold * (COPPER_PER_GOLD or 10000))
    if minCopper < 0 then minCopper = 0 end

    local function CanDeposit()
      if C_Bank and type(C_Bank.CanDepositMoney) == "function" then
        local ok, can = pcall(C_Bank.CanDepositMoney, bankType.Account)
        if ok and can == false then
          return false
        end
      end
      return true
    end

    local function CanWithdraw()
      if C_Bank and type(C_Bank.CanWithdrawMoney) == "function" then
        local ok, can = pcall(C_Bank.CanWithdrawMoney, bankType.Account)
        if ok and can == false then
          return false
        end
      end
      return true
    end

    local function DoDeposit()
      local dueTax = math.floor(tonumber(wb.dueTax) or 0)
      local dueBorrowed = math.floor(tonumber(wb.dueBorrowed) or 0)
      if dueTax < 0 then dueTax = 0 end
      if dueBorrowed < 0 then dueBorrowed = 0 end
      local due = dueTax + dueBorrowed
      if due <= 0 then return end

      if not CanDeposit() then
        RequestUIRefresh()
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
        return
      end

      C_Timer.After(0.30, function()
        state._pendingWarbankDeltas = (type(state._pendingWarbankDeltas) == "table") and state._pendingWarbankDeltas or {}
        PushPendingDelta(state._pendingWarbankDeltas, -toPay)
        local ok = pcall(C_Bank.DepositMoney, bankType.Account, toPay)
        if ok then
          local payTax = toPay
          if payTax > dueTax then payTax = dueTax end
          local remain = toPay - payTax
          local payBorrowed = remain
          if payBorrowed > dueBorrowed then payBorrowed = dueBorrowed end

          wb.dueTax = math.floor(dueTax - payTax)
          wb.dueBorrowed = math.floor(dueBorrowed - payBorrowed)
          if wb.dueTax < 0 then wb.dueTax = 0 end
          if wb.dueBorrowed < 0 then wb.dueBorrowed = 0 end
          wb.due = wb.dueTax + wb.dueBorrowed
          wb.paidToDate = math.floor((tonumber(wb.paidToDate) or 0) + toPay)
          PrintBankMove(cfg, toPay, "deposited to", "WarBank")
          RequestUIRefresh()
        else
          RequestUIRefresh()
        end
      end)
    end

    -- Always allow borrowing from Warbank up to Min Gold.
    if minCopper > 0 then
      local money = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
      if money < minCopper then
        local need = math.floor(minCopper - money)
        if need > 0 and CanWithdraw() then
          state._pendingWarbankDeltas = (type(state._pendingWarbankDeltas) == "table") and state._pendingWarbankDeltas or {}
          PushPendingDelta(state._pendingWarbankDeltas, need)
          local ok = pcall(C_Bank.WithdrawMoney, bankType.Account, need)
          if ok then
            wb.dueBorrowed = math.floor((tonumber(wb.dueBorrowed) or 0) + need)
            if wb.dueBorrowed < 0 then wb.dueBorrowed = 0 end
            wb.dueTax = math.floor(tonumber(wb.dueTax) or 0)
            if wb.dueTax < 0 then wb.dueTax = 0 end
            wb.due = wb.dueTax + wb.dueBorrowed
            PrintBankMove(cfg, need, "withdrawn from", "WarBank")
            RequestUIRefresh()
            C_Timer.After(0.60, DoDeposit)
            return
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
      if state.guildBankOpen then
        state._manualPrevMoney = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
        state._pendingGuildDeltas = {}
      else
        state._manualPrevMoney = nil
        state._pendingGuildDeltas = {}
      end
      if isShow then
        -- Guild bank APIs/permissions can be briefly unavailable on the first frame.
        -- A small delay here makes auto-pay/borrow consistent across client paths.
        if C_Timer and C_Timer.After then
          C_Timer.After(0.25, function() TryPayGuildBank(true) end)
        else
          TryPayGuildBank(true)
        end
      end
      RequestUIRefresh()
      return
    end

    if interactionType == it.AccountBanker then
      state.warbankOpen = (isShow == true)
      if state.warbankOpen then
        state._manualPrevMoneyWar = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
        state._pendingWarbankDeltas = {}
      else
        state._manualPrevMoneyWar = nil
        state._pendingWarbankDeltas = {}
      end
      if isShow then
        if C_Timer and C_Timer.After then
          C_Timer.After(0.25, function() TryPayWarbank(true) end)
        else
          TryPayWarbank(true)
        end
      end
      RequestUIRefresh()
      return
    end
  end

  -- Some interaction paths only fire the classic guild bank frame events (GUILDBANKFRAME_*),
  -- not PlayerInteractionManager. Expose a dedicated entrypoint so the core event handler can
  -- keep Tax in sync without needing Enum.PlayerInteractionType.
  function Tax.OnGuildBankFrame(isOpen)
    state.guildBankOpen = (isOpen == true)
    if state.guildBankOpen then
      state._manualPrevMoney = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
      state._pendingGuildDeltas = {}
    else
      state._manualPrevMoney = nil
      state._pendingGuildDeltas = {}
    end
    if state.guildBankOpen then
      if C_Timer and C_Timer.After then
        C_Timer.After(0.25, function() TryPayGuildBank(true) end)
      else
        TryPayGuildBank(true)
      end
    end
    RequestUIRefresh()
  end

  -- Warbank frame state can be embedded in the main BankFrame and may not always
  -- surface as PlayerInteractionManager.AccountBanker. Expose an entrypoint so
  -- the core event handler can keep Tax in sync.
  function Tax.OnWarbankFrame(isOpen)
    state.warbankOpen = (isOpen == true)
    if state.warbankOpen then
      state._manualPrevMoneyWar = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
      state._pendingWarbankDeltas = {}
    else
      state._manualPrevMoneyWar = nil
      state._pendingWarbankDeltas = {}
    end
    if state.warbankOpen then
      if C_Timer and C_Timer.After then
        C_Timer.After(0.25, function() TryPayWarbank(true) end)
      else
        TryPayWarbank(true)
      end
    end
    RequestUIRefresh()
  end

  function Tax.PayNow()
    -- Prefer our tracked state, but also allow PayNow if the frame is visibly open.
    if not (state.guildBankOpen == true) then
      local f = _G and rawget(_G, "GuildBankFrame")
      local shown = (f and f.IsShown and f:IsShown()) and true or false
      if not shown then
        return
      end
      state.guildBankOpen = true
    end
    TryPayGuildBank(false)
  end

  function Tax.OnPlayerMoney()
    local money = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)

    -- Guild bank manual moves.
    if state.guildBankOpen == true and state._manualPrevMoney ~= nil then
      local delta = money - math.floor(tonumber(state._manualPrevMoney) or 0)
      if delta ~= 0 then
        state._manualPrevMoney = money

        state._pendingGuildDeltas = (type(state._pendingGuildDeltas) == "table") and state._pendingGuildDeltas or {}
        if not PopIfMatches(state._pendingGuildDeltas, delta) then
          local _, cfg, bal = GetActiveScopeCfgAndBal()
          if type(cfg) == "table" and type(bal) == "table" then
            ApplyManualDepositOrWithdraw(cfg, bal, delta, "Guild Bank")
          end
        end
      end
    end

    -- Warbank manual moves.
    if state.warbankOpen == true and state._manualPrevMoneyWar ~= nil then
      local delta = money - math.floor(tonumber(state._manualPrevMoneyWar) or 0)
      if delta ~= 0 then
        state._manualPrevMoneyWar = money

        state._pendingWarbankDeltas = (type(state._pendingWarbankDeltas) == "table") and state._pendingWarbankDeltas or {}
        if not PopIfMatches(state._pendingWarbankDeltas, delta) then
          local _, cfg = GetActiveScopeCfgAndBal()
          if type(cfg) == "table" and cfg.warBankEnabled == true then
            local ct = EnsureCharTaxDB()
            local wb = ct and ct.warBal
            if type(wb) == "table" then
              ApplyManualDepositOrWithdraw(cfg, wb, delta, "WarBank")
            end
          end
        end
      end
    end

    -- If WarBank is open and we are below Min Gold, re-run the WarBank borrow logic.
    -- This matters when the player manually deposits/spends gold while the WarBank UI
    -- remains open (no "open" event fires again).
    if state.warbankOpen == true then
      local _, cfg = GetActiveScopeCfgAndBal()
      if type(cfg) == "table" and cfg.warBankEnabled == true then
        local minGold = tonumber(cfg.minGold) or 0
        if minGold < 0 then minGold = 0 end
        local minCopper = math.floor(minGold * (COPPER_PER_GOLD or 10000))
        if minCopper > 0 and money < minCopper then
          local now = 0
          if type(GetTime) == "function" then
            now = tonumber(GetTime()) or 0
          elseif type(time) == "function" then
            now = tonumber(time()) or 0
          end
          state._autoWarbankBorrowTS = tonumber(state._autoWarbankBorrowTS) or 0
          if now <= 0 or (now - state._autoWarbankBorrowTS) >= 0.40 then
            state._autoWarbankBorrowTS = (now > 0) and now or state._autoWarbankBorrowTS
            if C_Timer and C_Timer.After then
              C_Timer.After(0, function() TryPayWarbank(true) end)
            else
              TryPayWarbank(true)
            end
          end
        end
      end
    end
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

  function Tax.ClearDueWarbank()
    local ct = EnsureCharTaxDB()
    local wb = ct and ct.warBal
    if type(wb) ~= "table" then return end
    wb.dueTax = 0
    wb.dueBorrowed = math.floor(tonumber(wb.dueBorrowed) or 0)
    if wb.dueBorrowed < 0 then wb.dueBorrowed = 0 end
    wb.due = math.floor(tonumber(wb.dueTax) or 0) + math.floor(tonumber(wb.dueBorrowed) or 0)
  end

  function Tax.BuildTab(panel, env)
    if not panel then return end
    if panel._taxBuilt then return end
    panel._taxBuilt = true

    env = env or {}

    local EnsureDB = env.EnsureDB or function() end
    local GetDB = env.GetDB or function() return _G and rawget(_G, "fr0z3nUI_LootItDB") end

    local Refresh

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

    local GUILDNAME_H = 28

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

    local scopeBtnHL = scopeBtn:CreateTexture(nil, "BACKGROUND")
    scopeBtnHL:SetAllPoints(scopeBtn)
    scopeBtnHL:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    scopeBtnHL:SetBlendMode("ADD")
    scopeBtnHL:SetVertexColor(0.55, 0.25, 0.85, 0.45)
    scopeBtnHL:Hide()

    local scopeBtnText = scopeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    scopeBtnText:SetPoint("CENTER", scopeBtn, "CENTER", 0, 0)
    SetFontStringSize(scopeBtnText, 16)

    -- Percent input (borderless)
    local rateEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    rateEdit:SetSize(260, 32)
    -- Leave space for the guild name row between Scope and Rate.
    rateEdit:SetPoint("TOP", scopeBtn, "BOTTOM", 0, -(GUILDNAME_H + GAP_Y + 4))
    rateEdit:SetAutoFocus(false)
    rateEdit:SetMaxLetters(3)
    local RATE_INSET_L, RATE_INSET_R = 6, 18
    rateEdit:SetTextInsets(RATE_INSET_L, RATE_INSET_R, 0, 0)
    rateEdit:SetJustifyH("CENTER")
    if rateEdit.SetJustifyV then rateEdit:SetJustifyV("MIDDLE") end
    if rateEdit.SetNumeric then rateEdit:SetNumeric(true) end
    if rateEdit.GetFont and rateEdit.SetFont then
      local fontPath, _, fontFlags = rateEdit:GetFont()
      if fontPath then rateEdit:SetFont(fontPath, 20, fontFlags) end
    end
    HideEditBoxFrame(rateEdit)

    local ratePH = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    ratePH:SetPoint("CENTER", rateEdit, "CENTER", 0, 0)
    ratePH:SetText("Tax %")
    ratePH:SetTextColor(1, 1, 1, 0.35)

    local rateSuffix = rateEdit:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rateSuffix:SetText("%")
    rateSuffix:SetTextColor(1, 1, 1, 0.95)
    SetFontStringSize(rateSuffix, 20)
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
    guildNameRow:SetPoint("LEFT", panel, "LEFT", 0, 0)
    guildNameRow:SetPoint("RIGHT", panel, "RIGHT", 0, 0)

    local guildNamePadTop = math.floor((tonumber(GAP_Y) or 0) / 2)
    local guildNamePadBottom = (tonumber(GAP_Y) or 0) - guildNamePadTop
    if guildNamePadTop < 0 then guildNamePadTop = 0 end
    if guildNamePadBottom < 0 then guildNamePadBottom = 0 end

    local guildNameEdit = CreateFrame("EditBox", nil, guildNameRow, "InputBoxTemplate")
    guildNameEdit:SetPoint("TOPLEFT", guildNameRow, "TOPLEFT", 0, -guildNamePadTop)
    guildNameEdit:SetPoint("BOTTOMRIGHT", guildNameRow, "BOTTOMRIGHT", 0, guildNamePadBottom)
    guildNameEdit:SetAutoFocus(false)
    guildNameEdit:SetTextInsets(6, 6, 0, 0)
    guildNameEdit:SetJustifyH("CENTER")
    if guildNameEdit.SetJustifyV then guildNameEdit:SetJustifyV("MIDDLE") end
    if guildNameEdit.EnableMouse then guildNameEdit:EnableMouse(false) end
    if guildNameEdit.SetEnabled then guildNameEdit:SetEnabled(true) end

    local guildNameFontPath, _, guildNameFontFlags
    if guildNameEdit.GetFont then
      guildNameFontPath, _, guildNameFontFlags = guildNameEdit:GetFont()
    end
    if type(guildNameFontPath) ~= "string" or guildNameFontPath == "" then
      guildNameFontPath = "Fonts\\FRIZQT__.TTF"
    end
    local GUILDNAME_FONT_MAX = 30
    local GUILDNAME_FONT_MIN = 10
    if guildNameEdit.SetFont then
      guildNameEdit:SetFont(guildNameFontPath, GUILDNAME_FONT_MAX, guildNameFontFlags)
    end

    local function FitGuildNameToBox()
      if not (guildNameEdit and guildNameEdit.SetFont and guildNameEdit.GetWidth and guildNameEdit.GetText) then return end

      local text = tostring(guildNameEdit:GetText() or "")
      if text == "" then
        guildNameEdit:SetFont(guildNameFontPath, GUILDNAME_FONT_MAX, guildNameFontFlags)
        return
      end

      local w = tonumber(guildNameEdit:GetWidth() or 0) or 0
      local insetL, insetR = 6, 6
      local available = w - insetL - insetR
      if available <= 0 then return end

      local size = GUILDNAME_FONT_MAX
      guildNameEdit:SetFont(guildNameFontPath, size, guildNameFontFlags)

      local textW = (guildNameEdit.GetTextWidth and guildNameEdit:GetTextWidth()) or 0
      if type(textW) ~= "number" then textW = 0 end

      while size > GUILDNAME_FONT_MIN and textW > available do
        size = size - 1
        guildNameEdit:SetFont(guildNameFontPath, size, guildNameFontFlags)
        textW = (guildNameEdit.GetTextWidth and guildNameEdit:GetTextWidth()) or 0
        if type(textW) ~= "number" then textW = 0 end
      end
    end

    if guildNameEdit.HookScript then
      guildNameEdit:HookScript("OnSizeChanged", FitGuildNameToBox)
      guildNameEdit:HookScript("OnTextChanged", FitGuildNameToBox)
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

    -- Scope-scoped Min Gold (borderless), matching Trade tab input size/position.
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
    local function CreateOwedRow(parent, withHighlight)
      local row = CreateFrame("Frame", nil, parent)
      row:SetPoint("TOP", rateEdit, "BOTTOM", 0, -GAP_Y) -- final position set after sourcesRow exists
      row:SetSize(240, 28)

      local hl
      if withHighlight == true then
        hl = row:CreateTexture(nil, "BACKGROUND")
        hl:SetAllPoints(row)
        hl:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
        hl:SetBlendMode("ADD")
        hl:SetVertexColor(0.55, 0.25, 0.85, 0.45)
        hl:Hide()
      end

      local goldFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
      local silverFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
      local copperFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
      SetFSSize(goldFS, COIN_TEXT_SIZE_OWED)
      SetFSSize(silverFS, COIN_TEXT_SIZE_OWED)
      SetFSSize(copperFS, COIN_TEXT_SIZE_OWED)
      goldFS:SetTextColor(1.0, 0.82, 0.0, 1)
      silverFS:SetTextColor(0.78, 0.78, 0.81, 1)
      copperFS:SetTextColor(0.93, 0.65, 0.37, 1)

      local goldIcon = row:CreateTexture(nil, "OVERLAY")
      goldIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
      goldIcon:SetSize(COIN_W, COIN_H)

      local silverIcon = row:CreateTexture(nil, "OVERLAY")
      silverIcon:SetTexture("Interface\\MoneyFrame\\UI-SilverIcon")
      silverIcon:SetSize(COIN_W, COIN_H)

      local copperIcon = row:CreateTexture(nil, "OVERLAY")
      copperIcon:SetTexture("Interface\\MoneyFrame\\UI-CopperIcon")
      copperIcon:SetSize(COIN_W, COIN_H)

      local function Update(copper, showSilverCopper)
        copper = math.floor(tonumber(copper) or 0)
        if copper < 0 then copper = 0 end

        local g = math.floor(copper / (COPPER_PER_GOLD or 10000))
        local rem = copper - (g * (COPPER_PER_GOLD or 10000))
        local s = math.floor(rem / (COPPER_PER_SILVER or 100))
        local c = math.floor(rem - (s * (COPPER_PER_SILVER or 100)))

        goldFS:SetText(FormatIntWithCommas(g))
        silverFS:SetText(tostring(s))
        copperFS:SetText(tostring(c))

        local preIcon = 4
        local postCoin = 10

        goldFS:ClearAllPoints()
        goldIcon:ClearAllPoints()
        silverFS:ClearAllPoints()
        silverIcon:ClearAllPoints()
        copperFS:ClearAllPoints()
        copperIcon:ClearAllPoints()

        local wG = goldFS.GetStringWidth and goldFS:GetStringWidth() or 0
        if wG < 0 then wG = 0 end

        local availW = (row and row.GetWidth and row:GetWidth()) or 0
        if availW < 0 then availW = 0 end

        if showSilverCopper == true then
          silverFS:Show(); silverIcon:Show()
          copperFS:Show(); copperIcon:Show()

          local wS = silverFS.GetStringWidth and silverFS:GetStringWidth() or 0
          local wC = copperFS.GetStringWidth and copperFS:GetStringWidth() or 0
          if wS < 0 then wS = 0 end
          if wC < 0 then wC = 0 end

          local totalW = wG + preIcon + COIN_W + postCoin + wS + preIcon + COIN_W + postCoin + wC + preIcon + COIN_W
          if totalW < 10 then totalW = 10 end
          local startX = 0
          if availW > totalW then
            startX = (availW - totalW) / 2
          end

          goldFS:SetPoint("LEFT", row, "LEFT", startX, 0)
          goldIcon:SetPoint("CENTER", goldFS, "RIGHT", preIcon + (COIN_W / 2), 0)

          silverFS:SetPoint("LEFT", goldIcon, "RIGHT", postCoin, 0)
          silverIcon:SetPoint("CENTER", silverFS, "RIGHT", preIcon + (COIN_W / 2), 0)

          copperFS:SetPoint("LEFT", silverIcon, "RIGHT", postCoin, 0)
          copperIcon:SetPoint("CENTER", copperFS, "RIGHT", preIcon + (COIN_W / 2), 0)
        else
          silverFS:Hide(); silverIcon:Hide()
          copperFS:Hide(); copperIcon:Hide()

          local totalW = wG + preIcon + COIN_W
          if totalW < 10 then totalW = 10 end
          local startX = 0
          if availW > totalW then
            startX = (availW - totalW) / 2
          end

          goldFS:SetPoint("LEFT", row, "LEFT", startX, 0)
          goldIcon:SetPoint("CENTER", goldFS, "RIGHT", preIcon + (COIN_W / 2), 0)
        end
      end

      return row, hl, Update
    end

    local warOwedRow, _, UpdateWarOwedRow = CreateOwedRow(panel, false)
    local guildOwedRow, guildOwedRowHL, UpdateGuildOwedRow = CreateOwedRow(panel, true)

    local owedScopeBtn = CreateFrame("Button", nil, guildOwedRow)
    owedScopeBtn:SetAllPoints(guildOwedRow)
    owedScopeBtn:RegisterForClicks("LeftButtonUp")
    owedScopeBtn:SetScript("OnClick", function()
      EnsureDB()
      local ct = EnsureCharTaxDB()
      local scope = (ct and tostring(ct.scope or "guild"):lower()) or "guild"
      if scope ~= "guild" then
        Refresh()
        return
      end
      local guildKey = select(1, GetCurrentGuildKeyAndName())
      if not guildKey then
        Refresh()
        return
      end
      local g = EnsureGuildTaxDB(guildKey)
      if type(g) ~= "table" then
        Refresh()
        return
      end
      if g.owedScope == "characters" then
        g.owedScope = "character"
      else
        g.owedScope = "characters"
      end
      Refresh()

      -- If the tooltip is currently showing for this button, refresh it immediately.
      if owedScopeBtn and owedScopeBtn.GetScript and GameTooltip and GameTooltip.IsOwned then
        local owned = false
        pcall(function() owned = GameTooltip:IsOwned(owedScopeBtn) end)
        local over = (type(MouseIsOver) == "function") and MouseIsOver(owedScopeBtn) or false
        if owned or over then
          local onEnter = owedScopeBtn:GetScript("OnEnter")
          if type(onEnter) == "function" then
            pcall(onEnter, owedScopeBtn)
          end
        end
      end
    end)

    local function PlaceTooltipDownRightOfCursor()
      if not (GameTooltip and GameTooltip.ClearAllPoints and GameTooltip.SetPoint) then return end
      if not (UIParent and UIParent.GetEffectiveScale) then return end
      if type(GetCursorPosition) ~= "function" then return end

      local x, y = GetCursorPosition()
      local scale = UIParent:GetEffectiveScale() or 1
      if scale <= 0 then scale = 1 end
      x = (tonumber(x) or 0) / scale
      y = (tonumber(y) or 0) / scale

      GameTooltip:ClearAllPoints()
      GameTooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x + 14, y - 14)
    end

    owedScopeBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end

      if guildOwedRowHL then guildOwedRowHL:Show() end

      local ct = EnsureCharTaxDB()
      local scope = (ct and tostring(ct.scope or "guild"):lower()) or "guild"
      if scope ~= "guild" then return end

      local guildKey = select(1, GetCurrentGuildKeyAndName())
      if not guildKey then return end

      local g = EnsureGuildTaxDB(guildKey)
      if type(g) ~= "table" then return end

      local mode = tostring(g.owedScope or "character"):lower()
      local txt
      if mode == "characters" then
        txt = "Owed Scope: CHARACTERS OWE\nGuild Tax is owed by all characters per guild.\nClick to toggle."
      else
        txt = "Owed Scope: CHARACTER OWES\nGuild Tax is owed by only this character.\nClick to toggle."
      end

      GameTooltip:SetOwner(self, "ANCHOR_NONE")
      PlaceTooltipDownRightOfCursor()
      GameTooltip:SetText(txt)
      GameTooltip:Show()
    end)
    owedScopeBtn:SetScript("OnLeave", function()
      if guildOwedRowHL then guildOwedRowHL:Hide() end
      if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    end)
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
      GameTooltip:SetText("Minimum gold to keep on the character.\n0 disables this feature.\nStored per-scope (Guild/Character).")
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

    -- Warbank toggle (left of Min Gold, opposite Withdraw).
    local warbankBtn = CreateTextToggleButton(panel)
    warbankBtn:SetPoint("BOTTOM", vendorBtn, "TOP", 0, 0)

    -- Clear Due buttons live below each owed amount.
    local clearWarBtn = CreateTextToggleButton(panel)
    local clearGuildBtn = CreateTextToggleButton(panel)

    local scBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    scBtn:SetSize(44, BTN_H)
    scBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    scBtn:SetText("")

    local scSilver = scBtn:CreateTexture(nil, "ARTWORK")
    scSilver:SetTexture("Interface\\MoneyFrame\\UI-SilverIcon")
    scSilver:SetSize(COIN_W, COIN_H)
    scSilver:SetPoint("CENTER", scBtn, "CENTER", -(COIN_W / 2) - 2, COIN_TEX_Y)

    local scCopper = scBtn:CreateTexture(nil, "ARTWORK")
    scCopper:SetTexture("Interface\\MoneyFrame\\UI-CopperIcon")
    scCopper:SetSize(COIN_W, COIN_H)
    scCopper:SetPoint("CENTER", scBtn, "CENTER", (COIN_W / 2) + 2, COIN_TEX_Y)

    -- Initial layout; Refresh() finalizes positions.
    warOwedRow:ClearAllPoints()
    guildOwedRow:ClearAllPoints()
    warOwedRow:SetPoint("TOP", sourcesRow, "BOTTOM", 0, -GAP_Y)
    guildOwedRow:SetPoint("TOP", sourcesRow, "BOTTOM", 0, -GAP_Y)

    clearWarBtn:ClearAllPoints()
    clearGuildBtn:ClearAllPoints()
    clearWarBtn:SetPoint("TOP", warOwedRow, "BOTTOM", 0, -2)
    clearGuildBtn:SetPoint("TOP", guildOwedRow, "BOTTOM", 0, -2)

    minEdit:ClearAllPoints()
    -- Keep Min Gold centered even when the owed rows split left/right.
    minEdit:SetPoint("TOP", sourcesRow, "BOTTOM", 0, -(GAP_Y + 28 + 2 + BTN_H + GAP_Y))

    local reloadBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reloadBtn:SetSize(BTN_W, BTN_H)
    reloadBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    reloadBtn:SetText("Reload UI")
    reloadBtn:SetScript("OnClick", function()
      local r = _G and _G["ReloadUI"]
      if r then r() end
    end)

    local SHORT_BTN_W = math.floor((tonumber(BTN_W) or 110) * 0.62)
    if SHORT_BTN_W < 54 then SHORT_BTN_W = 54 end
    if SHORT_BTN_W > (tonumber(BTN_W) or 110) then SHORT_BTN_W = (tonumber(BTN_W) or 110) end

    -- Debug toggle (gates all non-deposit Tax prints) - move next to Reload UI and make it a real button.
    local debugBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    debugBtn:SetSize(SHORT_BTN_W, BTN_H)
    debugBtn:SetPoint("BOTTOMRIGHT", reloadBtn, "BOTTOMLEFT", -BTN_GAP, 0)
    debugBtn:SetText("Debug")
    debugBtn._fs = (debugBtn.GetFontString and debugBtn:GetFontString()) or nil
    if not debugBtn._fs then
      local fs = debugBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      fs:SetPoint("CENTER", debugBtn, "CENTER", 0, 0)
      debugBtn._fs = fs
    end

    -- Print toggle (gates bank move prints: deposit/withdraw).
    local bankPrintBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    bankPrintBtn:SetSize(SHORT_BTN_W, BTN_H)
    bankPrintBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    bankPrintBtn:SetText("Print")
    bankPrintBtn._fs = (bankPrintBtn.GetFontString and bankPrintBtn:GetFontString()) or nil
    if not bankPrintBtn._fs then
      local fs = bankPrintBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      fs:SetPoint("CENTER", bankPrintBtn, "CENTER", 0, 0)
      bankPrintBtn._fs = fs
    end

    local manualBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    manualBtn:SetSize(SHORT_BTN_W, BTN_H)
    manualBtn:SetText("Manual")
    manualBtn._fs = (manualBtn.GetFontString and manualBtn:GetFontString()) or nil
    if not manualBtn._fs then
      local fs = manualBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      fs:SetPoint("CENTER", manualBtn, "CENTER", 0, 0)
      manualBtn._fs = fs
    end

    -- Move Debug + SC next to Print.
    debugBtn:ClearAllPoints()
    debugBtn:SetPoint("BOTTOMLEFT", bankPrintBtn, "BOTTOMRIGHT", BTN_GAP, 0)

    scBtn:ClearAllPoints()
    scBtn:SetPoint("BOTTOMLEFT", debugBtn, "BOTTOMRIGHT", BTN_GAP, 0)

    manualBtn:ClearAllPoints()
    manualBtn:SetPoint("BOTTOMLEFT", scBtn, "BOTTOMRIGHT", BTN_GAP, 0)

    panel:HookScript("OnHide", function() end)

    Refresh = function()
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

      FitGuildNameToBox()

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

      -- Normalize split balances (per-character): normal tax due vs borrowed/withdrawn debt.
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

      local cfg
      local bal
      if scope == "character" then
        cfg = ct.cfg
        bal = ct.bal
      else
        cfg = guildKey and EnsureGuildTaxDB(guildKey) or nil
        if type(cfg) == "table" and cfg.owedScope == "characters" then
          bal = cfg.sharedBal
        else
          bal = ct.bal
        end
      end

      if type(bal) == "table" then AccrueBorrowedInterest(bal) end

      -- If guild scope and no guild, treat cfg as disabled with defaults.
      local viewCfg = cfg
      local viewBal = bal
      if type(viewCfg) ~= "table" then
        viewCfg = {
          enabled = false,
          rate = 0,
          quiet = false,
          sources = { vendor = true, questLoot = true, systemMoney = false, mail = true },
          autoPayOnGuildBankOpen = true,
          minGold = 0,
          allowWithdraw = false,
          warBankEnabled = false,
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
      if viewCfg.minGold == nil then viewCfg.minGold = 0 end
      if viewCfg.allowWithdraw == nil then viewCfg.allowWithdraw = false end
      if viewCfg.warBankEnabled == nil then viewCfg.warBankEnabled = false end

      if viewCfg.bankPrintEnabled == nil then viewCfg.bankPrintEnabled = true end
      if viewCfg.manualBankMovesEnabled == nil then viewCfg.manualBankMovesEnabled = false end

      local rate = clampFn(viewCfg.rate, 0, 100) or 0
      viewCfg.rate = rate
      viewCfg.enabled = (rate > 0)

      -- Disable SCOPE-SCOPED config controls when in Guild scope but not currently in a guild.
      local cfgControlsEnabled = true
      if scope == "guild" and not guildKey then cfgControlsEnabled = false end

      -- Split balances: Clear Due only clears normal tax due (not borrowed/withdrawn debt).
      local viewDueTax = viewBal.dueTax
      if viewDueTax == nil then viewDueTax = viewBal.due end
      local dueTax = math.floor(tonumber(viewDueTax) or 0)
      local dueBorrowed = math.floor(tonumber(viewBal.dueBorrowed) or 0)
      if dueTax < 0 then dueTax = 0 end
      if dueBorrowed < 0 then dueBorrowed = 0 end
      local dueTotal = dueTax + dueBorrowed
      if dueTotal < 0 then dueTotal = 0 end

      local ct2 = EnsureCharTaxDB()
      local showSilverCopper
      if scope == "guild" then
        showSilverCopper = (type(cfg) == "table") and (cfg.showOwedSilverCopper == true) or false
      else
        showSilverCopper = (ct2 and ct2.showOwedSilverCopper == true)
      end

      -- Warbank balance is always character-only.
      local warBal = (type(ct2) == "table") and ct2.warBal or nil
      if type(warBal) ~= "table" then
        warBal = { dueTax = 0, dueBorrowed = 0, due = 0, paidToDate = 0 }
        if type(ct2) == "table" then ct2.warBal = warBal end
      end
      if warBal.dueTax == nil and warBal.dueBorrowed == nil then
        warBal.dueTax = warBal.due
        warBal.dueBorrowed = 0
      end
      local warDueTax = math.floor(tonumber(warBal.dueTax) or 0)
      local warDueBorrowed = math.floor(tonumber(warBal.dueBorrowed) or 0)
      if warDueTax < 0 then warDueTax = 0 end
      if warDueBorrowed < 0 then warDueBorrowed = 0 end
      local warDueTotal = warDueTax + warDueBorrowed
      if warDueTotal < 0 then warDueTotal = 0 end

      local showWarbank = (type(viewCfg) == "table") and (viewCfg.warBankEnabled == true)
      if showWarbank then
        if warOwedRow and warOwedRow.Show then warOwedRow:Show() end
        if clearWarBtn and clearWarBtn.Show then clearWarBtn:Show() end
      else
        if warOwedRow and warOwedRow.Hide then warOwedRow:Hide() end
        if clearWarBtn and clearWarBtn.Hide then clearWarBtn:Hide() end
      end

      if guildOwedRow and guildOwedRow.Show then guildOwedRow:Show() end
      if clearGuildBtn and clearGuildBtn.Show then clearGuildBtn:Show() end

      UpdateGuildOwedRow(dueTotal, showSilverCopper)
      UpdateWarOwedRow(warDueTotal, showSilverCopper)

      -- Enable owed-scope toggle only in Guild scope and while in a guild.
      if owedScopeBtn and owedScopeBtn.EnableMouse then
        owedScopeBtn:EnableMouse((scope == "guild") and (guildKey ~= nil))
      end

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

      local minGold = (type(viewCfg) == "table") and (tonumber(viewCfg.minGold) or 0) or 0
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
      SetToggleText(withdrawBtn, "Withdraw", (type(viewCfg) == "table") and (viewCfg.allowWithdraw == true))
      SetToggleText(warbankBtn, "WarBank", (type(viewCfg) == "table") and (viewCfg.warBankEnabled == true))
      SetToggleText(debugBtn, "Debug", (ct and ct.debug == true))
      SetToggleText(bankPrintBtn, "Print", (type(viewCfg) == "table") and (viewCfg.bankPrintEnabled == true))
      SetToggleText(manualBtn, "Manual", (type(viewCfg) == "table") and (viewCfg.manualBankMovesEnabled == true))

      -- Action button state
      SetToggleText(clearGuildBtn, "Guild Bank", (dueTax > 0))
      SetToggleText(clearWarBtn, "WarBank", (warDueTax > 0))

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

      -- Keep Min Gold centered under the (potentially split) Due section.
      do
        local owedH = (guildOwedRow and guildOwedRow.GetHeight and guildOwedRow:GetHeight()) or 28
        local y = -((tonumber(GAP_Y) or 0) + owedH + 2 + (tonumber(BTN_H) or 22) + (tonumber(GAP_Y) or 0))
        minEdit:ClearAllPoints()
        minEdit:SetPoint("TOP", sourcesRow, "BOTTOM", 0, y)
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

      -- Place WarBank aligned with the Min Gold input row, and horizontally aligned over Vendor.
      do
        local pLeft = panel.GetLeft and panel:GetLeft() or nil
        local pBottom = panel.GetBottom and panel:GetBottom() or nil
        local vLeft = vendorBtn.GetLeft and vendorBtn:GetLeft() or nil
        local _, mY
        if minEdit and minEdit.GetCenter then
          _, mY = minEdit:GetCenter()
        end

        if pLeft and pBottom and vLeft and mY then
          warbankBtn:ClearAllPoints()
          warbankBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", (vLeft - pLeft), (mY - pBottom) - (BTN_H / 2))
        else
          -- Fallback: above Vendor.
          warbankBtn:ClearAllPoints()
          warbankBtn:SetPoint("BOTTOM", vendorBtn, "TOP", 0, 0)
        end
      end

      -- Place owed rows below the source row (WarBank left / Guild right when enabled).
      do
        local srCX = sourcesRow.GetCenter and sourcesRow:GetCenter() or nil
        if not srCX then
          guildOwedRow:ClearAllPoints()
          guildOwedRow:SetPoint("TOP", sourcesRow, "BOTTOM", 0, -GAP_Y)
          if showWarbank then
            warOwedRow:ClearAllPoints()
            warOwedRow:SetPoint("TOP", sourcesRow, "BOTTOM", 0, -GAP_Y)
          end
        else
          local pW = (panel and panel.GetWidth and panel:GetWidth()) or nil
          if (not pW) or pW <= 0 then
            local pL = panel and panel.GetLeft and panel:GetLeft() or nil
            local pR = panel and panel.GetRight and panel:GetRight() or nil
            if pL and pR then
              pW = pR - pL
            end
          end
          pW = tonumber(pW) or 0

          if showWarbank and pW > 10 then
            local x = pW / 4
            warOwedRow:ClearAllPoints()
            guildOwedRow:ClearAllPoints()
            warOwedRow:SetPoint("TOP", sourcesRow, "BOTTOM", -x, -GAP_Y)
            guildOwedRow:SetPoint("TOP", sourcesRow, "BOTTOM", x, -GAP_Y)
          else
            guildOwedRow:ClearAllPoints()
            guildOwedRow:SetPoint("TOP", sourcesRow, "BOTTOM", 0, -GAP_Y)
          end
        end

        clearGuildBtn:ClearAllPoints()
        clearGuildBtn:SetPoint("TOP", guildOwedRow, "BOTTOM", 0, -2)
        if showWarbank then
          clearWarBtn:ClearAllPoints()
          clearWarBtn:SetPoint("TOP", warOwedRow, "BOTTOM", 0, -2)
        end
      end

      -- Scope button UI
      scopeBtnText:SetText((scope == "character") and "CHARACTER" or "GUILD")
      if scopeBtnText and scopeBtnText.SetTextColor then
        scopeBtnText:SetTextColor(1.0, 0.82, 0.0, 1)
      end
      if rateEdit and rateEdit.SetEnabled then rateEdit:SetEnabled(cfgControlsEnabled) end
      if minEdit and minEdit.SetEnabled then minEdit:SetEnabled(cfgControlsEnabled) end
      if vendorBtn and vendorBtn.SetEnabled then vendorBtn:SetEnabled(cfgControlsEnabled) end
      if lootBtn and lootBtn.SetEnabled then lootBtn:SetEnabled(cfgControlsEnabled) end
      if mailBtn and mailBtn.SetEnabled then mailBtn:SetEnabled(cfgControlsEnabled) end
      if systemBtn and systemBtn.SetEnabled then systemBtn:SetEnabled(cfgControlsEnabled) end
      if withdrawBtn and withdrawBtn.SetEnabled then withdrawBtn:SetEnabled(cfgControlsEnabled) end
      if warbankBtn and warbankBtn.SetEnabled then warbankBtn:SetEnabled(cfgControlsEnabled) end
      if debugBtn and debugBtn.SetEnabled then debugBtn:SetEnabled(true) end
      if bankPrintBtn and bankPrintBtn.SetEnabled then bankPrintBtn:SetEnabled(cfgControlsEnabled) end
      if manualBtn and manualBtn.SetEnabled then manualBtn:SetEnabled(cfgControlsEnabled) end
      if clearGuildBtn and clearGuildBtn.SetEnabled then clearGuildBtn:SetEnabled(dueTax > 0) end
      if clearWarBtn and clearWarBtn.SetEnabled then clearWarBtn:SetEnabled(showWarbank and (warDueTax > 0)) end
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

      -- Refresh the tooltip immediately if still hovering.
      if scopeBtn and scopeBtn.GetScript and GameTooltip and GameTooltip.IsOwned then
        local owned = false
        pcall(function() owned = GameTooltip:IsOwned(scopeBtn) end)
        local over = (type(MouseIsOver) == "function") and MouseIsOver(scopeBtn) or false
        if owned or over then
          local onEnter = scopeBtn:GetScript("OnEnter")
          if type(onEnter) == "function" then
            pcall(onEnter, scopeBtn)
          end
        end
      end
    end)

    scopeBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end

      if scopeBtnHL then scopeBtnHL:Show() end

      local ct = EnsureCharTaxDB()
      local scope = (ct and tostring(ct.scope or "guild"):lower()) or "guild"
      if scope ~= "guild" and scope ~= "character" then scope = "guild" end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if scope == "guild" then
        GameTooltip:SetText("Scope: GUILD\nEdits tax rate/sources/min/withdraw for the current guild.\nOwed amount can be toggled (Character Owes / Characters Owe), saved per guild.")
      else
        GameTooltip:SetText("Scope: CHARACTER\nEdits tax rate/sources/min/withdraw for this character only.\nOwed scope is locked to Character Owes.")
      end
      GameTooltip:Show()
    end)
    scopeBtn:SetScript("OnLeave", function()
      if scopeBtnHL then scopeBtnHL:Hide() end
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
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.cfg = (type(cdb.tax.cfg) == "table") and cdb.tax.cfg or {}
      cdb.tax.scope = tostring(cdb.tax.scope or "guild"):lower()
      if cdb.tax.scope ~= "guild" and cdb.tax.scope ~= "character" then cdb.tax.scope = "guild" end

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

      local cfg
      if cdb.tax.scope == "character" then
        cfg = cdb.tax.cfg
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        cfg = EnsureGuildTaxDB(guildKey)
        if not cfg then return end
      end

      cfg.minGold = v
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

    warbankBtn:SetScript("OnClick", function()
      EnsureDB()

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
      cfg.warBankEnabled = not (cfg.warBankEnabled == true)
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
      cfg.allowWithdraw = not (cfg.allowWithdraw == true)
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

    bankPrintBtn:SetScript("OnClick", function()
      EnsureDB()
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
      cfg.bankPrintEnabled = not (cfg.bankPrintEnabled == true)
      Refresh()
    end)

    bankPrintBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Print Deposit/Withdraw")
      GameTooltip:Show()
    end)
    bankPrintBtn:SetScript("OnLeave", function() if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end)

    manualBtn:SetScript("OnClick", function()
      EnsureDB()
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
      cfg.manualBankMovesEnabled = not (cfg.manualBankMovesEnabled == true)
      Refresh()
    end)

    manualBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Count manual bank deposits/withdrawals")
      GameTooltip:Show()
    end)
    manualBtn:SetScript("OnLeave", function() if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end)

    withdrawBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Allows lending Guild funds up to the Min Gold balance.\nRepaid after other Taxes, Interest of 11.49% pa applies.")
      GameTooltip:Show()
    end)
    withdrawBtn:SetScript("OnLeave", function() if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end)

    clearGuildBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Clears Due, excluding Withdrawn Amount")
      GameTooltip:Show()
    end)
    clearGuildBtn:SetScript("OnLeave", function() if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end)

    clearWarBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Clears Due, excluding Withdrawn Amount")
      GameTooltip:Show()
    end)
    clearWarBtn:SetScript("OnLeave", function() if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end)

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

    clearGuildBtn:SetScript("OnClick", function()
      Tax.ClearDue()
      Refresh()
    end)

    clearWarBtn:SetScript("OnClick", function()
      Tax.ClearDueWarbank()
      Refresh()
    end)

    panel:SetScript("OnShow", Refresh)
    Refresh()
  end
end
