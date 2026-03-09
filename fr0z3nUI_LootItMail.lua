local LI = fr0z3nUI_LootIt or {}
fr0z3nUI_LootIt = LI

LI.Mail = LI.Mail or {}

do
  local Mail = LI.Mail
  Mail._notifierEnv = Mail._notifierEnv or {}

  -- While the mailbox UI is open, hide the notifier so it doesn't overlap the mailbox.
  -- Core toggles this via interaction events; UpdateMailNotifier enforces it.
  Mail._mailboxOpen = (Mail._mailboxOpen == true)

  function Mail.SetMailboxOpen(isOpen)
    Mail._mailboxOpen = (isOpen == true)
    if Mail._mailboxOpen and MailNotifier and MailNotifier.Hide then
      MailNotifier:Hide()
    end
  end

  function Mail.IsMailboxOpen()
    return (Mail._mailboxOpen == true)
  end

  function Mail.SetNotifierEnv(env)
    Mail._notifierEnv = (type(env) == "table") and env or {}
  end

  local function GetEnv()
    return Mail._notifierEnv or {}
  end

  local function ClampValue(v, mn, mx)
    local env = GetEnv()
    local clampFn = (env and rawget(env, "Clamp")) or (_G and rawget(_G, "Clamp"))
    if type(clampFn) == "function" then
      local ok, res = pcall(clampFn, v, mn, mx)
      if ok then
        return res
      end
    end

    v = tonumber(v)
    mn = tonumber(mn)
    mx = tonumber(mx)
    if not v then return mn end
    if mn and v < mn then return mn end
    if mx and v > mx then return mx end
    return v
  end

  local MAIL_TOY_KATY_STAMPWHISTLE = 156833

  local MailNotifier

  function Mail.GetMailNotifier()
    return MailNotifier
  end

  function Mail.ModelGetRotation(modelFrame)
    if not modelFrame then return 0 end
    if modelFrame.GetFacing then
      return modelFrame:GetFacing() or 0
    end
    if modelFrame.GetRotation then
      return modelFrame:GetRotation() or 0
    end
    return 0
  end

  function Mail.ModelSetRotation(modelFrame, rotation)
    if not modelFrame then return end
    rotation = tonumber(rotation) or 0
    if modelFrame.SetFacing then
      modelFrame:SetFacing(rotation)
      return
    end
    if modelFrame.SetRotation then
      modelFrame:SetRotation(rotation)
      return
    end
  end

  function Mail.ModelApplyZoom(modelFrame, zoom)
    if not modelFrame then return end
    zoom = tonumber(zoom)
    if not zoom then return end

    if modelFrame.SetCamDistanceScale then
      modelFrame:SetCamDistanceScale(zoom)
      return
    end
    if modelFrame.SetPortraitZoom then
      modelFrame:SetPortraitZoom(zoom)
      return
    end
    if modelFrame.SetModelScale then
      modelFrame:SetModelScale(zoom)
      return
    end
  end

  function Mail.ModelApplyAnimation(modelFrame, anim)
    if not modelFrame then return end
    anim = tonumber(anim)
    if anim == nil then return end
    if modelFrame.SetAnimation then
      modelFrame:SetAnimation(anim)
    end
  end

  local function FormatCooldown(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then return "0s" end
    if SecondsToTime then
      return SecondsToTime(seconds)
    end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    if m > 0 then
      return string.format("%dm %ds", m, s)
    end
    return string.format("%ds", s)
  end

  local function TryUseKatyStampwhistle()
    local env = GetEnv()
    local Print = env.Print or LI.Print or function(...) end

    local id = MAIL_TOY_KATY_STAMPWHISTLE

    if PlayerHasToy and not PlayerHasToy(id) then
      Print("You don't have Katy's Stampwhistle.")
      return
    end

    local start, duration, enable
    if C_ToyBox and C_ToyBox.GetToyCooldown then
      start, duration, enable = C_ToyBox.GetToyCooldown(id)
    end

    if enable == 1 and start and duration and duration > 0 then
      local remaining = (start + duration) - (GetTime and GetTime() or 0)
      if remaining and remaining > 0.25 then
        Print("Katy is busy rn, try again in [" .. FormatCooldown(remaining) .. "]")
        return
      end
    end

    if C_ToyBox and C_ToyBox.IsToyUsable and not C_ToyBox.IsToyUsable(id) then
      Print("Katy is not usable right now.")
      return
    end

    if UseToy then
      UseToy(id)
    elseif C_ToyBox and C_ToyBox.UseToy then
      C_ToyBox.UseToy(id)
    else
      Print("Cannot use toys on this client.")
    end
  end

  function Mail.ApplyMailModelToFrame(modelFrame)
    if not modelFrame then return end
    local env = GetEnv()
    local EnsureDB = env.EnsureDB or function(...) end
    local MailNotifyCfg = env.MailNotifyCfg or function(...) return nil end

    EnsureDB()
    local mnc = MailNotifyCfg()
    local spec = mnc and mnc.model or nil
    local kind = tostring((spec and spec.kind) or "npc"):lower()
    local id = (spec and spec.id) or ((kind == "npc" or kind == "creature") and 104230) or nil

    if modelFrame.ClearModel then modelFrame:ClearModel() end

    if kind == "player" then
      if modelFrame.SetUnit then
        modelFrame:SetUnit("player")
      end
    elseif kind == "display" then
      local displayID = tonumber(id)
      if displayID and modelFrame.SetDisplayInfo then
        modelFrame:SetDisplayInfo(displayID)
      end
    elseif kind == "file" then
      local fileID = tonumber(id)
      if fileID and modelFrame.SetModelByFileID then
        modelFrame:SetModelByFileID(fileID)
      end
    elseif kind == "npc" or kind == "creature" then
      local npcID = tonumber(id)
      if npcID and modelFrame.SetCreature then
        modelFrame:SetCreature(npcID)
      end
    end

    local rotation = spec and tonumber(spec.rotation)
    if rotation then
      Mail.ModelSetRotation(modelFrame, rotation)
    end
    local zoom = spec and tonumber(spec.zoom)
    if zoom then
      Mail.ModelApplyZoom(modelFrame, zoom)
    end

    local anim = spec and tonumber(spec.anim)
    if anim ~= nil then
      Mail.ModelApplyAnimation(modelFrame, anim)
    end

    local a = mnc and mnc.ui and tonumber(mnc.ui.alpha)
    if a and modelFrame.SetAlpha then
      modelFrame:SetAlpha(ClampValue(a, 0.10, 1.00))
    end
  end

  function Mail.ApplyMailNotifierInteractivity()
    if not MailNotifier then return end
    local env = GetEnv()
    local IsMailEditorOpen = env.IsMailEditorOpen or function(...) return false end

    local pickerOpen = IsMailEditorOpen() and true or false
    local shiftDown = (IsShiftKeyDown and IsShiftKeyDown()) and true or false
    local interactive = pickerOpen or shiftDown

    MailNotifier:EnableMouse(true)
    if MailNotifier.SetMouseClickEnabled then
      local ok = pcall(MailNotifier.SetMouseClickEnabled, MailNotifier, interactive)
      if not ok then
        pcall(MailNotifier.SetMouseClickEnabled, MailNotifier, "LeftButton", interactive)
        pcall(MailNotifier.SetMouseClickEnabled, MailNotifier, "RightButton", interactive)
      end
    elseif MailNotifier.SetPropagateMouseClicks then
      pcall(MailNotifier.SetPropagateMouseClicks, MailNotifier, not interactive)
    else
      MailNotifier:EnableMouse(interactive)
    end

    if not pickerOpen then
      MailNotifier:SetMovable(false)
      MailNotifier:RegisterForDrag()
    else
      MailNotifier:SetMovable(true)
      MailNotifier:RegisterForDrag("LeftButton")
    end
  end

  function Mail.CreateMailNotifier()
    if MailNotifier then return MailNotifier end

    local env = GetEnv()
    local EnsureDB = env.EnsureDB or function(...) end
    local MailNotifyCfg = env.MailNotifyCfg or function(...) return nil end
    local IsMailEditorOpen = env.IsMailEditorOpen or function(...) return false end
    local ToggleConfigUI = env.ToggleConfigUI or function(...) end

    EnsureDB()
    local mnc = MailNotifyCfg()
    if not mnc then return end
    mnc.ui = mnc.ui or {}
    local w = ClampValue(mnc.ui.w or 200, 40, 600)
    local h = ClampValue(mnc.ui.h or 220, 40, 600)
    local a = ClampValue(mnc.ui.alpha or 0.5, 0.10, 1.00)
    mnc.ui.w, mnc.ui.h, mnc.ui.alpha = w, h, a

    local frame = CreateFrame("Frame", "fr0z3nUI_LootIt_MailNotifier", UIParent)
    frame:SetSize(w, h)
    frame:SetFrameStrata(mnc.ui.strata or "BACKGROUND")
    if frame.SetAlpha then frame:SetAlpha(1) end
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)

    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
      if not IsMailEditorOpen() then return end
      self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      EnsureDB()
      local mnc2 = MailNotifyCfg()
      if not mnc2 then return end
      mnc2.ui = mnc2.ui or {}
      local point, _, _, x, y = self:GetPoint(1)
      mnc2.ui.point = point or "TOPRIGHT"
      mnc2.ui.x = x or 0
      mnc2.ui.y = y or 0

      local mail = LI and LI.Mail
      if mail and type(mail._refreshEditorViewControls) == "function" then
        mail._refreshEditorViewControls()
      end
    end)

    local model = CreateFrame("DressUpModel", nil, frame)
    model:SetAllPoints(frame)
    if model.EnableMouse then model:EnableMouse(false) end
    Mail.ApplyMailModelToFrame(model)
    if model.SetAlpha then
      model:SetAlpha(a)
    end
    frame.model = model

    frame:SetScript("OnMouseUp", function(_, button)
      if not (IsShiftKeyDown and IsShiftKeyDown()) then return end
      if button == "LeftButton" then
        TryUseKatyStampwhistle()
      elseif button == "RightButton" then
        ToggleConfigUI()
      end
    end)

    frame:HookScript("OnShow", function(self)
      EnsureDB()
      local mnc3 = MailNotifyCfg()
      if not mnc3 then return end
      if (mnc3.showInCombat == false) and InCombatLockdown and InCombatLockdown() then
        self:Hide()
      end
    end)

    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(self, delta)
      if not self.model then return end
      EnsureDB()
      local mnc4 = MailNotifyCfg()
      if not mnc4 then return end
      mnc4.model = mnc4.model or {}

      if IsShiftKeyDown and IsShiftKeyDown() then
        local r = tonumber(mnc4.model.rotation) or Mail.ModelGetRotation(self.model) or 0
        r = r + (delta * 0.20)
        mnc4.model.rotation = r
        Mail.ModelSetRotation(self.model, r)
      else
        local z = tonumber(mnc4.model.zoom)
        if not z then z = 1.0 end
        z = ClampValue(z + (delta * 0.08), 0.20, 3.00)
        mnc4.model.zoom = z
        Mail.ModelApplyZoom(self.model, z)
      end
    end)

    frame._lastShiftDown = nil
    frame._repeatElapsed = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
      local s = (IsShiftKeyDown and IsShiftKeyDown()) and true or false
      if self._lastShiftDown ~= s then
        self._lastShiftDown = s
        Mail.ApplyMailNotifierInteractivity()
      end

      if IsMailEditorOpen() then return end

      EnsureDB()
      local mnc5 = MailNotifyCfg()
      if not (mnc5 and mnc5.model) then return end
      local spec = mnc5.model
      if not spec.animRepeat then return end

      local interval = tonumber(spec.animRepeatSec) or 10
      if interval < 0.5 then interval = 0.5 end
      if interval > 3600 then interval = 3600 end

      self._repeatElapsed = (self._repeatElapsed or 0) + (elapsed or 0)
      if self._repeatElapsed < interval then return end
      self._repeatElapsed = 0

      local anim = tonumber(spec.anim) or 0
      if self.model then
        Mail.ModelApplyAnimation(self.model, anim)
      end
    end)

    Mail.ApplyMailNotifierInteractivity()

    frame:Hide()
    MailNotifier = frame
    return frame
  end

  function Mail.UpdateMailNotifier()
    local env = GetEnv()
    local EnsureDB = env.EnsureDB or function(...) end
    local MailNotifyCfg = env.MailNotifyCfg or function(...) return nil end
    local IsMailNotifierEnabled = env.IsMailNotifierEnabled or function(...) return false end

    EnsureDB()

    -- If the mailbox UI is open, keep the notifier hidden.
    if Mail.IsMailboxOpen() then
      if MailNotifier then MailNotifier:Hide() end
      return
    end
    if not IsMailNotifierEnabled() then
      if MailNotifier then MailNotifier:Hide() end
      return
    end

    local frame = Mail.CreateMailNotifier()
    local mn = MailNotifyCfg()
    if not (frame and mn) then
      if MailNotifier then MailNotifier:Hide() end
      return
    end
    if mn and mn.ui then
      frame:ClearAllPoints()
      frame:SetPoint(mn.ui.point or "TOPRIGHT", UIParent, mn.ui.point or "TOPRIGHT", mn.ui.x or 0, mn.ui.y or 0)
      local w = ClampValue(mn.ui.w or frame:GetWidth() or 200, 40, 600)
      local h = ClampValue(mn.ui.h or frame:GetHeight() or 220, 40, 600)
      local currentAlpha = (frame.model and frame.model.GetAlpha and frame.model:GetAlpha()) or 1
      local a = ClampValue(mn.ui.alpha or currentAlpha, 0.10, 1.00)
      mn.ui.w, mn.ui.h, mn.ui.alpha = w, h, a
      frame:SetSize(w, h)
      if frame.model and frame.model.SetAlpha then
        frame.model:SetAlpha(a)
      end
      frame:SetFrameStrata(mn.ui.strata or frame:GetFrameStrata() or "BACKGROUND")
    end

    Mail.ApplyMailNotifierInteractivity()

    if (mn and mn.showInCombat == false) and InCombatLockdown and InCombatLockdown() then
      frame:Hide()
      return
    end

    local has = false
    if HasNewMail then
      has = HasNewMail() and true or false
    end

    if has then
      frame._hadMail = (frame._hadMail == true)
      if not frame._hadMail then
        frame._hadMail = true
        if mn and mn.model and mn.model.animRandom then
          mn.model.anim = math.random(0, 150)
        end
      end

      Mail.ApplyMailModelToFrame(frame.model)
      frame:Show()
    else
      frame._hadMail = false
      frame:Hide()
    end
  end
