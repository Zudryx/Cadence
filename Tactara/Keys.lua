-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: pick a key for the rotation without touching your saved keybinds.
--
-- WoW no longer lets an action-bar macro /click a button that runs another
-- macro, so a "Tactara" macro on your bar can't cast. Instead, /tac bind lets
-- you press any key (even one your action bar already uses, like 1). Tactara
-- takes that key over with an *override* binding while the addon is loaded.
-- Your normal keybinds are never changed; /tac unbind hands the key back.

local ADDON, ns = ...

local owner = CreateFrame("Frame", "TactaraBindingOwner", UIParent)
local TARGETS = { main = "TactaraMainButton", aoe = "TactaraAoEButton", interrupt = "TactaraInterruptButton" }
local LABELS = { main = "main rotation", aoe = "AoE rotation", interrupt = "interrupt" }

function ns.GetTactaraKey(which)
  local b = TactaraCharDB and TactaraCharDB.binds
  return b and b[which] or nil
end

-- A key set in Esc > Options > Keybindings > AddOns > Tactara, if any.
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
  local k = ns.GetTactaraKey(which)
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
  local b = TactaraCharDB and TactaraCharDB.binds
  if not b then return end
  for which, buttonName in pairs(TARGETS) do
    if b[which] then
      SetOverrideBindingClick(owner, true, b[which], buttonName, "LeftButton")
    end
  end
end

-- Before 0.5.0 this addon was called Cadence, so a key set in WoW's
-- Keybindings menu still points at the old button names. Move each such key
-- to the matching Tactara button, unless that button already has a key.
local OLD_TARGETS = { main = "CadenceMainButton", aoe = "CadenceAoEButton", interrupt = "CadenceInterruptButton" }

function ns.MigrateOldKeybinds()
  if not (GetBindingKey and SetBinding) then return end
  if InCombatLockdown() then
    ns.migrateBindsAfterCombat = true
    return
  end
  ns.migrateBindsAfterCombat = false
  local moved = {}
  for which, oldName in pairs(OLD_TARGETS) do
    local newCmd = "CLICK " .. TARGETS[which] .. ":LeftButton"
    if not GetBindingKey(newCmd) then
      local keys = { GetBindingKey("CLICK " .. oldName .. ":LeftButton") }
      for _, key in ipairs(keys) do
        local ok, done = pcall(SetBinding, key, newCmd)
        if ok and done ~= false and GetBindingKey(newCmd) then moved[#moved + 1] = Pretty(key) end
      end
    end
  end
  if #moved > 0 then
    if SaveBindings and GetCurrentBindingSet then pcall(SaveBindings, GetCurrentBindingSet()) end
    ns.Print(("Kept your Keybindings-menu key%s: %s."):format(#moved > 1 and "s" or "", table.concat(moved, ", ")))
  end
end

function ns.SetTactaraKey(which, key)
  TactaraCharDB.binds = TactaraCharDB.binds or {}
  if key then
    for w, k in pairs(TactaraCharDB.binds) do
      if k == key then TactaraCharDB.binds[w] = nil end   -- one key, one button
    end
  end
  TactaraCharDB.binds[which] = key
  ns.ApplyBindings()
  if ns.Options and ns.Options.OnKeysChanged then ns.Options.OnKeysChanged() end
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

local function AfterCapture()
  local after = ns.afterKeyCapture
  ns.afterKeyCapture = nil
  if after then after() end
end

local function Finish(which, key)
  capture:Hide()
  if not key then
    ns.Print("Key setup cancelled.")
    AfterCapture()
    return
  end
  ns.SetTactaraKey(which, key)
  ns.Print(("The %s is now on |cffffd100%s|r. Your normal keybinds weren't changed. /tac unbind gives the key back.")
    :format(LABELS[which], Pretty(key)))
  if ns.Editor and ns.Editor.OnRebuilt then ns.Editor.OnRebuilt() end
  AfterCapture()
end

function ns.StartKeyCapture(which)
  which = TARGETS[which] and which or "main"
  if InCombatLockdown() then
    ns.Print("Set keys out of combat.")
    return
  end
  if not capture then
    capture = CreateFrame("Frame", "TactaraKeyCapture", UIParent)
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
    for w in pairs(TARGETS) do ns.SetTactaraKey(w, nil) end
    ns.Print("Tactara keys removed. Your normal keybinds are back.")
  else
    which = TARGETS[which] and which or "main"
    ns.SetTactaraKey(which, nil)
    ns.Print(("The %s key was removed. That key does what it did before."):format(LABELS[which]))
  end
  if ns.Editor and ns.Editor.OnRebuilt then ns.Editor.OnRebuilt() end
end
