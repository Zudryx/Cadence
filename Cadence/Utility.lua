-- Cadence: interrupts and defensives for the rotation helper.
--
-- These only appear when the moment calls for it:
--   * Interrupt (red): your target is casting something you can interrupt.
--     The first spell from the rotation's [interrupt] list that's usable in
--     your current stance/gear and off cooldown is suggested.
--   * Defensive (orange): in combat, the first [defensive] line whose checks
--     pass (e.g. "@health 30") and that's ready.
-- They're never part of the one-button sequence, so the rotation key won't
-- waste an interrupt or a big cooldown. The separate Cadence Interrupt key
-- (/cad bind interrupt) casts the right interrupt for your stance and gear.

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
  if not comp or not CadenceCharDB then return out end
  if CadenceCharDB.interrupts and comp.interrupts and #comp.interrupts > 0 then
    out.castState = ns.TargetCastState()
    if out.castState == "interruptible" then out.interrupt = FirstReady(comp.interrupts) end
  end
  if CadenceCharDB.defensives and InCombat() and comp.defensives and #comp.defensives > 0 then
    out.defensive = FirstReady(comp.defensives)
  end
  return out
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