end

function LI.Mail.BuildTab(mailPanel, mailUI, env)
  env = env or {}
  mailUI = mailUI or {}

  local EnsureDB = env.EnsureDB or function(...) end
  local MailNotifyCfg = env.MailNotifyCfg or function(...) return nil end
  local GetMailNotifyScope = env.GetMailNotifyScope or function(...) return "acc" end
  local SetMailNotifyScope = env.SetMailNotifyScope or function(...) end
  local GetMailNotifyMode = env.GetMailNotifyMode or function(...) return "off" end
  local SetMailNotifyMode = env.SetMailNotifyMode or function(...) end
  local RefreshMailNotifyModeButton = env.RefreshMailNotifyModeButton or function(...) end
  local RefreshMailCombatButton = env.RefreshMailCombatButton or function(...) end
  local UpdateMailNotifier = env.UpdateMailNotifier or LI.Mail.UpdateMailNotifier or function(...) end
  local CreateMailNotifier = env.CreateMailNotifier or LI.Mail.CreateMailNotifier or function(...) return nil end
  local ApplyMailModelToFrame = env.ApplyMailModelToFrame or LI.Mail.ApplyMailModelToFrame or function(...) end
  local ModelApplyAnimation = env.ModelApplyAnimation or LI.Mail.ModelApplyAnimation or function(...) end
  local ModelGetRotation = env.ModelGetRotation or LI.Mail.ModelGetRotation or function(...) return 0 end
  local ModelSetRotation = env.ModelSetRotation or LI.Mail.ModelSetRotation or function(...) end
  local ModelApplyZoom = env.ModelApplyZoom or LI.Mail.ModelApplyZoom or function(...) end
  local GetMailNotifier = env.GetMailNotifier or LI.Mail.GetMailNotifier or function(...) return nil end

  local _ClampFn = (type(rawget(env, "Clamp")) == "function") and rawget(env, "Clamp") or (_G and rawget(_G, "Clamp"))
  local function ClampValue(v, mn, mx)
    if type(_ClampFn) == "function" then
      local ok, res = pcall(_ClampFn, v, mn, mx)
      if ok then
        return res
      end
    end

    v = tonumber(v)
    mn = tonumber(mn)
    mx = tonumber(mx)
    if not v then return mn end
    if mn and v < mn then return mn end
    if mx and v > mx then return mx end
    return v
  end

  local reloadBtn = env.reloadBtn

  local Print = env.Print or LI.Print or function(...) end
  local SetCheckBoxText = env.SetCheckBoxText or LI.SetCheckBoxText or function(...) end
  local SetCheckBoxChecked = env.SetCheckBoxChecked or LI.SetCheckBoxChecked or function(...) end

  mailUI.notifyLabel = mailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  mailUI.notifyLabel:SetPoint("TOPLEFT", mailPanel, "TOPLEFT", 10, -10)
  mailUI.notifyLabel:SetText("")
  if mailUI.notifyLabel.Hide then mailUI.notifyLabel:Hide() end

  mailUI.notifyModeBtn = CreateFrame("Button", nil, mailPanel, "UIPanelButtonTemplate")
  mailUI.notifyModeBtn:SetSize(90, 20)
  mailUI.notifyModeBtn:SetPoint("TOPLEFT", mailPanel, "TOPLEFT", 10, 12)
  mailUI.notifyModeBtn:SetScript("OnClick", function()
    local cur = GetMailNotifyMode()
    local nextMode = (cur == "off") and "on" or ((cur == "on") and "acc" or "off")
    SetMailNotifyMode(nextMode)
    RefreshMailNotifyModeButton()
  end)
  RefreshMailNotifyModeButton()

  local function RefreshMailScopeButton()
    local btn = mailUI and mailUI.mailScopeBtn
    if not (btn and btn.SetText) then return end
    local s = tostring(GetMailNotifyScope() or "acc"):lower()
    btn:SetText((s == "char") and "Character" or "Account")
  end

  mailUI.mailScopeBtn = CreateFrame("Button", nil, mailPanel, "UIPanelButtonTemplate")
  mailUI.mailScopeBtn:SetSize(100, 20)
  mailUI.mailScopeBtn:SetPoint("LEFT", mailUI.notifyModeBtn, "RIGHT", 10, 0)
  mailUI.mailScopeBtn:SetScript("OnClick", function()
    local cur = tostring(GetMailNotifyScope() or "acc"):lower()
    local nextScope = (cur == "char") and "acc" or "char"
    SetMailNotifyScope(nextScope)
    RefreshMailScopeButton()
    RefreshMailCombatButton()
    if mailPanel and mailPanel.modelUI and mailPanel.modelUI.Refresh then
      mailPanel.modelUI:Refresh()
    end
  end)
  RefreshMailScopeButton()

  -- Embedded mail model editor (replaces the old pop-out window).
  local modelUI = CreateFrame("Frame", nil, mailPanel)
  modelUI:SetPoint("TOPLEFT", mailUI.notifyModeBtn, "BOTTOMLEFT", -2, -2)
  modelUI:SetPoint("BOTTOMRIGHT", mailPanel, "BOTTOMRIGHT", -12, 34)
  mailPanel.modelUI = modelUI

  local preview = CreateFrame("DressUpModel", nil, modelUI)
  preview:SetPoint("TOPLEFT", modelUI, "TOPLEFT", 2, 0)
  preview:SetSize(189, 231)
  modelUI.preview = preview

  local rightCol = CreateFrame("Frame", nil, modelUI)
  rightCol:SetPoint("TOPLEFT", preview, "TOPRIGHT", 18, 24)
  rightCol:SetPoint("BOTTOMRIGHT", modelUI, "BOTTOMRIGHT", -12, 6)

  local rightBottomRow = CreateFrame("Frame", nil, modelUI)
  rightBottomRow:SetPoint("BOTTOMLEFT", rightCol, "BOTTOMLEFT", 0, 0)
  rightBottomRow:SetPoint("BOTTOMRIGHT", rightCol, "BOTTOMRIGHT", 0, 0)
  rightBottomRow:SetHeight(24)

  local zoomLabel = modelUI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  zoomLabel:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -10)
  zoomLabel:SetText("Zoom")

  local zoomSlider = CreateFrame("Slider", "fr0z3nUI_LootIt_MailModelPickerZoom", modelUI, "OptionsSliderTemplate")
  zoomSlider:SetPoint("LEFT", zoomLabel, "RIGHT", 18, 0)
  zoomSlider:SetWidth(150)
  zoomSlider:SetMinMaxValues(0.20, 3.00)
  zoomSlider:SetValueStep(0.05)
  if zoomSlider.SetObeyStepOnDrag then zoomSlider:SetObeyStepOnDrag(true) end
  _G[zoomSlider:GetName() .. "Low"]:SetText("0.2")
  _G[zoomSlider:GetName() .. "High"]:SetText("3.0")
  _G[zoomSlider:GetName() .. "Text"]:SetText(" ")

  local alphaLabel = modelUI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  alphaLabel:SetPoint("TOPLEFT", zoomLabel, "BOTTOMLEFT", 0, -14)
  alphaLabel:SetText("Alpha")

  local alphaSlider = CreateFrame("Slider", "fr0z3nUI_LootIt_MailModelPickerAlpha", modelUI, "OptionsSliderTemplate")
  alphaSlider:SetPoint("LEFT", alphaLabel, "RIGHT", 18, 0)
  alphaSlider:SetWidth(150)
  alphaSlider:SetMinMaxValues(0.10, 1.00)
  alphaSlider:SetValueStep(0.05)
  if alphaSlider.SetObeyStepOnDrag then alphaSlider:SetObeyStepOnDrag(true) end
  _G[alphaSlider:GetName() .. "Low"]:SetText("0.1")
  _G[alphaSlider:GetName() .. "High"]:SetText("1.0")
  _G[alphaSlider:GetName() .. "Text"]:SetText(" ")

  local RefreshViewControls

  modelUI._repeatElapsed = 0
  modelUI:SetScript("OnUpdate", function(self, elapsed)
    EnsureDB()
    local mnc = MailNotifyCfg()
    if not (mnc and mnc.model) then return end
    local spec = mnc.model
    if not spec.animRepeat then return end

    local interval = tonumber(spec.animRepeatSec) or 10
    if interval < 0.5 then interval = 0.5 end
    if interval > 3600 then interval = 3600 end

    self._repeatElapsed = (self._repeatElapsed or 0) + (elapsed or 0)
    if self._repeatElapsed < interval then return end
    self._repeatElapsed = 0

    local anim = tonumber(spec.anim) or 0
    if preview then
      ModelApplyAnimation(preview, anim)
    end
    local mn = GetMailNotifier()
    if mn and mn.model then
      ModelApplyAnimation(mn.model, anim)
    end
  end)

  preview:EnableMouseWheel(true)
  preview:SetScript("OnMouseWheel", function(self, delta)
    EnsureDB()
    local mnc = MailNotifyCfg()
    if not mnc then return end
    mnc.model = mnc.model or {}

    if IsShiftKeyDown and IsShiftKeyDown() then
      local r = tonumber(mnc.model.rotation) or ModelGetRotation(self) or 0
      r = r + (delta * 0.20)
      mnc.model.rotation = r
      ModelSetRotation(self, r)
    else
      local z = tonumber(mnc.model.zoom)
      if not z then z = 1.0 end
      z = ClampValue(z + (delta * 0.08), 0.20, 3.00)
      mnc.model.zoom = z
      ModelApplyZoom(self, z)
    end
  end)

  local function NewPresetButton(text, npcID)
    local b = CreateFrame("Button", nil, modelUI, "UIPanelButtonTemplate")
    b:SetSize(110, 18)
    b:SetText(text)
    b:SetScript("OnClick", function()
      EnsureDB()
      local mnc = MailNotifyCfg()
      if not mnc then return end
      mnc.model = mnc.model or {}
      mnc.model.kind = "npc"
      mnc.model.id = npcID
      modelUI.rPlayer:SetChecked(false)
      modelUI.rNPC:SetChecked(true)
      modelUI.rDisplay:SetChecked(false)
      modelUI.rFile:SetChecked(false)
      modelUI.idBox:SetEnabled(true)
      modelUI.idBox:SetText(tostring(npcID))
      ApplyMailModelToFrame(preview)
      UpdateMailNotifier()
    end)
    return b
  end

  local kindLabel = modelUI:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  kindLabel:SetPoint("TOPLEFT", rightCol, "TOPLEFT", 0, 0)
  kindLabel:SetWidth(70)
  kindLabel:SetJustifyH("LEFT")
  kindLabel:SetText("Type")

  local function NewRadio(text)
    local r = CreateFrame("CheckButton", nil, modelUI, "UIRadioButtonTemplate")
    SetCheckBoxText(r, text)
    return r
  end

  local rPlayer = NewRadio("Player")
  rPlayer:SetPoint("TOPLEFT", kindLabel, "BOTTOMLEFT", -2, -8)
  local rNPC = NewRadio("NPCID")
  rNPC:SetPoint("TOPLEFT", rPlayer, "BOTTOMLEFT", 0, -8)
  local rDisplay = NewRadio("DisplayID")
  rDisplay:SetPoint("TOPLEFT", rNPC, "BOTTOMLEFT", 0, -8)
  local rFile = NewRadio("FileID")
  rFile:SetPoint("TOPLEFT", rDisplay, "BOTTOMLEFT", 0, -8)
  modelUI.rPlayer, modelUI.rNPC, modelUI.rDisplay, modelUI.rFile = rPlayer, rNPC, rDisplay, rFile

  local idLabel = modelUI:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  idLabel:SetPoint("LEFT", kindLabel, "RIGHT", 14, 0)
  idLabel:SetWidth(28)
  idLabel:SetJustifyH("LEFT")
  idLabel:SetText("ID")

  local idBox = CreateFrame("EditBox", nil, modelUI, "InputBoxTemplate")
  idBox:SetSize(110, 20)
  idBox:SetPoint("LEFT", idLabel, "RIGHT", 8, 0)
  idBox:SetAutoFocus(false)
  idBox:SetJustifyH("CENTER")
  modelUI.idBox = idBox

  local presetKaty = NewPresetButton("Katy", 132969)
  presetKaty:SetPoint("TOPLEFT", idBox, "BOTTOMLEFT", 0, -8)
  local presetDalaran = NewPresetButton("Dalaran", 104230)
  presetDalaran:SetPoint("TOPLEFT", presetKaty, "BOTTOMLEFT", 0, -6)
  local presetPlagued = NewPresetButton("Plagued", 155971)
  presetPlagued:SetPoint("TOPLEFT", presetDalaran, "BOTTOMLEFT", 0, -6)

  local function GetKind()
    if rNPC:GetChecked() then return "npc" end
    if rDisplay:GetChecked() then return "display" end
    if rFile:GetChecked() then return "file" end
    return "player"
  end

  local function SetKind(kind)
    kind = tostring(kind or "player"):lower()
    rPlayer:SetChecked(kind == "player")
    rNPC:SetChecked(kind == "npc" or kind == "creature")
    rDisplay:SetChecked(kind == "display")
    rFile:SetChecked(kind == "file")
    idBox:SetEnabled(kind ~= "player")
    if kind == "player" then
      idBox:SetText("")
    end
  end

  local function PreviewSpec()
    EnsureDB()
    local mnc = MailNotifyCfg()
    if not mnc then return end
    local spec = mnc.model or {}
    local kind = GetKind()
    local id = tonumber(idBox:GetText() or "")
    spec.kind = kind
    spec.id = (kind == "player") and nil or id
    mnc.model = spec
    ApplyMailModelToFrame(preview)
  end

  local function ApplyNotifierSizingAndAlpha()
    EnsureDB()
    local mnc = MailNotifyCfg()
    if not mnc then return end
    mnc.ui = mnc.ui or {}

    local w = ClampValue(mnc.ui.w or 200, 40, 600)
    local h = ClampValue(mnc.ui.h or 220, 40, 600)
    local a = ClampValue(mnc.ui.alpha or 0.5, 0.10, 1.00)
    mnc.ui.w, mnc.ui.h, mnc.ui.alpha = w, h, a

    local mn = GetMailNotifier() or CreateMailNotifier()
    if mn then
      mn:SetSize(w, h)
      if mn.model and mn.model.SetAlpha then
        mn.model:SetAlpha(a)
      end
      if mnc.ui and mnc.ui.strata and mn.SetFrameStrata then
        mn:SetFrameStrata(mnc.ui.strata)
      end
    end
  end

  local function OnRadioClick(self)
    rPlayer:SetChecked(self == rPlayer)
    rNPC:SetChecked(self == rNPC)
    rDisplay:SetChecked(self == rDisplay)
    rFile:SetChecked(self == rFile)
    SetKind(GetKind())
    PreviewSpec()
  end

  rPlayer:SetScript("OnClick", OnRadioClick)
  rNPC:SetScript("OnClick", OnRadioClick)
  rDisplay:SetScript("OnClick", OnRadioClick)
  rFile:SetScript("OnClick", OnRadioClick)
  idBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    PreviewSpec()
  end)

  local apply = CreateFrame("Button", nil, modelUI, "UIPanelButtonTemplate")
  apply:SetSize(90, 22)
  apply:SetPoint("TOPLEFT", zoomLabel, "BOTTOMLEFT", 0, -10)
  apply:SetText("Apply")
  apply:SetScript("OnClick", function()
    PreviewSpec()
    UpdateMailNotifier()
  end)

  local reset = CreateFrame("Button", nil, modelUI, "UIPanelButtonTemplate")
  reset:SetSize(60, 22)
  reset:SetPoint("LEFT", apply, "RIGHT", 10, 0)
  reset:SetText("Reset")
  reset:SetScript("OnClick", function()
    EnsureDB()
    local mn = MailNotifyCfg()
    if not mn then return end

    -- Model defaults
    mn.model = mn.model or {}
    mn.model.kind = "npc"
    mn.model.id = 104230
    mn.model.anim = 0
    mn.model.rotation = 0.15
    mn.model.zoom = 0.9

    -- View defaults
    mn.ui = mn.ui or {}
    mn.ui.w = 200
    mn.ui.h = 220
    mn.ui.alpha = 0.5
    mn.ui.strata = "BACKGROUND"

    mn.showInCombat = true

    SetKind("npc")
    if idBox and idBox.SetText then
      idBox:SetText("104230")
    end
    ApplyMailModelToFrame(preview)
    ApplyNotifierSizingAndAlpha()
    UpdateMailNotifier()
    if RefreshViewControls then RefreshViewControls() end
  end)

  mailUI.combatBtn = CreateFrame("Button", nil, modelUI, "UIPanelButtonTemplate")
  mailUI.combatBtn:SetSize(90, 22)
  mailUI.combatBtn:SetPoint("LEFT", reset, "RIGHT", 10, 0)
  mailUI.combatBtn:SetScript("OnClick", function()
    EnsureDB()
    local mn = MailNotifyCfg()
    if not mn then return end
    local on = (mn.showInCombat ~= false)
    mn.showInCombat = on and false or true
    UpdateMailNotifier()
    RefreshMailCombatButton()
  end)
  RefreshMailCombatButton()

  -- Mail notifier mode + combat buttons are anchored at the top of the tab.

  local viewContent

  local function BuildMailNotifierViewControls()
    viewContent = CreateFrame("Frame", nil, modelUI)
    viewContent:SetPoint("TOPLEFT", rFile, "BOTTOMLEFT", -2, -6)
    -- Leave a dedicated bottom row on the right for Combat+Apply.
    viewContent:SetPoint("BOTTOMRIGHT", rightBottomRow, "TOPRIGHT", 0, 0)

    local xyLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xyLabel:SetPoint("TOPLEFT", viewContent, "TOPLEFT", 6, -6)
    xyLabel:SetWidth(90)
    xyLabel:SetJustifyH("LEFT")
    xyLabel:SetText("Notifier X/Y")

    local xBox = CreateFrame("EditBox", nil, viewContent, "InputBoxTemplate")
    xBox:SetSize(46, 20)
    xBox:SetPoint("LEFT", xyLabel, "RIGHT", 10, 0)
    xBox:SetAutoFocus(false)
    xBox:SetJustifyH("CENTER")

    local yBox = CreateFrame("EditBox", nil, viewContent, "InputBoxTemplate")
    yBox:SetSize(46, 20)
    yBox:SetPoint("LEFT", xBox, "RIGHT", 10, 0)
    yBox:SetAutoFocus(false)
    yBox:SetJustifyH("CENTER")

    local wLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    wLabel:SetPoint("TOPLEFT", xyLabel, "BOTTOMLEFT", 0, -16)
    wLabel:SetWidth(90)
    wLabel:SetJustifyH("LEFT")
    wLabel:SetText("Notifier W/H")

    local wBox = CreateFrame("EditBox", nil, viewContent, "InputBoxTemplate")
    wBox:SetSize(46, 20)
    wBox:SetPoint("LEFT", wLabel, "RIGHT", 10, 0)
    wBox:SetAutoFocus(false)
    wBox:SetJustifyH("CENTER")

    local hBox = CreateFrame("EditBox", nil, viewContent, "InputBoxTemplate")
    hBox:SetSize(46, 20)
    hBox:SetPoint("LEFT", wBox, "RIGHT", 10, 0)
    hBox:SetAutoFocus(false)
    hBox:SetJustifyH("CENTER")

    local _inRefresh = false
    local function RefreshXYWHBoxesFromConfig()
      EnsureDB()
      local mnc = MailNotifyCfg()
      if not mnc then return end
      mnc.ui = mnc.ui or {}

      _inRefresh = true
      do
        local x = tonumber(mnc.ui.x) or 0
        local y = tonumber(mnc.ui.y) or 0
        xBox:SetText(tostring(math.floor(x + 0.5)))
        yBox:SetText(tostring(math.floor(y + 0.5)))
      end
      do
        local w = ClampValue(mnc.ui.w or 200, 40, 600)
        local h = ClampValue(mnc.ui.h or 220, 40, 600)
        wBox:SetText(tostring(math.floor(w + 0.5)))
        hBox:SetText(tostring(math.floor(h + 0.5)))
      end
      _inRefresh = false
    end

    local function ApplyXYWHFromBoxes()
      if _inRefresh then return end
      EnsureDB()
      local mnc = MailNotifyCfg()
      if not mnc then return end
      mnc.ui = mnc.ui or {}

      local x = tonumber(xBox:GetText() or "")
      local y = tonumber(yBox:GetText() or "")
      if x ~= nil then mnc.ui.x = x end
      if y ~= nil then mnc.ui.y = y end

      local w = tonumber(wBox:GetText() or "")
      local h = tonumber(hBox:GetText() or "")
      if w ~= nil then mnc.ui.w = w end
      if h ~= nil then mnc.ui.h = h end

      ApplyNotifierSizingAndAlpha()
      UpdateMailNotifier()
      if RefreshViewControls then RefreshViewControls() end
    end

    local function DebounceApply(editBox)
      if not editBox then return end
      if editBox._fliDebounce and editBox._fliDebounce.Cancel then
        editBox._fliDebounce:Cancel()
      end
      local ct = rawget(_G, "C_Timer")
      if ct and type(ct.NewTimer) == "function" then
        editBox._fliDebounce = ct.NewTimer(0.60, function()
          ApplyXYWHFromBoxes()
        end)
      end
    end

    local strataLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    strataLabel:SetPoint("TOPLEFT", wLabel, "BOTTOMLEFT", 0, -18)
    strataLabel:SetWidth(90)
    strataLabel:SetJustifyH("LEFT")
    strataLabel:SetText("Layer")

    local strataDD = CreateFrame("Frame", "fr0z3nUI_LootIt_MailModelPickerStrata", viewContent, "UIDropDownMenuTemplate")
    strataDD:SetPoint("LEFT", strataLabel, "RIGHT", -28, -2)
    UIDropDownMenu_SetWidth(strataDD, 130)

    local STRATA = {
      { key = "BACKGROUND", text = "Background" },
      { key = "LOW", text = "Low" },
      { key = "MEDIUM", text = "Medium" },
      { key = "HIGH", text = "High" },
      { key = "DIALOG", text = "Dialog" },
      { key = "FULLSCREEN", text = "Fullscreen" },
      { key = "FULLSCREEN_DIALOG", text = "Fullscreen Dialog" },
      { key = "TOOLTIP", text = "Tooltip" },
    }

    local function SetStrataDropdownText(strataKey)
      local want = tostring(strataKey or "BACKGROUND")
      local text = want
      for _, s in ipairs(STRATA) do
        if s.key == want then
          text = s.text
          break
        end
      end

      if UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(strataDD, text)
      else
        local fs = _G and strataDD and strataDD.GetName and _G[strataDD:GetName() .. "Text"]
        if fs and fs.SetText then
          fs:SetText(text)
        end
      end
    end

    do
      local mu = _G and rawget(_G, "MenuUtil")
      if type(mu) == "table" and type(mu.CreateContextMenu) == "function" then
        local anchor = strataDD.Button or strataDD
        if anchor and anchor.SetScript then
          anchor:SetScript("OnClick", function(btn)
            mu.CreateContextMenu(btn, function(_, root)
              if root and root.CreateTitle then root:CreateTitle("Layer") end
              EnsureDB()
              local mnc = MailNotifyCfg()
              if not mnc then return end
              mnc.ui = mnc.ui or {}
              local selected = tostring(mnc.ui.strata or "")
              for i, s in ipairs(STRATA) do
                if root and root.CreateRadio then
                  root:CreateRadio(s.text, function() return selected == s.key end, function()
                    EnsureDB()
                    local mnc2 = MailNotifyCfg()
                    if not mnc2 then return end
                    mnc2.ui = mnc2.ui or {}
                    mnc2.ui.strata = s.key
                    SetStrataDropdownText(s.key)
                    ApplyNotifierSizingAndAlpha()
                    UpdateMailNotifier()
                  end)
                elseif root and root.CreateButton then
                  root:CreateButton(s.text, function()
                    EnsureDB()
                    local mnc2 = MailNotifyCfg()
                    if not mnc2 then return end
                    mnc2.ui = mnc2.ui or {}
                    mnc2.ui.strata = s.key
                    SetStrataDropdownText(s.key)
                    ApplyNotifierSizingAndAlpha()
                    UpdateMailNotifier()
                  end)
                end
              end
            end)
          end)
        end
      else
        UIDropDownMenu_Initialize(strataDD, function(_, level)
          if level ~= 1 then return end
          for i, s in ipairs(STRATA) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = s.text
            info.func = function()
              EnsureDB()
              local mnc = MailNotifyCfg()
              if not mnc then return end
              mnc.ui = mnc.ui or {}
              mnc.ui.strata = s.key
              UIDropDownMenu_SetSelectedID(strataDD, i)
              ApplyNotifierSizingAndAlpha()
              UpdateMailNotifier()
            end
            UIDropDownMenu_AddButton(info, level)
          end
        end)
      end
    end

    local rotLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rotLabel:SetPoint("TOPLEFT", strataLabel, "BOTTOMLEFT", 0, -20)
    rotLabel:SetWidth(90)
    rotLabel:SetJustifyH("LEFT")
    rotLabel:SetText("Rotate")

    local rotLeft = CreateFrame("Button", nil, viewContent, "UIPanelButtonTemplate")
    rotLeft:SetSize(30, 20)
    rotLeft:SetPoint("LEFT", rotLabel, "RIGHT", -28, 0)
    rotLeft:SetText("<")

    local rotReset = CreateFrame("Button", nil, viewContent, "UIPanelButtonTemplate")
    rotReset:SetSize(46, 20)
    rotReset:SetPoint("LEFT", rotLeft, "RIGHT", 8, 0)
    rotReset:SetText("Reset")

    local rotRight = CreateFrame("Button", nil, viewContent, "UIPanelButtonTemplate")
    rotRight:SetSize(30, 20)
    rotRight:SetPoint("LEFT", rotReset, "RIGHT", 8, 0)
    rotRight:SetText(">")

    local actionLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    actionLabel:SetPoint("TOPLEFT", rotLabel, "BOTTOMLEFT", 0, -16)
    actionLabel:SetWidth(90)
    actionLabel:SetJustifyH("LEFT")
    actionLabel:SetText("Action")

    local actionPrev = CreateFrame("Button", nil, viewContent, "UIPanelButtonTemplate")
    actionPrev:SetSize(30, 20)
    actionPrev:SetPoint("LEFT", actionLabel, "RIGHT", -28, 0)
    actionPrev:SetText("<")

    local actionBox = CreateFrame("EditBox", nil, viewContent, "InputBoxTemplate")
    actionBox:SetSize(46, 20)
    actionBox:SetPoint("LEFT", actionPrev, "RIGHT", 8, 0)
    actionBox:SetAutoFocus(false)
    actionBox:SetJustifyH("CENTER")
    actionBox:SetNumeric(true)
    actionBox:SetText("0")

    local actionNext = CreateFrame("Button", nil, viewContent, "UIPanelButtonTemplate")
    actionNext:SetSize(30, 20)
    actionNext:SetPoint("LEFT", actionBox, "RIGHT", 8, 0)
    actionNext:SetText(">")

    local actionRandomBtn = CreateFrame("Button", nil, viewContent, "UIPanelButtonTemplate")
    actionRandomBtn:SetSize(60, 20)
    actionRandomBtn:SetPoint("LEFT", actionNext, "RIGHT", 0, 0)
    actionRandomBtn:SetText("Random")

    local repeatCB = CreateFrame("CheckButton", nil, viewContent, "UICheckButtonTemplate")
    SetCheckBoxText(repeatCB, "")
    if repeatCB.Text then repeatCB.Text:Hide() end
    if repeatCB.text then repeatCB.text:Hide() end
    repeatCB:SetSize(24, 24)

    local repeatSecBox = CreateFrame("EditBox", nil, viewContent, "InputBoxTemplate")
    repeatSecBox:SetSize(50, 20)
    repeatSecBox:SetPoint("TOPLEFT", actionBox, "BOTTOMLEFT", 0, -8)
    repeatSecBox:SetAutoFocus(false)
    repeatSecBox:SetJustifyH("CENTER")
    repeatSecBox:SetNumeric(true)
    repeatSecBox:SetText("10")

    repeatCB:SetPoint("RIGHT", repeatSecBox, "LEFT", -6, 0)

    local repeatLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    repeatLabel:SetPoint("TOPLEFT", actionLabel, "BOTTOMLEFT", 0, -16)
    repeatLabel:SetWidth(90)
    repeatLabel:SetJustifyH("LEFT")
    repeatLabel:SetText("Repeat")

    local repeatSecLabel = viewContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    repeatSecLabel:SetPoint("LEFT", repeatSecBox, "RIGHT", 6, 0)
    repeatSecLabel:SetText("sec.")

    local mailTest = CreateFrame("Button", nil, modelUI, "UIPanelButtonTemplate")
    mailTest:SetSize(60, 22)
    mailTest:SetPoint("TOPLEFT", presetPlagued, "BOTTOMLEFT", 0, -8)
    mailTest:SetText("Test")
    mailTest:SetScript("OnClick", function()
      EnsureDB()
      local mf = CreateMailNotifier()
      local mnc = MailNotifyCfg()
      if not (mf and mnc and mnc.ui) then return end
      if mnc.ui then
        mf:ClearAllPoints()
        mf:SetPoint(mnc.ui.point or "TOPRIGHT", UIParent, mnc.ui.point or "TOPRIGHT", mnc.ui.x or 0, mnc.ui.y or 0)
      end
      if (mnc.showInCombat == false) and InCombatLockdown and InCombatLockdown() then
        mf:Hide()
        Print("Mail notifier: hidden in combat.")
        return
      end
      ApplyMailModelToFrame(mf.model)
      mf:Show()
      Print("Mail notifier: shown (test).")
    end)
    modelUI.mailTestBtn = mailTest

    RefreshViewControls = function()
      EnsureDB()
      local mnc = MailNotifyCfg()
      if not mnc then return end
      mnc.ui = mnc.ui or {}
      mnc.model = mnc.model or {}

      RefreshXYWHBoxesFromConfig()

      local w = ClampValue(mnc.ui.w or 200, 40, 600)
      local h = ClampValue(mnc.ui.h or 220, 40, 600)
      local a = ClampValue(mnc.ui.alpha or 0.5, 0.10, 1.00)
      wBox:SetText(tostring(math.floor(w + 0.5)))
      hBox:SetText(tostring(math.floor(h + 0.5)))
      alphaSlider:SetValue(a)

      local want = tostring(mnc.ui.strata or "BACKGROUND")
      local selected = 1
      for i, s in ipairs(STRATA) do
        if s.key == want then
          selected = i
          break
        end
      end
      SetStrataDropdownText(want)

      local z = ClampValue(mnc.model.zoom or 0.9, 0.20, 3.00)
      zoomSlider:SetValue(z)

      local anim = tonumber(mnc.model.anim) or 0
      actionBox:SetText(tostring(anim))
      local randomOn = (mnc.model.animRandom == true)
      do
        local fs = actionRandomBtn and actionRandomBtn.GetFontString and actionRandomBtn:GetFontString() or nil
        if fs and fs.SetTextColor then
          if randomOn then
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
            fs:SetTextColor(0.55, 0.55, 0.55, 1)
          end
        end
      end

      local repeatOn = (mnc.model.animRepeat == true)
      local sec = tonumber(mnc.model.animRepeatSec) or 10
      if sec < 1 then sec = 1 end
      if sec > 3600 then sec = 3600 end
      repeatSecBox:SetText(tostring(math.floor(sec + 0.5)))
      SetCheckBoxChecked(repeatCB, repeatOn)
      repeatSecBox:SetEnabled(repeatOn)

      local allowManual = (not randomOn)
      actionBox:SetEnabled(allowManual)
      actionPrev:SetEnabled(allowManual)
      actionNext:SetEnabled(allowManual)
    end

    do
      local mail = LI and LI.Mail
      if mail then
        mail._refreshEditorViewControls = RefreshViewControls
      end
    end

    xBox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      ApplyXYWHFromBoxes()
    end)
    yBox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      ApplyXYWHFromBoxes()
    end)
    wBox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      ApplyXYWHFromBoxes()
    end)
    hBox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      ApplyXYWHFromBoxes()
    end)

    xBox:SetScript("OnEditFocusLost", function() ApplyXYWHFromBoxes() end)
    yBox:SetScript("OnEditFocusLost", function() ApplyXYWHFromBoxes() end)
    wBox:SetScript("OnEditFocusLost", function() ApplyXYWHFromBoxes() end)
    hBox:SetScript("OnEditFocusLost", function() ApplyXYWHFromBoxes() end)

    xBox:SetScript("OnTextChanged", function(self, userInput)
      if _inRefresh or (userInput ~= true) then return end
      DebounceApply(self)
    end)
    yBox:SetScript("OnTextChanged", function(self, userInput)
      if _inRefresh or (userInput ~= true) then return end
      DebounceApply(self)
    end)
    wBox:SetScript("OnTextChanged", function(self, userInput)
      if _inRefresh or (userInput ~= true) then return end
      DebounceApply(self)
    end)
    hBox:SetScript("OnTextChanged", function(self, userInput)
      if _inRefresh or (userInput ~= true) then return end
      DebounceApply(self)
    end)

    alphaSlider:SetScript("OnValueChanged", function(_, v)
      EnsureDB()
      local mnc = MailNotifyCfg()
      if not mnc then return end
      mnc.ui = mnc.ui or {}
      mnc.ui.alpha = ClampValue(v, 0.10, 1.00)
      ApplyNotifierSizingAndAlpha()
      if preview and preview.SetAlpha then
        preview:SetAlpha(mnc.ui.alpha)
      end
      UpdateMailNotifier()
    end)

    zoomSlider:SetScript("OnValueChanged", function(_, v)
      EnsureDB()
      local mnc = MailNotifyCfg()
      if not mnc then return end
      mnc.model = mnc.model or {}
      mnc.model.zoom = ClampValue(v, 0.20, 3.00)
      ApplyMailModelToFrame(preview)
      UpdateMailNotifier()
    end)

    local function NudgeRotation(dir)
      EnsureDB()
      local mnc = MailNotifyCfg()
      if not mnc then return end
      mnc.model = mnc.model or {}
      local r = tonumber(mnc.model.rotation) or ModelGetRotation(preview) or 0
      r = r + (dir * 0.20)
      mnc.model.rotation = r
      ModelSetRotation(preview, r)
      UpdateMailNotifier()
    end

    rotLeft:SetScript("OnClick", function() NudgeRotation(-1) end)
    rotRight:SetScript("OnClick", function() NudgeRotation(1) end)
    rotReset:SetScript("OnClick", function()
      EnsureDB()
      local mnc = MailNotifyCfg()
      if not mnc then return end
      mnc.model = mnc.model or {}
      mnc.model.rotation = 0
      ModelSetRotation(preview, 0)
      UpdateMailNotifier()
    end)

    local function SetAction(anim)
      EnsureDB()
      local mnc = MailNotifyCfg()
      if not mnc then return end
      mnc.model = mnc.model or {}
      anim = tonumber(anim) or 0
      if anim < 0 then anim = 0 end
      if anim > 150 then anim = 0 end
      mnc.model.animRandom = false
      mnc.model.anim = anim
      actionBox:SetText(tostring(anim))
      actionBox:SetEnabled(true)
      actionPrev:SetEnabled(true)
      actionNext:SetEnabled(true)
      ModelApplyAnimation(preview, anim)
      UpdateMailNotifier()
      if RefreshViewControls then RefreshViewControls() end
    end

    actionPrev:SetScript("OnClick", function()
      EnsureDB()
      local mnc = MailNotifyCfg()
      local anim = tonumber(mnc and mnc.model and mnc.model.anim) or 0
      SetAction(anim - 1)
    end)

    actionNext:SetScript("OnClick", function()
      EnsureDB()
      local mnc = MailNotifyCfg()
      local anim = tonumber(mnc and mnc.model and mnc.model.anim) or 0
      SetAction(anim + 1)
    end)

    actionBox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      SetAction(tonumber(self:GetText()) or 0)
    end)

    actionRandomBtn:SetScript("OnClick", function()
      EnsureDB()
      local mnc = MailNotifyCfg()
      if not mnc then return end
      mnc.model = mnc.model or {}

      local on = not (mnc.model.animRandom == true)
      mnc.model.animRandom = on and true or false

      if on then
        mnc.model.anim = math.random(0, 150)
        actionBox:SetEnabled(false)
        actionPrev:SetEnabled(false)
        actionNext:SetEnabled(false)
      else
        actionBox:SetEnabled(true)
        actionPrev:SetEnabled(true)
        actionNext:SetEnabled(true)
      end

      ApplyMailModelToFrame(preview)
      UpdateMailNotifier()
      RefreshViewControls()
    end)

    repeatCB:SetScript("OnClick", function(self)
      EnsureDB()
      local mnc = MailNotifyCfg()
      if not mnc then return end
      mnc.model = mnc.model or {}

      local on = self:GetChecked() and true or false
      mnc.model.animRepeat = on
      if mnc.model.animRepeatSec == nil then
        mnc.model.animRepeatSec = 10
      end

      repeatSecBox:SetEnabled(on)
      RefreshViewControls()
    end)

    repeatSecBox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      EnsureDB()
      local mnc = MailNotifyCfg()
      if not mnc then return end
      mnc.model = mnc.model or {}

      local sec = tonumber(self:GetText() or "") or 10
      if sec < 1 then sec = 1 end
      if sec > 3600 then sec = 3600 end
      mnc.model.animRepeatSec = sec
      RefreshViewControls()
    end)
  end

  BuildMailNotifierViewControls()

  do
    -- Bottom controls layout.
    reset:SetParent(mailPanel)
    reset:ClearAllPoints()
    reset:SetPoint("BOTTOMLEFT", mailPanel, "BOTTOMLEFT", 10, 6)

    local testBtn = modelUI and modelUI.mailTestBtn
    if testBtn then
      testBtn:SetParent(mailPanel)
      testBtn:ClearAllPoints()
      testBtn:SetPoint("LEFT", reset, "RIGHT", 10, 0)
      testBtn:SetSize(reset:GetWidth(), reset:GetHeight())
    end

    mailUI.combatBtn:ClearAllPoints()
    -- Center Combat+Apply in the right-side bottom row.
    mailUI.combatBtn:SetPoint("LEFT", rightBottomRow, "CENTER", -95, 0)

    apply:ClearAllPoints()
    apply:SetPoint("LEFT", mailUI.combatBtn, "RIGHT", 10, 0)
  end

  local hint = modelUI:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetParent(mailPanel)
  hint:ClearAllPoints()
  hint:SetPoint("BOTTOMLEFT", (modelUI and modelUI.mailTestBtn) or reset, "BOTTOMRIGHT", 10, -2)
  if reloadBtn then
    hint:SetPoint("BOTTOMRIGHT", reloadBtn, "BOTTOMLEFT", -10, -2)
  else
    hint:SetPoint("BOTTOMRIGHT", mailPanel, "BOTTOMRIGHT", -10, 6)
  end
  hint:SetJustifyH("CENTER")
  hint:SetText("Shift-click uses Katy's Stampwhistle.")

  modelUI.Refresh = function()
    EnsureDB()
    local mnc = MailNotifyCfg()
    local spec = (mnc and mnc.model) or {}
    SetKind(spec.kind or "player")
    if spec.id then idBox:SetText(tostring(spec.id)) end
    ApplyMailModelToFrame(preview)
    ApplyNotifierSizingAndAlpha()
    if RefreshViewControls then RefreshViewControls() end
  end
end
