-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: the key bar.
-- Shows what your Tactara key will cast on its next presses (the one-button
-- sequence): 1 to 10 icons, or the whole rotation. The helper popup
-- (HelperDisplay.lua) shows the best skill to use instead. Both come from
-- Tactara's own data.

local ADDON, ns = ...

local BIG, SMALL = 40, 26
local QUESTION_MARK = 134400
local MAX_ICONS = 20
ns.MAX_ICONS = MAX_ICONS
local display

-- How many icons a display shows. TactaraCharDB[key] is 1-10, or 0 for
-- "as many as there are" (the whole rotation / everything usable now).
-- Returns the count and whether it's "all".
function ns.IconCount(key)
  local v = math.floor(tonumber(TactaraCharDB[key]) or 3)
  if v <= 0 then return MAX_ICONS, true end
  return math.min(v, MAX_ICONS), false
end

-- Resize a display without moving its left edge, so icons come and go on
-- the right instead of the whole row sliding around.
function ns.SetDisplayWidth(f, w)
  local old = f:GetWidth()
  if old and math.abs(old - w) < 0.5 then return end
  local left, bottom = f:GetLeft(), f:GetBottom()
  f:SetWidth(w)
  if left and bottom and f.posKey then
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    TactaraCharDB[f.posKey] = { point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = left, y = bottom }
  end
end

local function SpellIcon(name)
  if not name then return QUESTION_MARK end
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, tex = pcall(C_Spell.GetSpellTexture, name)
    if ok and tex then return tex end
  end
  if GetSpellTexture then
    local ok, tex = pcall(GetSpellTexture, name)
    if ok and tex then return tex end
  end
  return QUESTION_MARK
end
ns.SpellIcon = SpellIcon

-- Shared by both displays: drag to move while unlocked, position saved per character.
-- Put a display where its saved position says (or its default spot).
function ns.RestorePosition(f)
  local pos = TactaraCharDB[f.posKey] or {}
  f:ClearAllPoints()
  f:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", pos.x or f.posDefaultX, pos.y or f.posDefaultY)
end

function ns.MakeMovable(f, key, defaultX, defaultY)
  f.posKey, f.posDefaultX, f.posDefaultY = key, defaultX, defaultY
  ns.RestorePosition(f)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and not TactaraCharDB.locked then self:StartMoving() end
  end)
  f:SetScript("OnMouseUp", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint(1)
    TactaraCharDB[key] = { point = point, relPoint = relPoint, x = x, y = y }
  end)
end

function ns.CreateDisplay()
  if display then return display end
  local f = CreateFrame("Frame", "TactaraDisplay", UIParent)
  f:SetSize(BIG + 2 * (SMALL + 4), BIG)
  f:SetFrameStrata("MEDIUM")
  ns.MakeMovable(f, "display", 0, -180)

  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetPoint("TOPLEFT", -4, 4)
  f.bg:SetPoint("BOTTOMRIGHT", 4, -16)
  f.bg:SetColorTexture(0, 0, 0, 0.5)

  f.icons = {}
  for i = 1, 3 do ns.KeyIcon(f, i) end

  f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.label:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -2)

  -- "PULL" tag over the first icon while you're out of combat (e.g. Charge)
  f.pullTag = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.pullTag:SetPoint("BOTTOM", f.icons[1], "BOTTOM", 0, 2)
  f.pullTag:SetText("PULL")
  ns.Style.Caption(f.pullTag, ns.Style.BRAND)
  f.pullTag:Hide()

  display = f
  ns.display = f
  ns.UpdateDisplay()
  return f
end

-- The frame around a key bar icon: the next press in Tactara's cyan, the
-- rest a thin dark edge; none in the minimal look.
local function StyleKeyIcon(t, i)
  local S = ns.Style
  if S.Minimal() then
    t.edges:Set(0)
  elseif i == 1 then
    t.edges:Set(2, S.BRAND)
  else
    t.edges:Set(1, S.DARK, 0.85)
  end
  t.look = S.Look()
end

-- Shows or hides an icon with its frame.
local function ShowKeyIcon(t, show)
  if show then t:Show() else t:Hide() end
  if t.edges then t.edges:Show(show) end
end

-- Icons are made as they're needed: big first one, smaller ones after it.
function ns.KeyIcon(f, i)
  if f.icons[i] then return f.icons[i] end
  local size = (i == 1) and BIG or SMALL
  local t = f:CreateTexture(nil, "ARTWORK")
  t:SetSize(size, size)
  t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  if i == 1 then
    t:SetPoint("LEFT", f, "LEFT", 0, 0)
  else
    t:SetPoint("BOTTOMLEFT", ns.KeyIcon(f, i - 1), "BOTTOMRIGHT", 4, 0)
    t:SetAlpha(0.75)
  end
  t.edges = ns.Style.Edges(f, t)
  StyleKeyIcon(t, i)
  f.icons[i] = t
  return t
