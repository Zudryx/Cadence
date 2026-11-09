-- Tactara: the helper popup.
-- Big icon = best skill to use right now (from the rotation's [priority]
-- list), two smaller icons = what comes after. To the right, an interrupt
-- slot (red) and a defensive slot (orange) appear only when needed. Each
-- icon shows the key it's bound to on your action bars.

local ADDON, ns = ...

local BIG, SMALL, UTIL = 48, 30, 36
local popup

local function Hotkey(spell)
  if not spell then return "" end
  local ok, text = pcall(function()
    for _, btn in ipairs((ns.ButtonsForSpell(spell))) do
      local hk = btn.HotKey or (btn.GetName and btn:GetName() and _G[btn:GetName() .. "HotKey"])
      local t = hk and hk.GetText and hk:GetText()
      if t and t ~= "" and t ~= RANGE_INDICATOR then return t end
    end
    return ""
  end)
  return ok and text or ""
end

---------------------------------------------------------------------------
-- Cooldown sweep and tints, like the default action bars: red = out of
-- range, blue = waiting on mana/rage/energy, grey = can't be used right now.
-- Anything the game hides (boss fights, arenas) leaves the icon plain.
---------------------------------------------------------------------------

local TINTS = {
  none = { 1, 1, 1 },
  range = { 0.85, 0.15, 0.15 },
  power = { 0.45, 0.45, 1 },
  unusable = { 0.4, 0.4, 0.4 },
}

-- start, duration of a real cooldown (not the global cooldown); 0, 0 when
-- it's ready; nil when the game won't say.
function ns.IconCooldown(spell)
  if not (C_Spell and C_Spell.GetSpellCooldown) then return nil end
  local ok, start, dur = pcall(function()
    local cd = C_Spell.GetSpellCooldown(spell)
    if type(cd) ~= "table" or cd.isOnGCD then return 0, 0 end
    local st, du = (cd.startTime or 0) + 0, (cd.duration or 0) + 0   -- errors if hidden
    if du <= 1.5 or st <= 0 or st + du <= GetTime() then return 0, 0 end
    return st, du
  end)
  if ok then return start, dur end
  return nil
end

-- true / false, or nil when there's no target or the game won't say
function ns.IconInRange(spell)
  if not (C_Spell and C_Spell.IsSpellInRange) then return nil end
  local ok, r = pcall(function()
    if not UnitExists("target") then return nil end
    local v = C_Spell.IsSpellInRange(spell, "target")
    if v == nil then return nil end
    return v and true or false                    -- errors if hidden
  end)
  if ok then return r end
  return nil
end

-- which tint an icon gets: "none", "range", "power" or "unusable"
function ns.IconTint(spell)
  if TactaraCharDB.helperTint == false then return "none" end
  local state = ns.UsableState(spell)
  if state == "no" then return "unusable" end
  if state == "power" then return "power" end
  if ns.IconInRange(spell) == false then return "range" end
  return "none"
end

local function UpdateIconState(holder, spell)
  -- tint
  local tint = spell and ns.IconTint(spell) or "none"
  if holder.tint ~= tint then
    holder.tint = tint
    local c = TINTS[tint]
    holder.tex:SetVertexColor(c[1], c[2], c[3])
    if tint == "range" then holder.key:SetTextColor(1, 0.2, 0.2) else holder.key:SetTextColor(1, 1, 1) end
  end
  -- cooldown sweep
  local cd = holder.cd
  if not cd then return end
  local start, dur = 0, 0
  if spell and TactaraCharDB.helperCooldowns ~= false then
    start, dur = ns.IconCooldown(spell)
    start, dur = start or 0, dur or 0
  end
  if start ~= holder.cdStart or dur ~= holder.cdDur then
    holder.cdStart, holder.cdDur = start, dur
    if dur > 0 then
      cd:SetCooldown(start, dur)
      cd:Show()
    elseif cd.Clear then
      cd:Clear()
    else
      cd:SetCooldown(0, 0)
    end
  end
end
ns.UpdateIconState = UpdateIconState

