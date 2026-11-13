-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: first steps and updates.
--
--   * What's new: after Tactara updates, a window with the changelog of the
--     new version (and any you skipped), once per update, for all your
--     characters. /tac new shows it any time.
--   * Your key: on a character with no Tactara key, one question offering to
--     set it up (the same as /tac bind). Asked before the talent planner
--     question, never in combat.

local ADDON, ns = ...

local W = {}
ns.Welcome = W

local MAX_SECTIONS = 3

---------------------------------------------------------------------------
-- Versions
---------------------------------------------------------------------------

-- "0.15.0" < "0.16.0" < "0.16.1", by number
function W.Newer(a, b)
  local pa, pb = {}, {}
  for n in tostring(a or ""):gmatch("%d+") do pa[#pa + 1] = tonumber(n) end
  for n in tostring(b or ""):gmatch("%d+") do pb[#pb + 1] = tonumber(n) end
  for i = 1, math.max(#pa, #pb) do
    local x, y = pa[i] or 0, pb[i] or 0
    if x ~= y then return x > y end
  end
  return false
end

-- Changelog sections newer than `since` (all of them when since is nil),
-- newest first, at most MAX_SECTIONS.
function W.SectionsSince(since)
  local out = {}
  for _, s in ipairs(ns.WHATS_NEW or {}) do
    if (not since or W.Newer(s.version, since)) and not W.Newer(s.version, ns.VERSION) then
      out[#out + 1] = s
      if #out >= MAX_SECTIONS then break end
    end
  end
  return out
end

-- The changelog's markdown, as game text: **bold** and `commands` in gold,
-- list dashes as bullets.
function W.Format(line)
  local indent, rest = line:match("^(%s*)%-%s+(.*)$")
  if rest then
    line = (#indent > 0 and "      - " or "• ") .. rest
  end
  line = line:gsub("%*%*(.-)%*%*", "|cffffd100%1|r")
  line = line:gsub("`(.-)`", "|cffffd100%1|r")
  return line
end

function W.Text(sections)
  local parts = {}
  for i, s in ipairs(sections) do
    if i > 1 then parts[#parts + 1] = "" end
    parts[#parts + 1] = "|cff4fc3f7Tactara " .. s.version .. "|r"
    for _, line in ipairs(s.lines) do parts[#parts + 1] = W.Format(line) end
  end
  return table.concat(parts, "\n")
end

---------------------------------------------------------------------------
-- The "what's new" window
---------------------------------------------------------------------------

local frame

local function Build()
  local ok, f = pcall(CreateFrame, "Frame", "TactaraWhatsNew", UIParent, "BasicFrameTemplateWithInset")
  if not ok or not f then f = CreateFrame("Frame", "TactaraWhatsNew", UIParent) end
  f:SetSize(560, 420)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if UISpecialFrames then table.insert(UISpecialFrames, "TactaraWhatsNew") end
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.title:SetPoint("TOP", f, "TOP", 0, -6)

  local okS, scroll = pcall(CreateFrame, "ScrollFrame", "TactaraWhatsNewScroll", f, "UIPanelScrollFrameTemplate")
  if not okS or not scroll then scroll = CreateFrame("ScrollFrame", "TactaraWhatsNewScroll", f) end
  scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -32)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 42)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(500, 10)
  f.body = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.body:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
  f.body:SetWidth(500)
  f.body:SetJustifyH("LEFT")
  if f.body.SetSpacing then f.body:SetSpacing(3) end
  scroll:SetScrollChild(child)
  f.child = child

  f.show = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  f.show:SetSize(24, 24)
  f.show:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)
  f.showLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.showLabel:SetPoint("LEFT", f.show, "RIGHT", 2, 0)
  f.showLabel:SetText("Show this after Tactara updates")
  f.show:SetScript("OnClick", function(self)
    TactaraDB.whatsNewOff = not self:GetChecked() or nil
  end)

  f.ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.ok:SetSize(100, 22)
  f.ok:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
  f.ok:SetText("OK")
  f.ok:SetScript("OnClick", function() f:Hide() end)
  return f
end

-- since: show what changed after this version (nil: the newest sections)
function W.Show(since)
  local sections = W.SectionsSince(since)
  if #sections == 0 then sections = W.SectionsSince(nil) end
  if #sections == 0 then return nil end
  frame = frame or Build()
  frame.title:SetText(("Tactara %s: what's new"):format(ns.VERSION))
  frame.body:SetText(W.Text(sections))
  local h = frame.body.GetStringHeight and frame.body:GetStringHeight() or 300
  frame.child:SetHeight(math.max(10, (tonumber(h) or 300) + 10))
  frame.show:SetChecked(not TactaraDB.whatsNewOff)
  frame:Show()
  W.frame = frame
  return frame
end

local newsWaiting = false

-- At login: once per update for all your characters. A fresh install has
-- nothing to show; neither does a version you've already seen.
function W.CheckWhatsNew()
  local seen = TactaraDB.whatsNewSeen or ns.previousVersion
  if ns.freshInstall or not W.Newer(ns.VERSION, seen or "0") then
    TactaraDB.whatsNewSeen = ns.VERSION
    return false
  end
  if TactaraDB.whatsNewOff then
    TactaraDB.whatsNewSeen = ns.VERSION
    return false
  end
  if InCombatLockdown() then newsWaiting = true return false end
  newsWaiting = false
  TactaraDB.whatsNewSeen = ns.VERSION
  W.Show(seen)
  return true
end

---------------------------------------------------------------------------
-- Setting up your key
---------------------------------------------------------------------------

local keyWaiting, keyOpen = false, false

local function HasKey()
  return (ns.GetTactaraKey("main") or ns.GetSettingsKey("main")) and true or false
end

-- true while the key question (or picking the key) is on screen: the
-- talent planner question waits for it.
function W.Busy()
  if keyOpen then return true end
  local capture = _G.TactaraKeyCapture
  return capture and capture.IsShown and capture:IsShown() and true or false
end

local function Done()
  keyOpen = false
  if W.afterKey then
    local fn = W.afterKey
    W.afterKey = nil
    if C_Timer and C_Timer.After then C_Timer.After(1, fn) else fn() end
  end
end

-- Asked once per character that has no Tactara key, unless first-time
-- questions are turned off for all your characters.
function W.AskKey()
  if TactaraDB.welcomeOff or TactaraCharDB.keyAsked or HasKey() then return false end
  if InCombatLockdown() then keyWaiting = true return false end
  keyWaiting = false
  if not (StaticPopupDialogs and StaticPopup_Show) then return false end
  StaticPopupDialogs.TACTARA_KEY = {
    text = "%s", button1 = "Pick a key", button2 = "Later", button3 = "No thanks",
    OnAccept = function()
      TactaraCharDB.keyAsked = true
      ns.afterKeyCapture = Done
      ns.StartKeyCapture("main")
    end,
    OnCancel = function() Done() end,
    OnAlt = function()
      TactaraCharDB.keyAsked = true
      ns.Print("No key, then. The glow on your bars and the helper popup work without one; |cffffd100/tac bind|r sets it up any time.")
      Done()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
  keyOpen = true
  StaticPopup_Show("TACTARA_KEY", "|cffffd100Tactara|r can put your whole rotation on one key: each press casts the next spell "
    .. "(you still press it every time).\n\nPick that key now? Any key works, even one on your action bar. "
    .. "Your keybinds aren't changed, and |cffffd100/tac unbind|r gives the key back.")
  return true
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local ev = CreateFrame("Frame")
W.frameEvents = ev
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end

function W.HandleEvent(event)
  if event == "PLAYER_LOGIN" then
    if C_Timer and C_Timer.After then
      C_Timer.After(5, W.CheckWhatsNew)
      C_Timer.After(6, W.AskKey)
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if newsWaiting then W.CheckWhatsNew() end
    if keyWaiting then W.AskKey() end
  end
end

ev:SetScript("OnEvent", function(_, event) W.HandleEvent(event) end)
