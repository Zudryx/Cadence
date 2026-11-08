-- Cadence: the helper popup.
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

local function MakeIcon(parent, size, color)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(size, size)
  holder.tex = holder:CreateTexture(nil, "ARTWORK")
  holder.tex:SetAllPoints()
  holder.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  holder.key = holder:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  holder.key:SetPoint("TOPRIGHT", -2, -2)
  if color then
    holder.border = holder:CreateTexture(nil, "BACKGROUND")
    holder.border:SetPoint("TOPLEFT", -2, 2)
    holder.border:SetPoint("BOTTOMRIGHT", 2, -2)
    holder.border:SetColorTexture(color[1], color[2], color[3], 1)
    holder.tag = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    holder.tag:SetPoint("TOP", holder, "BOTTOM", 0, -1)
  end
  return holder
end

local function SetIcon(holder, spell)
  if spell then
    holder.tex:SetTexture(ns.SpellIcon(spell))
    holder.key:SetText(Hotkey(spell))
    holder:Show()
  else
    holder:Hide()
  end
end

function ns.CreateHelperPopup()
  if popup then return popup end
  local f = CreateFrame("Frame", "CadenceHelperPopup", UIParent)
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
  f.pullTag = f.icons[1]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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
  if not CadenceCharDB.showHelper then
    f:Hide()
    return
  end
  local locked = CadenceCharDB.locked
  f:EnableMouse(not locked)
  if locked then f.bg:Hide() else f.bg:Show() end

  local inCombat = InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player"))
  local shown, pull = ns.HelperQueue(3, true, "priority")
  local util = ns.lastUtility or {}

  if #shown == 0 then
    if locked then f:Hide() return end
    f:Show()
    SetIcon(f.icons[1], nil); SetIcon(f.icons[2], nil); SetIcon(f.icons[3], nil)
    SetIcon(f.interrupt, nil); SetIcon(f.defensive, nil)
    f.label:SetText("Cadence helper: no rotation yet (drag to move, /cad lock)")
    return
  end

  f:Show()
  -- idle out of combat with nothing targeted: dim it
  local okT, hostile = pcall(function() return UnitExists("target") and UnitCanAttack("player", "target") end)
  local idle = not inCombat and not (okT and hostile)
  f:SetAlpha(idle and 0.45 or 1)
  for i = 1, 3 do SetIcon(f.icons[i], shown[i]) end
  if pull then f.pullTag:Show() else f.pullTag:Hide() end
  SetIcon(f.interrupt, util.interrupt)
  SetIcon(f.defensive, util.defensive)

  if locked then
    f.label:SetText("")
  else
    f.label:SetText("Cadence HELPER: best skill now (drag, /cad lock)")
  end
end
