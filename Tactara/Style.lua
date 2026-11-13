-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: the look shared by its own displays and windows.
-- Menus and windows stay Blizzard's (they fit in, and UI packs restyle
-- them); this only adds Tactara's accent, the cyan of its logo ring, and a
-- few touches: icon frames on the helper popup and key bar, the logo in
-- window titles, and the "Display look" setting (standard or minimal).

local ADDON, ns = ...

local S = {}
ns.Style = S

S.BRAND = { 0.31, 0.76, 0.97 }      -- the logo's cyan ring (#4fc3f7), also the chat prefix
S.BRAND_HEX = "4fc3f7"
S.DARK = { 0, 0, 0 }                -- thin frame around every other icon
S.ICON = "Interface\\AddOns\\Tactara\\Media\\Icon"

-- "Tactara" (or any text) in the accent color.
function S.Brand(text)
  return "|cff" .. S.BRAND_HEX .. tostring(text) .. "|r"
end

-- standard: framed icons with captions. minimal: just icons (the interrupt
-- and defensive slots keep a thin colored edge so you can tell them apart).
S.LOOKS = { standard = true, minimal = true }

function S.Look()
  local v = TactaraCharDB and TactaraCharDB.displayStyle
  return S.LOOKS[v] and v or "standard"
end

function S.Minimal() return S.Look() == "minimal" end

---------------------------------------------------------------------------
-- A frame of four edges just outside `anchor` (a texture or a frame),
-- drawn on `parent`. Outside, so it never covers the spell's icon.
---------------------------------------------------------------------------

local Edges = {}
Edges.__index = Edges

function S.Edges(parent, anchor)
  local e = setmetatable({ parent = parent, anchor = anchor, parts = {}, thickness = 0, shown = true }, Edges)
  for i = 1, 4 do e.parts[i] = parent:CreateTexture(nil, "BORDER") end
  return e
end

-- thickness 0 hides it; color = { r, g, b }, alpha optional
function Edges:Set(thickness, color, alpha)
  self.thickness, self.color, self.alpha = thickness or 0, color, alpha or 1
  local a, t = self.anchor, self.thickness
  local top, bottom, left, right = self.parts[1], self.parts[2], self.parts[3], self.parts[4]
  if t > 0 then
    top:ClearAllPoints()
    top:SetPoint("BOTTOMLEFT", a, "TOPLEFT", -t, 0)
    top:SetPoint("BOTTOMRIGHT", a, "TOPRIGHT", t, 0)
    top:SetHeight(t)
    bottom:ClearAllPoints()
    bottom:SetPoint("TOPLEFT", a, "BOTTOMLEFT", -t, 0)
    bottom:SetPoint("TOPRIGHT", a, "BOTTOMRIGHT", t, 0)
    bottom:SetHeight(t)
    left:ClearAllPoints()
    left:SetPoint("TOPRIGHT", a, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMRIGHT", a, "BOTTOMLEFT", 0, 0)
    left:SetWidth(t)
    right:ClearAllPoints()
    right:SetPoint("TOPLEFT", a, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMLEFT", a, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(t)
    local c = color or S.DARK
    for _, p in ipairs(self.parts) do p:SetColorTexture(c[1], c[2], c[3], self.alpha) end
  end
  self:Show(self.shown)
end

-- Shown only while its icon is and it has a thickness.
function Edges:Show(show)
  self.shown = show and true or false
  local on = self.shown and self.thickness > 0
  for _, p in ipairs(self.parts) do
    if on then p:Show() else p:Hide() end
  end
end

function Edges:IsShown()
  return self.shown and self.thickness > 0
end

---------------------------------------------------------------------------
-- Small text that reads over any background: outlined, in a color.
---------------------------------------------------------------------------

function S.Caption(fs, color)
  pcall(function()
    local font, size = fs:GetFont()
    if font then fs:SetFont(font, size, "OUTLINE") end
  end)
  if color then fs:SetTextColor(color[1], color[2], color[3]) end
  fs.captionColor = color
end

---------------------------------------------------------------------------
-- The logo just left of a window's title.
---------------------------------------------------------------------------

function S.TitleIcon(frame, title)
  if not (frame and title) or frame.tactaraLogo then return frame and frame.tactaraLogo end
  local t = frame:CreateTexture(nil, "OVERLAY")
  t:SetSize(16, 16)
  t:SetTexture(S.ICON)
  t:SetPoint("RIGHT", title, "LEFT", -4, 0)
  frame.tactaraLogo = t
  return t
end

-- "Tactara ..." window titles with the name in the accent color and the logo.
function S.Title(frame, title, text)
  title:SetText((text:gsub("^Tactara", S.Brand("Tactara"))))
  S.TitleIcon(frame, title)
end
