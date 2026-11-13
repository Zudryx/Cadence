-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: first steps and updates.
--
--   * What's new: after Tactara updates, a window with the changelog of the
--     new version (and any you skipped), once per update, for all your
--     characters. /tac new shows it any time.
--   * Your keys: on a character with no Tactara key, a window with your
--     one-button, AoE and interrupt keys and Remove (the same as on the
--     settings page). Asked before the talent planner question, never in
--     combat. /tac reset keybinds opens it again.

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

-- The window: your three keys and Remove, like the settings page.
local KEY_ROWS = {
  { which = "main", label = "One-button key", tip = "The key that plays your rotation, one step per press." },
  { which = "aoe", label = "AoE key", tip = "A second key that plays the AoE version of your rotation." },
  { which = "interrupt", label = "Interrupt key", tip = "Casts the best interrupt you have." },
}
local keyFrame

local function KeyText(which)
  local label = ns.KeyLabel(which)
  if not label or label == "none" then return "Not set (click)" end
  return label
end

-- Puts each button's key on it (after you pick or remove one).
function W.OnKeysChanged()
  if not keyFrame then return end
  for _, row in ipairs(KEY_ROWS) do
    local b = keyFrame.keys[row.which]
    if b then b:SetText(KeyText(row.which)) end
  end
end

local function Tip(button, title, text)
  button:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 0.82, 0)
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

-- how: "done" (Done, Escape or the close button) or "no" (No thanks)
function W.CloseKeys(how)
  if not keyOpen then return end
  if how == "no" then
    TactaraCharDB.keyAsked = true
    if not HasKey() then
      ns.Print("No key, then. The glow on your bars and the helper popup work without one; "
        .. "|cffffd100/tac reset keybinds|r opens the key setup any time.")
    end
  else
    for _, row in ipairs(KEY_ROWS) do
      if ns.GetTactaraKey(row.which) or ns.GetSettingsKey(row.which) then TactaraCharDB.keyAsked = true end
    end
  end
  -- with no key and no "No thanks", it asks again next time you log in
  Done()   -- first: hiding the window runs OnHide, which then has nothing to do
  if keyFrame and keyFrame:IsShown() then keyFrame:Hide() end
end

local function BuildKeys()
  local ok, f = pcall(CreateFrame, "Frame", "TactaraKeySetup", UIParent, "BasicFrameTemplateWithInset")
  if not ok or not f then f = CreateFrame("Frame", "TactaraKeySetup", UIParent) end
  f:SetSize(440, 290)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, -40)   -- below the "press a key" prompt
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if UISpecialFrames then table.insert(UISpecialFrames, "TactaraKeySetup") end
  f:SetScript("OnHide", function() W.CloseKeys("done") end)   -- Escape or the X
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.title:SetPoint("TOP", f, "TOP", 0, -6)
  f.title:SetText("Tactara keys")

  f.intro = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.intro:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -34)
  f.intro:SetWidth(408)
  f.intro:SetJustifyH("LEFT")
  f.intro:SetText("|cffffd100Tactara|r can put your whole rotation on one key: each press casts the next spell "
    .. "(you still press it every time).\n\nClick a button, then press any key, even one on your action bar. "
    .. "Your keybinds aren't changed. Right-click a button to clear that key.")

  local HOW = "\n\nClick, then press any key (even one on your action bar). Right-click to clear it. "
    .. "Tactara takes the key over while it's loaded; your keybinds aren't changed."
  f.keys = {}
  local y = -128
  local function Row(label, buttonText, tip)
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", f, "TOPLEFT", 24, y - 4)
    fs:SetText(label)
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(200, 22)
    b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, y)
    b:SetText(buttonText)
    Tip(b, label, tip)
    y = y - 28
    return b
  end
  for _, row in ipairs(KEY_ROWS) do
    local which = row.which
    local b = Row(row.label, KeyText(which), row.tip .. HOW)
    if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    b:SetScript("OnClick", function(_, mouse)
      if mouse == "RightButton" then
        ns.Unbind(which)
      else
        ns.afterKeyCapture = W.OnKeysChanged
        ns.StartKeyCapture(which)
      end
      W.OnKeysChanged()
    end)
    f.keys[which] = b
  end
  f.remove = Row("Give keys back", "Remove", "Removes all Tactara keys. Each key goes back to what it did before.")
  f.remove:SetScript("OnClick", function()
    ns.Unbind("all")
    W.OnKeysChanged()
  end)

  f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 40)
  f.hint:SetText("|cffffd100/tac reset keybinds|r opens this again. The settings page has the same keys.")

  f.no = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.no:SetSize(110, 22)
  f.no:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)
  f.no:SetText("No thanks")
  Tip(f.no, "No thanks", "Don't ask again on this character. /tac reset keybinds opens this any time.")
  f.no:SetScript("OnClick", function() W.CloseKeys("no") end)

  f.done = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.done:SetSize(110, 22)
  f.done:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
  f.done:SetText("Done")
  Tip(f.done, "Done", "Close this. With no key set, Tactara asks again next time you log in.")
  f.done:SetScript("OnClick", function() W.CloseKeys("done") end)
  return f
end

function W.ShowKeys()
  keyFrame = keyFrame or BuildKeys()
  W.keyFrame = keyFrame
  keyOpen = true
  W.OnKeysChanged()
  keyFrame:Show()
  return keyFrame
end

-- Asked once per character that has no Tactara key, unless first-time
-- questions are turned off for all your characters.
function W.AskKey()
  if TactaraDB.welcomeOff or TactaraCharDB.keyAsked or HasKey() then return false end
  if InCombatLockdown() then keyWaiting = true return false end
  keyWaiting = false
  W.ShowKeys()
  return true
end

-- /tac reset keybinds: the window again, whatever you answered before.
-- Your keys stay until you remove them.
function W.ResetKeys()
  if InCombatLockdown() then
    ns.Print("Set keys out of combat.")
    return false
  end
  TactaraCharDB.keyAsked = nil
  W.ShowKeys()
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