end

-- Next presses of the Tactara key: current step's ready fallback, then the
-- following steps. Out of combat the pull (Charge) comes first. With all,
-- it stops when the rotation comes back around (the whole rotation once).
function ns.KeyQueue(n, all)
  local btn = ns.lastClicked or ns.mainButton
  local comp = ns.CompiledFor(btn)
  local q, pull = {}, false
  if not comp or #comp.steps == 0 then return q, pull end
  local inCombat = InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player"))
  if comp.pull and not inCombat then
    q[1] = comp.pull
    pull = true
  end
  local idx = btn:GetAttribute("idx") or 1
  if idx < 1 or idx > #comp.steps then idx = 1 end
  q[#q + 1] = ns.PickForStep(comp, idx)
  local seen = { [idx] = true }
  for _ = 1, n + #comp.steps do
    if #q >= n then break end
    idx = ns.NextStepIdx(comp, idx)
    local step = comp.steps[idx]
    if not step or (all and seen[idx]) then break end
    seen[idx] = true
    q[#q + 1] = step.icon or (step.spells and step.spells[1])
  end
  return q, pull
end

---------------------------------------------------------------------------
-- When you're not fighting (out of combat, no living enemy targeted), each
-- display can show normally ("show"), be see-through ("fade") or hide.
-- While unlocked, "hide" shows see-through instead, so you can still move them.
---------------------------------------------------------------------------

function ns.NotFighting()
  local inCombat = InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player"))
  if inCombat then return false end
  local ok, enemy = pcall(function()
    return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
  end)
  return not (ok and enemy)
end

-- "Hide while mounted" (off unless you turn it on): on a mount or a flight
-- path, and not in a fight, both displays step aside. Not while they're
-- unlocked, so you can still move them.
function ns.HiddenForMount()
  if not (TactaraCharDB and TactaraCharDB.hideMounted and TactaraCharDB.locked) then return false end
  if InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player")) then return false end
  local ok, riding = pcall(function()
    return (IsMounted and IsMounted()) or (UnitOnTaxi and UnitOnTaxi("player")) or false
  end)
  return ok and riding and true or false
end

-- Returns false when the display should stay hidden right now.
function ns.ApplyIdleLook(f, mode)
  if mode == "show" or not ns.NotFighting() then
    f:SetAlpha(1)
    return true
  end
  if mode == "hide" and TactaraCharDB.locked then
    f:Hide()
    return false
  end
  f:SetAlpha(tonumber(TactaraCharDB.fadeAlpha) or 0.45)
  return true
end

function ns.UpdateDisplay()
  local f = display
  if not f then return end
  if not TactaraCharDB.showDisplay or ns.HiddenForMount() then
    f:Hide()
    return
  end

  local locked = TactaraCharDB.locked
  f:EnableMouse(not locked)
  if locked then f.bg:Hide() else f.bg:Show() end

  local look = ns.Style.Look()
  for i, t in ipairs(f.icons) do
    if t.look ~= look then StyleKeyIcon(t, i) end
  end

  local n, all = ns.IconCount("keyIcons")
  local shown, pull = ns.KeyQueue(n, all)
  local slots = all and math.max(#shown, 1) or n
  ns.SetDisplayWidth(f, BIG + (slots - 1) * (SMALL + 4))
  for i = slots + 1, #f.icons do ShowKeyIcon(f.icons[i], false) end

  if #shown == 0 then
    f.pullTag:Hide()
    if locked then f:Hide() return end
    f:Show()
    for i = 1, slots do
      ns.KeyIcon(f, i):SetTexture(QUESTION_MARK)
      ShowKeyIcon(f.icons[i], true)
    end
    f.label:SetText("Tactara key: no steps yet (drag to move, /tac lock)")
    return
  end

  f:Show()
  if not ns.ApplyIdleLook(f, TactaraCharDB.keyIdle) then return end
  if pull then f.pullTag:Show() else f.pullTag:Hide() end
  for i = 1, slots do
    local icon = ns.KeyIcon(f, i)
    if shown[i] then
      icon:SetTexture(SpellIcon(shown[i]))
      ShowKeyIcon(icon, true)
    else
      ShowKeyIcon(icon, false)
    end
  end

  if locked then
    f.label:SetText(ns.IsAoEButton(ns.lastClicked) and "Key (AoE)" or "")
  else
    f.label:SetText("Tactara KEY: next presses (drag, /tac lock)")
  end
end
