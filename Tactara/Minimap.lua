-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: minimap button.
-- A round button on the edge of the minimap: left-click opens the rotation
-- editor, right-click the settings page, drag it to move it around the edge.
-- Shown or hidden with /tac minimap or the settings page. The entry in the
-- minimap's addon menu (Core.lua) uses the same click and tooltip.

local ADDON, ns = ...

local ICON = "Interface\\AddOns\\Tactara\\Media\\Icon"
local DEFAULT_ANGLE = 225   -- degrees, 0 = right, 90 = top: lower left
local button

---------------------------------------------------------------------------
-- Shared with the addon menu entry
---------------------------------------------------------------------------

function ns.LauncherClick(mouseButton)
  if IsShiftKeyDown and IsShiftKeyDown() then
    ns.TalentPlanner.Toggle()
  elseif mouseButton == "RightButton" then
    ns.Options.Open()
  else
    ns.Editor.Toggle()
  end
end

function ns.LauncherTooltip(owner, anchor)
  local tip = GameTooltip
  if not tip then return end
  tip:SetOwner(owner or UIParent, anchor or "ANCHOR_LEFT")
  tip:AddLine("Tactara " .. ns.VERSION)
  tip:AddLine(ns.activeName or "No rotation yet", 1, 1, 1)
  tip:AddLine("Left-click: rotation editor", 0.6, 0.8, 1)
  tip:AddLine("Right-click: settings", 0.6, 0.8, 1)
  tip:AddLine("Shift-click: talent planner", 0.6, 0.8, 1)
  if owner and owner == button then
    tip:AddLine("Drag: move it around the minimap", 0.6, 0.8, 1)
  end
  tip:Show()
end

---------------------------------------------------------------------------
-- Where the button sits
---------------------------------------------------------------------------

-- Which quarters of the minimap are round, per GetMinimapShape(). Quarters:
-- 1 = lower right, 2 = lower left, 3 = upper right, 4 = upper left.
-- Square quarters (some UI addons) push the button out to the corner.
local SHAPES = {
  ["ROUND"]                 = { true, true, true, true },
  ["SQUARE"]                = { false, false, false, false },
  ["CORNER-TOPLEFT"]        = { false, false, false, true },
  ["CORNER-TOPRIGHT"]       = { false, false, true, false },
  ["CORNER-BOTTOMLEFT"]     = { false, true, false, false },
  ["CORNER-BOTTOMRIGHT"]    = { true, false, false, false },
  ["SIDE-LEFT"]             = { false, true, false, true },
  ["SIDE-RIGHT"]            = { true, false, true, false },
  ["SIDE-TOP"]              = { false, false, true, true },
  ["SIDE-BOTTOM"]           = { true, true, false, false },
  ["TRICORNER-TOPLEFT"]     = { false, true, true, true },
  ["TRICORNER-TOPRIGHT"]    = { true, false, true, true },
  ["TRICORNER-BOTTOMLEFT"]  = { true, true, false, true },
  ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

-- Offset from the minimap's center for a button at this angle.
function ns.MinimapButtonOffset(angle, shape, width, height)
  local r = math.rad(angle or DEFAULT_ANGLE)
  local x, y = math.cos(r), math.sin(r)
  local q = 1
  if x < 0 then q = q + 1 end
  if y > 0 then q = q + 2 end
  local rw, rh = width / 2 + 5, height / 2 + 5
  local quarters = SHAPES[shape or "ROUND"] or SHAPES.ROUND
  if quarters[q] then
    return x * rw, y * rh
  end
  local dw, dh = math.sqrt(2 * rw * rw) - 10, math.sqrt(2 * rh * rh) - 10
  return math.max(-rw, math.min(x * dw, rw)), math.max(-rh, math.min(y * dh, rh))
end

local function Place()
  if not button then return end
  local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
  local x, y = ns.MinimapButtonOffset(TactaraCharDB.minimapAngle, shape, Minimap:GetWidth(), Minimap:GetHeight())
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local atan2 = math.atan2 or math.atan

-- While dragging: the angle from the minimap's center to the cursor.
local function FollowCursor()
  local mx, my = Minimap:GetCenter()
  if not mx then return end
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale() or 1
  px, py = px / scale, py / scale
  TactaraCharDB.minimapAngle = math.floor(math.deg(atan2(py - my, px - mx)) % 360 + 0.5) % 360
  Place()
end

---------------------------------------------------------------------------
-- The button
---------------------------------------------------------------------------

function ns.CreateMinimapButton()
  if button or not Minimap then return button end
  local b = CreateFrame("Button", "TactaraMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
  b:RegisterForClicks("AnyUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(24, 24)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetPoint("CENTER")

  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(18, 18)
  icon:SetTexture(ICON)
  icon:SetPoint("CENTER")
  -- round off the square icon so it sits inside the ring
  local mask = b.CreateMaskTexture and b:CreateMaskTexture()
  if mask and icon.AddMaskTexture then
    mask:SetAllPoints(icon)
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    icon:AddMaskTexture(mask)
  end
  b.icon = icon

  local ring = b:CreateTexture(nil, "OVERLAY")
  ring:SetSize(50, 50)
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  ring:SetPoint("TOPLEFT")

  b:SetScript("OnClick", function(_, mouseButton) ns.LauncherClick(mouseButton) end)
  b:SetScript("OnEnter", function(self)
    if not self.dragging then ns.LauncherTooltip(self, "ANCHOR_LEFT") end
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  -- pressed look
  b:SetScript("OnMouseDown", function(self) self.icon:ClearAllPoints(); self.icon:SetPoint("CENTER", 1, -1) end)
  b:SetScript("OnMouseUp", function(self) self.icon:ClearAllPoints(); self.icon:SetPoint("CENTER") end)
  b:SetScript("OnDragStart", function(self)
    self.dragging = true
    if GameTooltip then GameTooltip:Hide() end
    self:LockHighlight()
    self:SetScript("OnUpdate", FollowCursor)
  end)
  b:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    self.dragging = false
    self:UnlockHighlight()
    self.icon:ClearAllPoints(); self.icon:SetPoint("CENTER")
  end)

  button = b
  ns.minimapButton = b
  -- the minimap can be resized (Edit Mode) or reshaped by UI addons
  pcall(function() Minimap:HookScript("OnSizeChanged", Place) end)
  return b
end

function ns.UpdateMinimapButton()
  local b = ns.CreateMinimapButton()
  if not b then return end
  if TactaraCharDB.minimapButton == false then
    b:Hide()
    return
  end
  Place()
  b:Show()
end

function ns.ResetMinimapButton()
  TactaraCharDB.minimapAngle = DEFAULT_ANGLE
  TactaraCharDB.minimapButton = true
  ns.UpdateMinimapButton()
end
