-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: interrupts and defensives for the rotation helper.
--
-- These only appear when the moment calls for it:
--   * Interrupt (red): your target is casting something you can interrupt.
--     The first spell from the rotation's [interrupt] list that's usable in
--     your current stance/gear and off cooldown is suggested.
--   * Defensive (orange): in combat, the first [defensive] line whose checks
--     pass (e.g. "@health 30") and that's ready.
-- They're never part of the one-button sequence, so the rotation key won't
-- waste an interrupt or a big cooldown. The separate Tactara Interrupt key
-- (/tac bind interrupt) casts the right interrupt for your stance and gear.
--
-- A sound can play when either slot lights up (off unless you pick one).
-- Like the glow, it only tells you; you still press the key.

local ADDON, ns = ...

-- "interruptible" / "uninterruptible" / "none" / "unknown" (hidden from addons)
function ns.TargetCastState()
  local ok, state = pcall(function()
    if not (UnitExists("target") and UnitCanAttack("player", "target")) then return "none" end
    local name, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
    if not name then
      local cname, _, _, _, _, _, cnot = UnitChannelInfo("target")
      name, notInterruptible = cname, cnot
    end
    if not name then return "none" end
    local okFlag, locked = pcall(function() return notInterruptible and true or false end)
    if okFlag and locked then return "uninterruptible" end
    return "interruptible"   -- if the flag is hidden, assume it can be interrupted
  end)
  if ok then return state end
  return "unknown"
end

local function InCombat()
  return InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player")) or false
end

local function FirstReady(list)
  for _, e in ipairs(list or {}) do
    if ns.LiveOK(e) and ns.SpellReady(e.spell) then return e.spell end
  end
  return nil
end

-- { interrupt = spell or nil, defensive = spell or nil, castState = ... }
function ns.UtilityPicks()
  local out = {}
  local comp = ns.compiled and ns.compiled.main
  if not comp or not TactaraCharDB then return out end
  if TactaraCharDB.interrupts and comp.interrupts and #comp.interrupts > 0 then
    out.castState = ns.TargetCastState()
    if out.castState == "interruptible" then out.interrupt = FirstReady(comp.interrupts) end
  end
  if TactaraCharDB.defensives and InCombat() and comp.defensives and #comp.defensives > 0 then
    out.defensive = FirstReady(comp.defensives)
  end
  return out
end

---------------------------------------------------------------------------
-- Sounds when the interrupt or defensive slot lights up
---------------------------------------------------------------------------

-- The game's own sounds (by name, with the number as a fallback).
ns.SOUNDS = {
  { key = "raid", label = "Raid warning", kit = "RAID_WARNING", id = 8959 },
  { key = "ready", label = "Ready check", kit = "READY_CHECK", id = 8960 },
  { key = "alarm", label = "Alarm clock", kit = "ALARM_CLOCK_WARNING_3", id = 12889 },
  { key = "ping", label = "Map ping", kit = "MAP_PING", id = 3175 },
  { key = "whisper", label = "Whisper", kit = "TELL_MESSAGE", id = 3081 },
}
ns.SOUND_DEFAULTS = { interrupt = "raid", defensive = "alarm", buff = "ready" }   -- for "/tac sound interrupt on"

function ns.SoundFor(key)
  for _, s in ipairs(ns.SOUNDS) do
    if s.key == key then return s end
  end
  return nil
end

-- Plays one of the sounds above on the master channel (so it's heard with
-- game sounds turned down). true if the game played it.
function ns.PlayAlert(key)
  local s = ns.SoundFor(key)
  if not (s and PlaySound) then return false end
  local id = (type(SOUNDKIT) == "table" and SOUNDKIT[s.kit]) or s.id
  local ok, played = pcall(PlaySound, id, "Master")
  return ok and played ~= false
end

-- At most one sound per this many seconds: a chain of casts shouldn't buzz,
-- and a defensive that comes and goes with your health shouldn't either.
local SOUND_GAP = { interrupt = 1.5, defensive = 10 }
local lastSound = { interrupt = -1e9, defensive = -1e9 }
local wasLit = {}

-- With each new set of picks: a sound when a slot goes from empty to lit.
function ns.UtilitySounds(util)
  if not TactaraCharDB then return end
  local now = GetTime()
  for _, kind in ipairs({ "interrupt", "defensive" }) do
    local lit = util and util[kind] ~= nil or false
    if lit and not wasLit[kind] then
      local key = TactaraCharDB[kind .. "Sound"]
      if key and key ~= "off" and now - lastSound[kind] >= SOUND_GAP[kind] and ns.PlayAlert(key) then
        lastSound[kind] = now
      end
    end
    wasLit[kind] = lit
  end
end

function ns.ResetUtilitySounds()
  lastSound.interrupt, lastSound.defensive = -1e9, -1e9
  wasLit = {}
end

-- React to target casts right away (the helper's tick also catches them).
local f = CreateFrame("Frame")
ns.utilityFrame = f
for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
  "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
  "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" }) do
  if f.RegisterUnitEvent then
    pcall(f.RegisterUnitEvent, f, e, "target")
  else
    pcall(f.RegisterEvent, f, e)
  end
end
pcall(f.RegisterUnitEvent or f.RegisterEvent, f, "UNIT_HEALTH", "player")
f:SetScript("OnEvent", function()
  if ns.loggedIn then ns.HelperRefresh() end
end)
