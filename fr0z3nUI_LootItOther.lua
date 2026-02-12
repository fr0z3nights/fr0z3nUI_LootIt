---@diagnostic disable: undefined-global
local LI = fr0z3nUI_LootIt or {}
fr0z3nUI_LootIt = LI

LI.Other = LI.Other or {}

function LI.Other.BuildTab(otherPanel, env)
  if not otherPanel then return end
  env = env or {}

  local EnsureDB = env.EnsureDB or function() end
  local GetDB = env.GetDB or function() return _G and rawget(_G, "fr0z3nUI_LootItDB") end
  local ApplyFilters = env.ApplyFilters or function() end

  local SetCheckBoxText = env.SetCheckBoxText or LI.SetCheckBoxText or function() end
  local SetCheckBoxChecked = env.SetCheckBoxChecked or LI.SetCheckBoxChecked or function() end

  local otherTitle = otherPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  otherTitle:SetPoint("TOPLEFT", otherPanel, "TOPLEFT", 10, -10)
  otherTitle:SetText("Other")

  local achCB = CreateFrame("CheckButton", nil, otherPanel, "UICheckButtonTemplate")
  achCB:SetPoint("TOPLEFT", otherTitle, "BOTTOMLEFT", 0, -10)
  SetCheckBoxText(achCB, "Achievement")
  achCB:SetScript("OnClick", function(self)
    EnsureDB()
    local DB = GetDB()
    if not DB then return end
    DB.other = (type(DB.other) == "table") and DB.other or {}
    DB.other.achievement = (type(DB.other.achievement) == "table") and DB.other.achievement or {}
    DB.other.achievement.enabled = self:GetChecked() and true or false
    ApplyFilters()
  end)

  do
    local t = achCB.Text or achCB.text
    if t and t.ClearAllPoints and t.SetPoint then
      if achCB and achCB.SetSize then
        achCB:SetSize(24, 24)
      end
      t:ClearAllPoints()
      t:SetPoint("LEFT", achCB, "RIGHT", 3, 0)

      if achCB and achCB.SetHitRectInsets and t.GetStringWidth then
        local w = tonumber(t:GetStringWidth()) or 0
        if w > 0 then
          achCB:SetHitRectInsets(0, -(w + 10), 0, 0)
        end
      end
    end
  end

  local otherOutputLabel = otherPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  otherOutputLabel:SetPoint("LEFT", (achCB.Text or achCB.text) or achCB, "RIGHT", 18, 0)
  otherOutputLabel:SetText("Output")

  local otherOutputDD = CreateFrame("Frame", "fr0z3nUI_LootIt_OtherOutputDropDown", otherPanel, "UIDropDownMenuTemplate")
  otherOutputDD:SetPoint("LEFT", otherOutputLabel, "RIGHT", -6, -2)
  UIDropDownMenu_SetWidth(otherOutputDD, 140)

  do
    local mu = _G and rawget(_G, "MenuUtil")
    if type(mu) == "table" and type(mu.CreateContextMenu) == "function" then
      local anchor = otherOutputDD.Button or otherOutputDD
      if anchor and anchor.SetScript then
        anchor:SetScript("OnClick", function(btn)
          mu.CreateContextMenu(btn, function(_, root)
            if root and root.CreateTitle then root:CreateTitle("Output") end
            EnsureDB()
            local DB = GetDB()
            if not DB then return end
            DB.other = (type(DB.other) == "table") and DB.other or {}
            for i = 1, (NUM_CHAT_WINDOWS or 1) do
              local name = GetChatWindowInfo and GetChatWindowInfo(i)
              if not name or name == "" then name = "Chat " .. i end
              local label = string.format("%d: %s", i, name)
              if root and root.CreateRadio then
                root:CreateRadio(label, function() return (DB.other.outputChatFrame == i) end, function()
                  EnsureDB()
                  local DB2 = GetDB()
                  if not DB2 then return end
                  DB2.other = (type(DB2.other) == "table") and DB2.other or {}
                  DB2.other.outputChatFrame = i
                  if UIDropDownMenu_SetSelectedID then UIDropDownMenu_SetSelectedID(otherOutputDD, i) end
                end)
              elseif root and root.CreateButton then
                root:CreateButton(label, function()
                  EnsureDB()
                  local DB2 = GetDB()
                  if not DB2 then return end
                  DB2.other = (type(DB2.other) == "table") and DB2.other or {}
                  DB2.other.outputChatFrame = i
                  if UIDropDownMenu_SetSelectedID then UIDropDownMenu_SetSelectedID(otherOutputDD, i) end
                end)
              end
            end
          end)
        end)
      end
    else
      UIDropDownMenu_Initialize(otherOutputDD, function(_, level)
        level = level or 1
        if level ~= 1 then return end
        EnsureDB()
        local DB = GetDB()
        if not DB then return end
        DB.other = (type(DB.other) == "table") and DB.other or {}

        for i = 1, (NUM_CHAT_WINDOWS or 1) do
          local name = GetChatWindowInfo and GetChatWindowInfo(i)
          if not name or name == "" then
            name = "Chat " .. i
          end

          local info = UIDropDownMenu_CreateInfo()
          info.text = string.format("%d: %s", i, name)
          info.checked = (DB.other.outputChatFrame == i)
          info.func = function()
            EnsureDB()
            local DB2 = GetDB()
            if not DB2 then return end
            DB2.other = (type(DB2.other) == "table") and DB2.other or {}
            DB2.other.outputChatFrame = i
            UIDropDownMenu_SetSelectedID(otherOutputDD, i)
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

  local exampleTitle = otherPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  exampleTitle:SetPoint("TOPLEFT", achCB, "BOTTOMLEFT", 0, -14)
  exampleTitle:SetText("Achievement Format")

  local ex1 = otherPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ex1:SetPoint("TOPLEFT", exampleTitle, "BOTTOMLEFT", 0, -6)
  ex1:SetJustifyH("LEFT")
  ex1:SetText("[Character] has earned the achievement [link]")

  local ex2 = otherPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ex2:SetPoint("TOPLEFT", ex1, "BOTTOMLEFT", 0, -4)
  ex2:SetJustifyH("LEFT")
  ex2:SetText("Character: earned Link!")

  otherPanel.Refresh = function()
    EnsureDB()
    local DB = GetDB()
    if not DB then return end
    DB.other = (type(DB.other) == "table") and DB.other or {}
    DB.other.achievement = (type(DB.other.achievement) == "table") and DB.other.achievement or {}
    SetCheckBoxChecked(achCB, DB.other.achievement.enabled == true)
    UIDropDownMenu_SetSelectedID(otherOutputDD, DB.other.outputChatFrame or 1)
  end
end
