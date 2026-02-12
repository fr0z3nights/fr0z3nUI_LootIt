---@diagnostic disable: undefined-global
local LI = fr0z3nUI_LootIt or {}
fr0z3nUI_LootIt = LI
LI.TabardUI = LI.TabardUI or {}

function LI.TabardUI.BuildTab(tabardPanel, env)
  if not tabardPanel then return end

  local EnsureDB = env and env.EnsureDB
  local GetDB = env and env.GetDB
  local GetCharDB = env and env.GetCharDB
  local Clamp = env and env.Clamp
  local SetCheckBoxText = env and env.SetCheckBoxText

  if type(EnsureDB) ~= "function" then EnsureDB = function(...) end end
  if type(GetDB) ~= "function" then GetDB = function(...) return nil end end
  if type(GetCharDB) ~= "function" then GetCharDB = function(...) return nil end end
  if type(Clamp) ~= "function" then
    Clamp = function(v, minV, maxV)
      v = tonumber(v) or 0
      minV = tonumber(minV)
      maxV = tonumber(maxV)
      if minV and v < minV then v = minV end
      if maxV and v > maxV then v = maxV end
      return v
    end
  end
  if type(SetCheckBoxText) ~= "function" then SetCheckBoxText = function(...) end end

  local tabardTitle = tabardPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  tabardTitle:SetPoint("TOPLEFT", tabardPanel, "TOPLEFT", 10, -10)
  tabardTitle:SetText("")
  if tabardTitle.Hide then tabardTitle:Hide() end

  local function GetTabardEnableMode()
    local mod = _G and rawget(_G, "fr0z3nUI_LootItTabard")
    if mod and mod.GetEnableMode then
      return mod.GetEnableMode()
    end
    EnsureDB()
    local DB = GetDB()
    local CHARDB = GetCharDB()
    if CHARDB and CHARDB.tabardEnabledOverride == true then return "on" end
    if CHARDB and CHARDB.tabardEnabledOverride == false then return "off" end
    if DB and DB.tabard and DB.tabard.enabled then return "acc" end
    return "off"
  end

  local function SetTabardEnableMode(mode)
    local mod = _G and rawget(_G, "fr0z3nUI_LootItTabard")
    if mod and mod.SetEnableMode then
      mod.SetEnableMode(mode)
      return
    end
    EnsureDB()
    local DB = GetDB()
    local CHARDB = GetCharDB()
    if not (DB and CHARDB) then return end

    DB.tabard = (type(DB.tabard) == "table") and DB.tabard or {}
    mode = tostring(mode or ""):lower()
    if mode == "on" then
      CHARDB.tabardEnabledOverride = true
    elseif mode == "acc" then
      CHARDB.tabardEnabledOverride = nil
      DB.tabard.enabled = true
    else
      CHARDB.tabardEnabledOverride = false
    end
  end

  local tabardEnableLabel = tabardPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  tabardEnableLabel:SetPoint("TOPLEFT", tabardPanel, "TOPLEFT", 10, -10)
  tabardEnableLabel:SetText("")
  if tabardEnableLabel.Hide then tabardEnableLabel:Hide() end

  local tabardEnableModeBtn = CreateFrame("Button", nil, tabardPanel, "UIPanelButtonTemplate")
  tabardEnableModeBtn:SetSize(90, 20)
  tabardEnableModeBtn:SetPoint("TOPLEFT", tabardPanel, "TOPLEFT", 10, -10)

  local function RefreshTabardEnableModeButton()
    if not (tabardEnableModeBtn and tabardEnableModeBtn.SetText) then return end
    local m = GetTabardEnableMode()
    tabardEnableModeBtn:SetText((m == "on") and "On" or ((m == "acc") and "On Acc" or "Off"))
  end

  tabardEnableModeBtn:SetScript("OnClick", function()
    local cur = GetTabardEnableMode()
    local nextMode = (cur == "off") and "on" or ((cur == "on") and "acc" or "off")
    SetTabardEnableMode(nextMode)
    RefreshTabardEnableModeButton()
  end)

  tabardEnableModeBtn:SetScript("OnEnter", function(self)
    if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
    local m = GetTabardEnableMode()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Enable")
    GameTooltip:AddLine("Cycles: On / On Acc / Off", 0.85, 0.85, 0.85, true)
    GameTooltip:AddLine("Current: " .. ((m == "on") and "On" or ((m == "acc") and "On Acc" or "Off")), 0.85, 0.85, 0.85, true)
    GameTooltip:Show()
  end)
  tabardEnableModeBtn:SetScript("OnLeave", function()
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
  end)

  local function TabardMod()
    return _G and rawget(_G, "fr0z3nUI_LootItTabard")
  end

  local function EnsureTabardDB()
    EnsureDB()
    local DB = GetDB()
    if not DB then return {} end

    DB.tabard = (type(DB.tabard) == "table") and DB.tabard or {}
    DB.tabard.modeByContext = (type(DB.tabard.modeByContext) == "table") and DB.tabard.modeByContext or {
      solo = "nochange",
      city = "closest",
      dungeon = "closest",
      raid = "nochange",
      pvp = "nochange",
    }
    if DB.tabard.delay == nil then DB.tabard.delay = 0.75 end
    if DB.tabard.hideRepBarWhenNoChampion == nil then DB.tabard.hideRepBarWhenNoChampion = false end
    return DB.tabard
  end

  local function NotifyTabardSettingsChanged(reason)
    local mod = TabardMod()
    if mod and mod.OnSettingsChanged then
      mod.OnSettingsChanged(reason or "ui")
    end
  end

  -- Context mode controls
  local tabardModeTitle = tabardPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  tabardModeTitle:SetPoint("TOPLEFT", tabardEnableModeBtn, "BOTTOMLEFT", 0, -18)
  tabardModeTitle:SetText("Context modes")

  local MODE_LABELS = {
    nochange = "No change",
    closest = "Closest to Exalted",
    furthest = "Furthest from Exalted",
    lowest = "Lowest rep",
    random = "Random",
    faction = "Faction (cities)",
    auto = "Auto",
    none = "Unequip",
  }

  local MODE_ORDER = { "nochange", "closest", "furthest", "lowest", "random", "auto", "faction", "none" }

  local function CreateModeDropDown(name, anchor, yOffset)
    local label = tabardPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    label:SetText(name)

    local dd = CreateFrame("Frame", nil, tabardPanel, "UIDropDownMenuTemplate")
    dd:SetPoint("LEFT", label, "RIGHT", -6, -2)
    UIDropDownMenu_SetWidth(dd, 170)
    return label, dd
  end

  local soloLabel, soloDD = CreateModeDropDown("Solo", tabardModeTitle, -8)
  local cityLabel, cityDD = CreateModeDropDown("City", soloLabel, -8)
  local dungeonLabel, dungeonDD = CreateModeDropDown("Dungeon", cityLabel, -8)
  local raidLabel, raidDD = CreateModeDropDown("Raid", dungeonLabel, -8)
  local pvpLabel, pvpDD = CreateModeDropDown("PvP", raidLabel, -8)

  local function SetModeFor(ctx, mode)
    local tdb = EnsureTabardDB()
    tdb.modeByContext[ctx] = tostring(mode or "nochange")
    NotifyTabardSettingsChanged("mode")
  end

  local function GetModeFor(ctx)
    local tdb = EnsureTabardDB()
    return tostring((tdb.modeByContext and tdb.modeByContext[ctx]) or "nochange")
  end

  local function InitModeDropDown(dd, ctx)
    UIDropDownMenu_Initialize(dd, function(_, level)
      if level ~= 1 then return end
      local current = GetModeFor(ctx)
      for _, key in ipairs(MODE_ORDER) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = MODE_LABELS[key] or key
        info.value = key
        info.checked = (key == current)
        info.func = function()
          UIDropDownMenu_SetText(dd, MODE_LABELS[key] or key)
          SetModeFor(ctx, key)
        end
        UIDropDownMenu_AddButton(info, level)
      end
    end)
  end

  InitModeDropDown(soloDD, "solo")
  InitModeDropDown(cityDD, "city")
  InitModeDropDown(dungeonDD, "dungeon")
  InitModeDropDown(raidDD, "raid")
  InitModeDropDown(pvpDD, "pvp")

  -- Delay + misc
  local delayLabel = tabardPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  delayLabel:SetPoint("TOPLEFT", pvpLabel, "BOTTOMLEFT", 0, -14)
  delayLabel:SetText("Delay")

  local delaySlider = CreateFrame("Slider", nil, tabardPanel, "OptionsSliderTemplate")
  delaySlider:SetPoint("LEFT", delayLabel, "RIGHT", 14, 0)
  delaySlider:SetWidth(180)
  delaySlider:SetMinMaxValues(0, 3.0)
  delaySlider:SetValueStep(0.05)
  delaySlider:SetObeyStepOnDrag(true)
  if delaySlider.Low then delaySlider.Low:SetText("0") end
  if delaySlider.High then delaySlider.High:SetText("3.0") end
  if delaySlider.Text then delaySlider.Text:SetText("") end

  local delayValue = tabardPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  delayValue:SetPoint("LEFT", delaySlider, "RIGHT", 10, 0)
  delayValue:SetText("0.75s")

  delaySlider:SetScript("OnValueChanged", function(self, value)
    local tdb = EnsureTabardDB()
    local v = Clamp(value or 0, 0, 3.0)
    tdb.delay = v
    delayValue:SetText(string.format("%.2fs", v))
    NotifyTabardSettingsChanged("delay")
  end)

  local repCB = CreateFrame("CheckButton", nil, tabardPanel, "UICheckButtonTemplate")
  repCB:SetPoint("TOPLEFT", delayLabel, "BOTTOMLEFT", 0, -10)
  SetCheckBoxText(repCB, "Hide rep bar when not championing")
  repCB:SetScript("OnClick", function(self)
    local tdb = EnsureTabardDB()
    tdb.hideRepBarWhenNoChampion = self:GetChecked() and true or false
    NotifyTabardSettingsChanged("repbar")
  end)

  local swapBtn = CreateFrame("Button", nil, tabardPanel, "UIPanelButtonTemplate")
  swapBtn:SetSize(90, 20)
  swapBtn:SetPoint("TOPLEFT", repCB, "BOTTOMLEFT", 0, -10)
  swapBtn:SetText("Swap Now")
  swapBtn:SetScript("OnClick", function()
    local mod = TabardMod()
    if mod and mod.MaybeSwap then mod.MaybeSwap("ui") end
  end)

  local dbgBtn = CreateFrame("Button", nil, tabardPanel, "UIPanelButtonTemplate")
  dbgBtn:SetSize(90, 20)
  dbgBtn:SetPoint("LEFT", swapBtn, "RIGHT", 10, 0)
  dbgBtn:SetText("Debug")
  dbgBtn:SetScript("OnClick", function()
    local mod = TabardMod()
    if mod and mod.Debug then mod.Debug() end
  end)

  local tip = tabardPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  tip:SetPoint("TOPLEFT", swapBtn, "BOTTOMLEFT", 0, -10)
  tip:SetJustifyH("LEFT")
  tip:SetText("Tip: If you don't want auto-equips in towns, set City to 'No change'.")

  local function RefreshTabardControls()
    RefreshTabardEnableModeButton()
    local tdb = EnsureTabardDB()
    UIDropDownMenu_SetText(soloDD, MODE_LABELS[GetModeFor("solo")] or GetModeFor("solo"))
    UIDropDownMenu_SetText(cityDD, MODE_LABELS[GetModeFor("city")] or GetModeFor("city"))
    UIDropDownMenu_SetText(dungeonDD, MODE_LABELS[GetModeFor("dungeon")] or GetModeFor("dungeon"))
    UIDropDownMenu_SetText(raidDD, MODE_LABELS[GetModeFor("raid")] or GetModeFor("raid"))
    UIDropDownMenu_SetText(pvpDD, MODE_LABELS[GetModeFor("pvp")] or GetModeFor("pvp"))
    local d = tonumber(tdb.delay) or 0.75
    delaySlider:SetValue(Clamp(d, 0, 3.0))
    delayValue:SetText(string.format("%.2fs", Clamp(d, 0, 3.0)))
    repCB:SetChecked(tdb.hideRepBarWhenNoChampion and true or false)
  end

  tabardPanel.Refresh = RefreshTabardControls

  tabardPanel:SetScript("OnShow", RefreshTabardEnableModeButton)
  tabardPanel:SetScript("OnShow", RefreshTabardControls)
end
