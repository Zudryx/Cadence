-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: rotation helper (bar highlight).
--
-- Two ways to play with the same rotation:
--   * One-button: press your Tactara key. The highlight shows what it's
--     about to cast.
--   * Visual helper: press your own spells. Tactara follows what you cast
--     and puts a pulsing blue border (like retail's Assisted Highlight) on
--     the next spell on your action bars.
--
-- If the rotation has a [priority] list, the helper picks the best spell: at
-- every moment it shows the highest line that's ready (off cooldown, usable,
-- live checks passed). While you're pressing the Tactara key it shows the
-- key's sequence instead, so the glow matches what the key will cast.
-- Without a [priority] list it follows the sequence, skipping fallbacks
-- that are on cooldown or unusable.
--
-- When WoW hides something from addons (rage, target health, and in
-- restricted fights cooldowns/auras), the checks that need it are skipped.
-- Purely visual: nothing here presses, casts or changes your buttons.

local ADDON, ns = ...

local H = { idx = 1, button = nil, lastPress = 0 }
ns.Helper = H

local TICK = 0.2            -- refresh rate while there's something to show
local PRESS_GRACE = 0.6     -- ignore cast events this soon after a Tactara press
local LOOKAHEAD = 3         -- manual cast may skip up to this many steps
local SEQUENCE_HOLD = 3     -- seconds after a Tactara press that the helper shows the key's sequence
local GLOW_COLORS = {
  next = ns.Style.BRAND,              -- Tactara's cyan: next spell (like retail's Assisted Highlight)
  interrupt = { 1.00, 0.20, 0.20 },   -- red: interrupt now
  defensive = { 1.00, 0.60, 0.10 },   -- orange: defensive cooldown
}
ns.GLOW_COLORS = GLOW_COLORS

---------------------------------------------------------------------------
-- Sequence position (shared with the Tactara buttons)
---------------------------------------------------------------------------

function ns.HelperComp()
  local b = H.button or ns.mainButton
  return ns.CompiledFor(b), b
end

function ns.NextStepIdx(comp, i)
  i = i + 1
  if i > #comp.steps then i = comp.loopStart or 1 end
  return i
end

