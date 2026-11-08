-- Cadence: pick a key for the rotation without touching your saved keybinds.
--
-- WoW no longer lets an action-bar macro /click a button that runs another
-- macro, so a "Cadence" macro on your bar can't cast. Instead, /cad bind lets
-- you press any key (even one your action bar already uses, like 1). Cadence
-- takes that key over with an *override* binding while the addon is loaded.
-- Your normal keybinds are never changed; /cad unbind hands the key back.

local ADDON, ns = ...

local owner = CreateFrame("Frame", "CadenceBindingOwner", UIParent)
local TARGETS = { main = "CadenceMainButton", aoe = "CadenceAoEButton", interrupt = "CadenceInterruptButton" }
local LABELS = { main = "main rotation", aoe = "AoE rotation", interrupt = "interrupt" }

function ns.GetCadenceKey(which)
  local b = CadenceCharDB and CadenceCharDB.binds
  return b and b[which] or nil
end

-- A key set in Esc > Options > Keybindings > AddOns > Cadence, if any.
function ns.GetSettingsKey(which)
  if not GetBindingKey then return nil end
  return GetBindingKey("CLICK " .. TARGETS[which] .. ":LeftButton")
end

local function Pretty(key)
  if GetBindingText then
    local ok, t = pcall(GetBindingText, key)
    if ok and t and t ~= "" then return t end
  end
  return key
end

function ns.KeyLabel(which)
  local k = ns.GetCadenceKey(which)
  if k then return Pretty(k) end
  k = ns.GetSettingsKey(which)
  if k then return Pretty(k) .. " (Keybindings)" end
  return "none"
end

function ns.ApplyBindings()
  if InCombatLockdown() then
    ns.bindAfterCombat = true
    return
  end
  ns.bindAfterCombat = false
  ClearOverrideBindings(owner)
  local b = CadenceCharDB and CadenceCharDB.binds
  if not b then return end
  for which, buttonName in pairs(TARGETS) do
    if b[which] then
      SetOverrideBindingClick(owner, true, b[which], buttonName, "LeftButton")
    end
  end
end

function ns.SetCadenceKey(which, key)
  CadenceCharDB.binds = CadenceCharDB.binds or {}
  if key then
    for w, k in pairs(CadenceCharDB.binds) do
      if k == key then CadenceCharDB.binds[w] = nil end   -- one key, one button
    end
  end
  CadenceCharDB.binds[which] = key
  ns.ApplyBindings()
end

---------------------------------------------------------------------------
-- "Press a key" prompt
---------------------------------------------------------------------------

local capture
local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
  LALT = true, RALT = true, LMETA = true, RMETA = true }
local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local function WithModifiers(key)
  local mods = ""
  if IsAltKeyDown() then mods = mods .. "ALT-" end
  if IsControlKeyDown() then mods = mods .. "CTRL-" end
  if IsShiftKeyDown() then mods = mods .. "SHIFT-" end
  return mods .. key
end

local function Finish(which, key)
  capture:Hide()
  if not key then
    ns.Print("Key setup cancelled.")
    return
  end
  ns.SetCadenceKey(which, key)
  ns.Print(("The %s is now on |cffffd100%s|r. Your normal keybinds weren't changed. /cad unbind gives the key back.")
    :format(LABELS[which], Pretty(key)))
  if ns.Editor and ns.Editor.OnRebuilt then ns.Editor.OnRebuilt() end
end

function ns.StartKeyCapture(which)
  which = TARGETS[which] and which or "main"
  if InCombatLockdown() then
    ns.Print("Set keys out of combat.")
    return
  end
  if not capture then
    capture = CreateFrame("Frame", "CadenceKeyCapture", UIParent)
    capture:SetSize(440, 90)
    capture:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
    capture:SetFrameStrata("FULLSCREEN_DIALOG")
    local bg = capture:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.85)
    capture.text = capture:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    capture.text:SetPoint("CENTER")
    capture.text:SetWidth(420)
    capture:EnableKeyboard(true)
    capture:EnableMouse(true)
    capture:SetScript("OnKeyDown", function(self, key)
      if key == "ESCAPE" then Finish(self.which, nil) return end
      if MODIFIER_KEYS[key] then return end
      Finish(self.which, WithModifiers(key))
    end)
    capture:SetScript("OnMouseDown", function(self, button)
      local k = MOUSE_KEYS[button]
      if k then Finish(self.which, WithModifiers(k)) end
    end)
  end
  if capture.SetPropagateKeyboardInput then pcall(capture.SetPropagateKeyboardInput, capture, false) end
  capture.which = which
  capture.text:SetText(("Press the key for the |cffffd100%s|r.\nModifiers work (Shift/Ctrl/Alt), so do mouse buttons 3-5.\nEsc to cancel.")
    :format(LABELS[which]))
  capture:Show()
end

function ns.Unbind(which)
  if InCombatLockdown() then
    ns.Print("Change keys out of combat.")
    return
  end
  if which == "all" then
    for w in pairs(TARGETS) do ns.SetCadenceKey(w, nil) end
    ns.Print("Cadence keys removed. Your normal keybinds are back.")
  else
    which = TARGETS[which] and which or "main"
    ns.SetCadenceKey(which, nil)
    ns.Print(("The %s key was removed. That key does what it did before."):format(LABELS[which]))
  end
  if ns.Editor and ns.Editor.OnRebuilt then ns.Editor.OnRebuilt() end
end