local function MakeIcon(parent, size, color)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(size, size)
  holder.tex = holder:CreateTexture(nil, "ARTWORK")
  holder.tex:SetAllPoints()
  holder.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  -- the sweep sits over the icon; key text and labels sit over the sweep
  local okCD, cd = pcall(CreateFrame, "Cooldown", nil, holder, "CooldownFrameTemplate")
  if okCD and cd then
    cd:SetAllPoints(holder.tex)
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(size < 40) end
    holder.cd = cd
  end
  holder.over = CreateFrame("Frame", nil, holder)
  holder.over:SetAllPoints()
  if holder.over.SetFrameLevel and holder.GetFrameLevel then
    holder.over:SetFrameLevel((holder:GetFrameLevel() or 1) + 3)
  end
  holder.key = holder.over:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  holder.key:SetPoint("TOPRIGHT", -2, -2)
  if color then
    holder.border = holder:CreateTexture(nil, "BACKGROUND")
    holder.border:SetPoint("TOPLEFT", -2, 2)
    holder.border:SetPoint("BOTTOMRIGHT", 2, -2)
    holder.border:SetColorTexture(color[1], color[2], color[3], 1)
    holder.tag = holder.over:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    holder.tag:SetPoint("TOP", holder, "BOTTOM", 0, -1)
  end
  return holder
end

local function SetIcon(holder, spell)
  if spell then
    holder.tex:SetTexture(ns.SpellIcon(spell))
    holder.key:SetText(Hotkey(spell))
    holder.spell = spell
    UpdateIconState(holder, spell)
    holder:Show()
  else
    holder.spell = nil
    UpdateIconState(holder, nil)
    holder:Hide()
  end
end

function ns.CreateHelperPopup()
  if popup then return popup end
  local f = CreateFrame("Frame", "TactaraHelperPopup", UIParent)
  f:SetSize(BIG + 2 * (SMALL + 4) + 2 * (UTIL + 8), BIG)
  f:SetFrameStrata("MEDIUM")
  ns.MakeMovable(f, "helperPos", 0, -110)

  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetPoint("TOPLEFT", -4, 4)
  f.bg:SetPoint("BOTTOMRIGHT", 4, -16)
  f.bg:SetColorTexture(0, 0, 0, 0.5)

  f.icons = {}
  f.icons[1] = MakeIcon(f, BIG)
  f.icons[1]:SetPoint("LEFT", f, "LEFT", 0, 0)
  for i = 2, 3 do
    f.icons[i] = MakeIcon(f, SMALL)
    f.icons[i]:SetPoint("BOTTOMLEFT", f.icons[i - 1], "BOTTOMRIGHT", 4, 0)
    f.icons[i]:SetAlpha(0.8)
  end
  f.pullTag = f.icons[1].over:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.pullTag:SetPoint("BOTTOM", 0, 2)
  f.pullTag:SetText("PULL")
  f.pullTag:Hide()

  f.interrupt = MakeIcon(f, UTIL, ns.GLOW_COLORS.interrupt)
  f.interrupt:SetPoint("LEFT", f.icons[3], "RIGHT", 10, 4)
  f.interrupt.tag:SetText("INTERRUPT")
  f.defensive = MakeIcon(f, UTIL, ns.GLOW_COLORS.defensive)
  f.defensive:SetPoint("LEFT", f.interrupt, "RIGHT", 10, 0)
  f.defensive.tag:SetText("DEFENSIVE")

  f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.label:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -2)

  popup = f
  ns.helperPopup = f
  ns.UpdateHelperPopup()
  return f
end

function ns.UpdateHelperPopup()
  local f = popup
  if not f then return end
  if not TactaraCharDB.showHelper then
    f:Hide()
    return
  end
  local locked = TactaraCharDB.locked
  f:EnableMouse(not locked)
  if locked then f.bg:Hide() else f.bg:Show() end

  local shown, pull = ns.HelperQueue(3, true, "priority")
  local util = ns.lastUtility or {}

  if #shown == 0 then
    if locked then f:Hide() return end
    f:Show()
    SetIcon(f.icons[1], nil); SetIcon(f.icons[2], nil); SetIcon(f.icons[3], nil)
    SetIcon(f.interrupt, nil); SetIcon(f.defensive, nil)
    f.label:SetText("Tactara helper: no rotation yet (drag to move, /tac lock)")
    return
  end

  f:Show()
  -- not fighting: normal, see-through or hidden (settings page)
  if not ns.ApplyIdleLook(f, TactaraCharDB.helperIdle) then return end
  for i = 1, 3 do SetIcon(f.icons[i], shown[i]) end
  if pull then f.pullTag:Show() else f.pullTag:Hide() end
  SetIcon(f.interrupt, util.interrupt)
  SetIcon(f.defensive, util.defensive)

  if locked then
    f.label:SetText("")
  else
    f.label:SetText("Tactara HELPER: best skill now (drag, /tac lock)")
  end
end
