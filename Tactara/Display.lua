-- Tactara: the key bar.
-- Shows what your Tactara key will cast on its next 3 presses (the
-- one-button sequence). The helper popup (HelperDisplay.lua) shows the best
-- skill to use instead. Both come from Tactara's own data.

local ADDON, ns = ...

local BIG, SMALL = 40, 26
local QUESTION_MARK = 134400
local display

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
function ns.MakeMovable(f, key, defaultX, defaultY)
  local pos = TactaraCharDB[key] or {}
  f:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", pos.x or defaultX, pos.y or defaultY)
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
  for i = 1, 3 do
    local size = (i == 1) and BIG or SMALL
    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetSize(size, size)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if i == 1 then
      t:SetPoint("LEFT", f, "LEFT", 0, 0)
    else
      t:SetPoint("BOTTOMLEFT", f.icons[i - 1], "BOTTOMRIGHT", 4, 0)
      t:SetAlpha(0.75)
    end
    f.icons[i] = t
  end

  f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.label:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -2)

  -- "PULL" tag over the first icon while you're out of combat (e.g. Charge)
  f.pullTag = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.pullTag:SetPoint("BOTTOM", f.icons[1], "BOTTOM", 0, 2)
  f.pullTag:SetText("PULL")
  f.pullTag:Hide()

  display = f
  ns.display = f
  ns.UpdateDisplay()
  return f
end

-- Next presses of the Tactara key: current step's ready fallback, then the
-- following steps. Out of combat the pull (Charge) comes first.
function ns.KeyQueue(n)
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
  while #q < n do
    idx = ns.NextStepIdx(comp, idx)
    q[#q + 1] = comp.steps[idx] and comp.steps[idx].icon
  end
  return q, pull
end

function ns.UpdateDisplay()
  local f = display
  if not f then return end
  if not TactaraCharDB.showDisplay then
    f:Hide()
    return
  end

  local locked = TactaraCharDB.locked
  f:EnableMouse(not locked)
  if locked then f.bg:Hide() else f.bg:Show() end

  local shown, pull = ns.KeyQueue(3)
  if #shown == 0 then
    f.pullTag:Hide()
    if locked then f:Hide() return end
    f:Show()
    for i = 1, 3 do f.icons[i]:SetTexture(QUESTION_MARK) end
    f.label:SetText("Tactara key: no steps yet (drag to move, /tac lock)")
    return
  end

  f:Show()
  if pull then f.pullTag:Show() else f.pullTag:Hide() end
  for n = 1, 3 do
    if shown[n] then
      f.icons[n]:SetTexture(SpellIcon(shown[n]))
      f.icons[n]:Show()
    else
      f.icons[n]:Hide()
    end
  end

  if locked then
    f.label:SetText(ns.IsAoEButton(ns.lastClicked) and "Key (AoE)" or "")
  else
    f.label:SetText("Tactara KEY: next presses (drag, /tac lock)")
  end
end