local function ClampIdx(comp)
  if H.idx < 1 or H.idx > math.max(1, #comp.steps) then H.idx = 1 end
  return H.idx
end

function ns.HelperReset()
  H.idx = 1
end

-- A Tactara key press: jump to wherever the button is now.
function ns.HelperSync(button)
  H.button = button
  H.idx = button:GetAttribute("idx") or 1
  H.lastPress = GetTime()
end

---------------------------------------------------------------------------
-- Can this spell be cast right now? true / false. Unknown counts as yes,
-- so hidden values make the helper fall back to the rotation order.
---------------------------------------------------------------------------

local function OnCooldown(name)
  if not (C_Spell and C_Spell.GetSpellCooldown) then return false end
  local ok, result = pcall(function()
    local cd = C_Spell.GetSpellCooldown(name)
    if type(cd) ~= "table" then return false end
    if cd.isOnGCD then return false end              -- the global cooldown doesn't count
    if cd.isActive ~= nil then return cd.isActive and true or false end
    if cd.duration and cd.duration > 1.5 and cd.startTime and cd.startTime > 0 then
      return (cd.startTime + cd.duration - GetTime()) > 0.1
    end
    return false
  end)
  return ok and result == true
end

-- "yes" / "power" (only short on Rage) / "no" (no proc, wrong stance,
-- target too healthy) / "unknown" (hidden from addons)
local function UsableState(name)
  if not (C_Spell and C_Spell.IsSpellUsable) then return "unknown" end
  local ok, state = pcall(function()
    local usable, noPower = C_Spell.IsSpellUsable(name)
    if usable then return "yes" end
    if noPower then return "power" end
    return "no"
  end)
  return ok and state or "unknown"
end
ns.UsableState = UsableState

function ns.SpellReady(name)
  return not OnCooldown(name) and UsableState(name) ~= "no"
end

-- Best spell for one step: the first of its fallbacks that's ready.
function ns.PickForStep(comp, i)
  local step = comp and comp.steps[i]
  if not step then return nil end
  for _, s in ipairs(step.spells or {}) do
    if ns.SpellReady(s) then return s end
  end
  return step.icon
end

---------------------------------------------------------------------------
-- Live checks for [priority] lines. true / false / nil (can't tell -> skip line)
---------------------------------------------------------------------------

-- Is this buff (on you) / your debuff (on the target) missing or about to run out?
-- A spell on your stance bar (Paladin auras, stances, forms) asks the stance
-- bar. Otherwise the game's answer wins when it gives one (including "not
-- there", out of combat, when it's showing your buffs: ns.AuraReadable), and
-- Tactara's own timer from your cast decides when it doesn't. true = missing,
-- false = up, nil = can't tell.
local REFRESH = 3
local function AuraMissing(unit, name, filter)
  if unit == "player" then
    local form = ns.FormActive(name)      -- a Paladin aura or a stance: the stance bar knows
    if form ~= nil then return not form end
  end
  local mine = ns.TrackedRemaining(unit, name)
  local aura
  local okAPI = false
  if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
    okAPI, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, name, filter)
  end
  if okAPI and aura ~= nil then
    if unit == "player" then ns.NoteAuraSeen(aura) end
    pcall(function() ns.LearnDuration(name, aura.duration) end)
    local okT, expiring = pcall(function()
      local exp = aura.expirationTime
      return exp ~= nil and exp > 0 and (exp - GetTime()) < REFRESH
    end)
    return okT and expiring or false
  end
  if okAPI and unit == "player" and ns.AuraReadable(name) then
    ns.ForgetTracked("player", name)         -- clicked off, dispelled or died: it's gone
    return true
  end
  if mine then return mine < REFRESH end     -- our timer says it's up
  if okAPI then return true end              -- game says no, and we didn't cast it
  return nil                                 -- game hides it and we have no timer
end

-- How long a buff on you has left, in seconds (math.huge: until you change
-- it, 0: not there), and its full length. nil when Tactara can't tell.
-- Out of combat the game usually says; otherwise Tactara's timer from your cast.
function ns.BuffTimeLeft(name)
  local form = ns.FormActive(name)
  if form ~= nil then return form and math.huge or 0, math.huge end
  local okAPI, aura = false, nil
  if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
    okAPI, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
  end
  if okAPI and aura ~= nil then
    ns.NoteAuraSeen(aura)
    local ok, left, full = pcall(function()
      local exp, dur = aura.expirationTime, aura.duration
      if not exp or exp == 0 then return math.huge, math.huge end
      local d = (dur and dur > 0) and dur or nil
      return math.max(0, exp - GetTime()), d
    end)
    if ok then return left, full or ns.BuffDuration(name) end
  end
  if okAPI and ns.AuraReadable(name) then
    ns.ForgetTracked("player", name)
    return 0, ns.BuffDuration(name)
  end
  local mine = ns.TrackedRemaining("player", name)
  if mine then return math.max(0, mine), ns.BuffDuration(name) end
  if okAPI then return 0, ns.BuffDuration(name) end
  return nil
end

-- When a buff counts as running low, by its full length: an hour-long
-- Blessing under 5 minutes, a 30-minute buff under 2, a 5-10 minute one
-- under 1, a 1-2 minute one (Battle Shout) under 30 seconds. Shorter ones
-- (Seals) only when they're about to drop. Never for auras and forms.
-- The "Buffs running low" setting moves these: early = twice as long,
-- late = half, off = only when they're missing.
ns.BUFF_LOW_FACTOR = { early = 2, normal = 1, late = 0.5, off = 0 }

function ns.BuffLowAt(full)
  if not full or full == math.huge then return 0 end
  local base
  if full >= 3000 then base = 300
  elseif full >= 1200 then base = 120
  elseif full >= 300 then base = 60
  elseif full >= 60 then base = 30
  else return REFRESH end
  local factor = ns.BUFF_LOW_FACTOR[TactaraCharDB and TactaraCharDB.buffLow or "normal"] or 1
  return base * factor
end

function ns.CheckLive(c)
  if c.kind == "enemies" then
    local need = tonumber(c.arg:match("%d+")) or 2
    return ns.CountEnemies() >= need
  elseif c.kind == "missing" then
    return AuraMissing("player", c.arg, "HELPFUL")
  elseif c.kind == "nodebuff" then
    local okE, exists = pcall(UnitExists, "target")
    if not (okE and exists) then return false end
    return AuraMissing("target", c.arg, "HARMFUL|PLAYER")
  elseif c.kind == "health" then
    local pct = ns.PlayerHealthPct()
    if not pct then return nil end
    return pct < (tonumber(c.arg:match("%d+")) or 35)
  elseif c.kind == "creature" then
    local ok, kind = pcall(function()
      if not UnitExists("target") then return false end
      local t = UnitCreatureType("target")
      return t and (tostring(t) .. "") or false   -- errors if the game hides it
    end)
    if not ok then return nil end
    if not kind then return false end
    for want in c.arg:gmatch("[^,/]+") do
      if ns.trim(want):lower() == kind:lower() then return true end
    end
    return false
  elseif c.kind == "combo" then
    return (ns.ComboPoints() or 0) >= (tonumber(c.arg:match("%d+")) or 5)
  elseif c.kind == "nopet" then
    local ok, missing = pcall(function()
      return not UnitExists("pet") or UnitIsDead("pet") == true
    end)
    if not ok then return nil end
    return missing and true or false
  end
  return true
end

-- Your own health in percent, or nil if the game hides it.
function ns.PlayerHealthPct()
  local ok, pct = pcall(function()
    local h, m = UnitHealth("player"), UnitHealthMax("player")
    if m and m > 0 then return h / m * 100 end
    return nil
  end)
  if ok then return pct end
  return nil
end

local function LiveOK(entry)
  for _, c in ipairs(entry.live) do
    if ns.CheckLive(c) ~= true then return false end
  end
  return true
end
ns.LiveOK = LiveOK

-- Up to n spells from the [priority] list, best first: ready ones, then
-- ones only waiting on Rage.
function ns.PriorityCandidates(comp, n)
  local ready, waiting, seen = {}, {}, {}
  for _, e in ipairs(comp.priority or {}) do
    if not seen[e.spell] and LiveOK(e) and not OnCooldown(e.spell) then
      local u = UsableState(e.spell)
      if u == "yes" or u == "unknown" then
        ready[#ready + 1] = e.spell
        seen[e.spell] = true
      elseif u == "power" then
        waiting[#waiting + 1] = e.spell
        seen[e.spell] = true
      end
    end
    if #ready >= n then break end
  end
  local out = {}
  for _, s in ipairs(ready) do if #out < n then out[#out + 1] = s end end
  for _, s in ipairs(waiting) do if #out < n then out[#out + 1] = s end end
  return out
end

function ns.HelperUsesPriority(comp)
  if not comp or not comp.priority or #comp.priority == 0 then return false end
  local mode = TactaraCharDB and TactaraCharDB.helperMode or "auto"
  if mode == "sequence" then return false end
  if mode == "priority" then return true end
  return (GetTime() - H.lastPress) > SEQUENCE_HOLD or #comp.steps == 0
end

local function HasHostileTarget()
  local ok, result = pcall(function()
    return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
  end)
  return ok and result and true or false
end

local function InCombat()
  return InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player")) or false
end

-- What the helper suggests next: a list of up to n spells, plus whether the
-- first one is the out-of-combat pull (Charge).
function ns.HelperQueue(n, forDisplay, forceMode, all)
  local comp = ns.HelperComp()
  local q, pull = {}, false
  if not comp or (#comp.steps == 0 and #(comp.priority or {}) == 0) then return q, pull end
  if not InCombat() and comp.pull and (forDisplay or ns.SpellReady(comp.pull)) then
    q[1] = comp.pull
    pull = true
  end
  local usePriority
  if forceMode == "priority" then
    usePriority = comp.priority and #comp.priority > 0
  else
    usePriority = ns.HelperUsesPriority(comp)
  end
  if usePriority then
    for _, s in ipairs(ns.PriorityCandidates(comp, n)) do
      if #q < n and s ~= q[1] then q[#q + 1] = s end
    end
    if #q == 0 then
      -- nothing ready: show the first line that applies right now (the next
      -- one off cooldown), not a buff or pet line that isn't needed
      for _, e in ipairs(comp.priority) do
        if LiveOK(e) and #e.live == 0 then q[1] = e.spell break end
      end
      q[1] = q[1] or comp.priority[1].spell
    end
  elseif #comp.steps > 0 then
    local i = ClampIdx(comp)
    q[#q + 1] = ns.PickForStep(comp, i)
    local seen = { [i] = true }
    for _ = 1, n + #comp.steps do
      if #q >= n then break end
      i = ns.NextStepIdx(comp, i)
      local step = comp.steps[i]
      if not step or (all and seen[i]) then break end
      seen[i] = true
      q[#q + 1] = step.icon or (step.spells and step.spells[1])
    end
  end
  return q, pull
end

-- What the bar highlight should point at right now (spell name or nil).
function ns.HelperPick()
  if not InCombat() and not HasHostileTarget() then return nil end
  local q = ns.HelperQueue(1)
  return q[1]
end

---------------------------------------------------------------------------
-- Following manual casts
---------------------------------------------------------------------------

local function SpellName(spellID)
  local ok, name = pcall(function()
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
    if GetSpellInfo then return (GetSpellInfo(spellID)) end
  end)
  if ok then return name end
  return nil
end

local function StepHas(step, name)
  local ok, found = pcall(function()
    for _, s in ipairs(step.spells or {}) do
      if s == name then return true end
    end
    return false
  end)
  if not ok then return nil end   -- name is hidden from addons
  return found
end

function ns.OnPlayerCast(spellID)
  ns.TrackCast(SpellName(spellID))                           -- buff/debuff timers (Tracker.lua)
  if GetTime() - H.lastPress < PRESS_GRACE then
    ns.HelperRefresh()
    return                                                   -- the Tactara key already moved us
  end
  local comp = ns.HelperComp()
  if not comp or #comp.steps == 0 then ns.HelperRefresh() return end
  local name = SpellName(spellID)
  local i = ClampIdx(comp)
  for _ = 0, LOOKAHEAD do
    local has = StepHas(comp.steps[i], name)
    if has == nil then
      H.idx = ns.NextStepIdx(comp, ClampIdx(comp))   -- can't read the spell: assume it was the step
      ns.HelperRefresh()
      return
    end
    if has then
      H.idx = ns.NextStepIdx(comp, i)
      ns.Debug(("helper: you cast %s, next is step %d"):format(tostring(name), H.idx))
      ns.HelperRefresh()
      return
    end
    i = ns.NextStepIdx(comp, i)
  end
  ns.HelperRefresh()
end

---------------------------------------------------------------------------
-- Finding your action buttons (Blizzard bars, Bartender4, ElvUI, Dominos)
---------------------------------------------------------------------------

local BLIZZARD_BARS = {
  "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
  "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button", "BonusActionButton",
}

local buttonList = {}
local spellButtons = {}     -- [spell name] = { button, ... }
local mapDirty = true

local function CollectButtons()
  local list = {}
  local function add(name)
    local b = _G[name]
    if type(b) == "table" and b.GetObjectType then list[#list + 1] = b end
  end
  for _, prefix in ipairs(BLIZZARD_BARS) do
    for i = 1, 12 do add(prefix .. i) end
  end
  for i = 1, 180 do add("BT4Button" .. i) end
  for i = 1, 180 do add("DominosActionButton" .. i) end
  for bar = 1, 15 do
    for i = 1, 12 do add("ElvUI_Bar" .. bar .. "Button" .. i) end
  end
  buttonList = list
end

local function ButtonSlot(btn)
  if btn._state_type == "action" and type(btn._state_action) == "number" then
    return btn._state_action                       -- LibActionButton (Bartender4, ElvUI)
  end
  if type(btn.action) == "number" then return btn.action end
  local ok, a = pcall(btn.GetAttribute, btn, "action")
  if ok and type(a) == "number" then return a end
  return nil
end

local function SlotSpellName(slot)
  local ok, name = pcall(function()
    local kind, id = GetActionInfo(slot)
    if kind == "macro" and GetMacroSpell then
      id = GetMacroSpell(id)
      kind = id and "spell" or nil
    end
    if kind == "spell" and id then return SpellName(id) end
    return nil
  end)
  if ok and type(name) == "string" then return name end
  return nil
end

local function RebuildMap()
  CollectButtons()
  for k in pairs(spellButtons) do spellButtons[k] = nil end
  for _, btn in ipairs(buttonList) do
    local slot = ButtonSlot(btn)
    local name = slot and SlotSpellName(slot)
    if name then
      spellButtons[name] = spellButtons[name] or {}
      table.insert(spellButtons[name], btn)
    end
  end
  mapDirty = false
end

function ns.ButtonsForSpell(name)
  if mapDirty then RebuildMap() end
  return spellButtons[name] or {}, #buttonList
end

---------------------------------------------------------------------------
-- The glow (our own frames on top of your buttons; never edits the buttons)
---------------------------------------------------------------------------

local glows = {}
local lit = {}
H.lit, H.glows = lit, glows   -- for /tac test and the test suite

-- Glow strength (/tac glow strong | normal | subtle). Strong is the default.
--   edge  = solid border just outside the button
--   halo  = soft glow ring around that border
--   inner = tint over the icon itself
--   low   = how far the pulse fades (1 = never fades)
local GLOW_STYLES = {
  subtle = { edge = 3, halo = 0,  haloAlpha = 0,    inner = 0.15, low = 0.35, speed = 0.6 },
  normal = { edge = 4, halo = 5,  haloAlpha = 0.40, inner = 0.22, low = 0.50, speed = 0.5 },
  strong = { edge = 5, halo = 9,  haloAlpha = 0.55, inner = 0.30, low = 0.65, speed = 0.4 },
}
ns.GLOW_STYLES = GLOW_STYLES

local function GlowStyle()
  local name = TactaraDB and TactaraDB.glowStyle
  return GLOW_STYLES[name] or GLOW_STYLES.strong, GLOW_STYLES[name] and name or "strong"
end

-- A rectangular ring `thickness` wide, `inset` in from the frame's edges.
local function Ring(g, inset, thickness, alpha)
  if thickness <= 0 or alpha <= 0 then return end
  local function rect(a1, x1, y1, a2, x2, y2, w, h)
    local t = g:CreateTexture(nil, "OVERLAY")
    t:SetBlendMode("ADD")
    t:SetPoint(a1, g, a1, x1, y1)
    t:SetPoint(a2, g, a2, x2, y2)
    if w then t:SetWidth(w) end
    if h then t:SetHeight(h) end
    g.parts[#g.parts + 1] = { tex = t, alpha = alpha }
  end
  rect("TOPLEFT", inset, -inset, "TOPRIGHT", -inset, -inset, nil, thickness)
  rect("BOTTOMLEFT", inset, inset, "BOTTOMRIGHT", -inset, inset, nil, thickness)
  rect("TOPLEFT", inset, -(inset + thickness), "BOTTOMLEFT", inset, inset + thickness, thickness, nil)
  rect("TOPRIGHT", -inset, -(inset + thickness), "BOTTOMRIGHT", -inset, inset + thickness, thickness, nil)
end

local function MakeGlow(btn)
  local st, styleName = GlowStyle()
  local out = st.edge + st.halo
  local g = CreateFrame("Frame", nil, btn)
  g:SetPoint("TOPLEFT", btn, "TOPLEFT", -out, out)
  g:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", out, -out)
  g:SetFrameLevel((btn:GetFrameLevel() or 1) + 10)
  g.parts = {}
  g.style = styleName
  -- soft halo: two rings fading outwards
  local half = math.floor(st.halo / 2)
  Ring(g, 0, half, st.haloAlpha * 0.45)
  Ring(g, half, st.halo - half, st.haloAlpha)
  -- solid border hugging the button
  Ring(g, st.halo, st.edge, 1)
  -- tint over the icon
  local inner = g:CreateTexture(nil, "OVERLAY")
  inner:SetPoint("TOPLEFT", g, "TOPLEFT", out, -out)
  inner:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", -out, out)
  inner:SetBlendMode("ADD")
  g.parts[#g.parts + 1] = { tex = inner, alpha = st.inner }
  -- pulse
  local ag = g:CreateAnimationGroup()
  ag:SetLooping("BOUNCE")
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(1)
  a:SetToAlpha(st.low)
  a:SetDuration(st.speed)
  g.anim = ag
  g:Hide()
  return g
end

local function ColorGlow(g, kind)
  local c = GLOW_COLORS[kind] or GLOW_COLORS.next
  for _, p in ipairs(g.parts) do p.tex:SetColorTexture(c[1], c[2], c[3], p.alpha) end
  g.kind = kind
end

local function ShowGlow(btn, kind)
  local g = glows[btn]
  if g and g.style ~= select(2, GlowStyle()) then    -- style changed: rebuild this glow
    if g.anim then g.anim:Stop() end
    g:Hide()
    g = nil
  end
  if not g then
    g = MakeGlow(btn)
    glows[btn] = g
  end
  if g.kind ~= kind then ColorGlow(g, kind) end
  g:Show()
  if g.anim then g.anim:Play() end
end

local function HideGlow(btn)
  local g = glows[btn]
  if not g then return end
  if g.anim then g.anim:Stop() end
  g:Hide()
end

-- The same glow on other buttons (the talent planner uses it in the talent window).
ns.ShowButtonGlow = ShowGlow
ns.HideButtonGlow = HideGlow

ns.lastHighlight = nil

function ns.UpdateHighlight()
  if ns.previewing then return end
  local want = {}
  local spell
  local util = ns.UtilityPicks()          -- also feeds the helper popup's red/orange slots
  if TactaraCharDB and TactaraCharDB.highlight then
    spell = ns.HelperPick()
    local function mark(name, kind)
      if not name then return end
      for _, btn in ipairs((ns.ButtonsForSpell(name))) do
        if btn:IsVisible() then want[btn] = kind end
      end
    end
    mark(spell, "next")
    mark(util.defensive, "defensive")
    mark(util.interrupt, "interrupt")     -- interrupt wins if it's the same button
  end
  for btn in pairs(lit) do
    if not want[btn] then HideGlow(btn); lit[btn] = nil end
  end
  for btn, kind in pairs(want) do
    if lit[btn] ~= kind then ShowGlow(btn, kind); lit[btn] = kind end
  end
  ns.lastHighlight = spell
  ns.lastUtility = util
  if ns.UtilitySounds then ns.UtilitySounds(util) end
end

-- /tac glow <style>: switch style and show a 3-second preview of all three
-- colors on your bars (blue next, red interrupt, orange defensive).
function ns.SetGlowStyle(name)
  if name and GLOW_STYLES[name] then TactaraDB.glowStyle = name end
  for btn in pairs(lit) do
    HideGlow(btn)
    lit[btn] = nil
  end
  ns.PreviewGlow()
end

function ns.PreviewGlow()
  if mapDirty then RebuildMap() end
  local kinds = { "next", "interrupt", "defensive" }
  local shown = 0
  ns.previewing = true
  for _, btn in ipairs(buttonList) do
    if shown >= 3 then break end
    local slot = ButtonSlot(btn)
    if slot and SlotSpellName(slot) and btn:IsVisible() then
      shown = shown + 1
      ShowGlow(btn, kinds[shown])
      lit[btn] = kinds[shown]
    end
  end
  C_Timer.After(3, function()
    ns.previewing = false
    for btn in pairs(lit) do
      HideGlow(btn)
      lit[btn] = nil
    end
    ns.UpdateHighlight()
  end)
  return shown
end

function ns.HelperRefresh()
  ns.UpdateHighlight()
  ns.UpdateDisplay()
  if ns.UpdateHelperPopup then ns.UpdateHelperPopup() end
end

---------------------------------------------------------------------------
-- Events + a light refresh tick (cooldowns finishing, procs appearing)
---------------------------------------------------------------------------

local f = CreateFrame("Frame")
ns.helperFrame = f

local function Reg(event, unit)
  if unit and f.RegisterUnitEvent then
    pcall(f.RegisterUnitEvent, f, event, unit)
  else
    pcall(f.RegisterEvent, f, event)
  end
end

for _, e in ipairs({ "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
  "UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD", "ACTIONBAR_HIDEGRID" }) do
  Reg(e)
end
-- mounting, and taking or leaving a flight path (for "hide while mounted")
for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE",
  "PLAYER_REGEN_DISABLED", "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED" }) do
  Reg(e)
end
Reg("UNIT_SPELLCAST_SUCCEEDED", "player")

f:SetScript("OnEvent", function(self, event, ...)
  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    local _, _, spellID = ...
    ns.OnPlayerCast(spellID)
    return
  end
  if event == "ACTIONBAR_SLOT_CHANGED" or event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR"
    or event == "UPDATE_SHAPESHIFT_FORM" or event == "PLAYER_ENTERING_WORLD" or event == "ACTIONBAR_HIDEGRID" then
    mapDirty = true    -- stance changes swap the warrior's main bar page
  end
  if ns.loggedIn then ns.HelperRefresh() end
end)

local elapsedTotal, sinceMap = 0, 0
f:SetScript("OnUpdate", function(self, elapsed)
  elapsedTotal = elapsedTotal + elapsed
  if elapsedTotal < TICK then return end
  sinceMap = sinceMap + elapsedTotal
  elapsedTotal = 0
  if not ns.loggedIn then return end
  if sinceMap > 2 then          -- bar addons can page without events we see
    mapDirty = true
    sinceMap = 0
  end
  if InCombat() or HasHostileTarget() or next(lit) then
    ns.HelperRefresh()
  end
end)

function ns.HelperDiagnose()
  local spell = ns.HelperPick()
  local btns, total = ns.ButtonsForSpell(spell or "")
  local comp = ns.HelperComp()
  local mode = ns.HelperUsesPriority(comp) and "priority list" or "sequence"
  return ("bar highlight %s (%s) | timers: %s | %d action buttons found | now pointing at: %s%s"):format(
    TactaraCharDB.highlight and "ON" or "OFF", mode, ns.TrackerSummary(), total, tostring(spell or "nothing (no enemy targeted)"),
    spell and (" (on " .. #btns .. " button" .. (#btns == 1 and "" or "s") .. ")") or "")
end
