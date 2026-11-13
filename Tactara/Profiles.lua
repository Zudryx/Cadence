-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: the same settings on all your characters.
--
-- Settings live per character, and WoW only loads the character you're
-- playing. So each character also keeps a copy of its settings in Tactara's
-- account-wide storage (TactaraDB.characters), and any character can copy
-- them from there. You can also save a default that every new character
-- starts with.
--
-- Copied: keys, display positions and sizes, how they look, the glow,
-- suggestions, the minimap button and the talent options. Not copied:
-- anything about one character's class or specs (its rotation choice and
-- talent builds).

local ADDON, ns = ...
local Pr = {}
ns.Profiles = Pr

Pr.KEYS = {
  "binds", "keyDown",
  "display", "helperPos", "displayScale", "helperScale", "showHelper", "showDisplay", "locked",
  "helperIdle", "keyIdle", "fadeAlpha", "displayStyle", "keyIcons", "helperIcons", "helperCooldowns", "helperTint",
  "highlight", "helperMode", "interrupts", "defensives", "interruptSound", "defensiveSound",
  "minimapButton", "minimapAngle",
  "talentAutoLearn", "talentGlow", "talentReminders", "talentButton", "trainerReminder", "prePull", "buffSound", "buffLow", "supplies", "ammoLow", "shardLow", "hideMounted",
}

local function Copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = Copy(x) end
  return t
end

function Pr.Snapshot()
  local t = {}
  for _, k in ipairs(Pr.KEYS) do t[k] = Copy(TactaraCharDB[k]) end
  return t
end

function Pr.CharKey()
  local name = UnitName and UnitName("player") or "?"
  local realm = GetRealmName and GetRealmName() or ""
  return (realm ~= "" and (name .. " - " .. realm)) or name
end

-- Keep this character's settings where your other characters can see them.
function Pr.Save()
  if not (TactaraDB and TactaraCharDB) then return end
  TactaraDB.characters = TactaraDB.characters or {}
  local _, class = UnitClass("player")
  TactaraDB.characters[Pr.CharKey()] = {
    class = class, level = UnitLevel and UnitLevel("player") or nil,
    saved = time and time() or 0, settings = Pr.Snapshot(),
  }
end

-- Put settings in place and redraw everything they touch.
function Pr.Apply(settings)
  for _, k in ipairs(Pr.KEYS) do
    if settings[k] ~= nil then TactaraCharDB[k] = Copy(settings[k]) end
  end
  for _, f in ipairs({ ns.display, ns.helperPopup }) do
    if f and f.posKey then
      f:SetScale(tonumber(TactaraCharDB[f.posKey == "display" and "displayScale" or "helperScale"]) or 1)
      ns.RestorePosition(f)
    end
  end
  if ns.ApplyBindings then ns.ApplyBindings() end
  if ns.SyncKeyDown then pcall(ns.SyncKeyDown) end
  if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
  if ns.Talents and ns.Talents.UpdateWindowButton then ns.Talents.UpdateWindowButton() end
  if ns.Options and ns.Options.OnKeysChanged then ns.Options.OnKeysChanged() end
  if ns.HelperRefresh then ns.HelperRefresh() end
end

-- Your other characters, most recently played first.
function Pr.Others()
  local me, list = Pr.CharKey(), {}
  for key, c in pairs(TactaraDB.characters or {}) do
    if key ~= me and c.settings then list[#list + 1] = { key = key, class = c.class, level = c.level, saved = c.saved or 0 } end
  end
  table.sort(list, function(a, b) return a.saved > b.saved end)
  return list
end

function Pr.CopyFrom(key)
  local c = TactaraDB.characters and TactaraDB.characters[key]
  if not (c and c.settings) then return false end
  Pr.Apply(c.settings)
  Pr.Save()
  ns.Print(("Copied Tactara settings from %s: keys, displays, the glow, suggestions, minimap button and talent options. Rotation and talent builds stay this character's own."):format(key))
  return true
end

function Pr.SaveDefault()
  TactaraDB.defaultSettings = Pr.Snapshot()
  ns.Print("Saved. New characters start with these Tactara settings (keys, displays, glow, suggestions, minimap, talent options).")
end

function Pr.ClearDefault()
  TactaraDB.defaultSettings = nil
  ns.Print("New characters start with Tactara's normal settings again.")
end

-- Called while loading, before anything is drawn, for a character Tactara hasn't seen.
function Pr.StartFromDefault()
  local d = TactaraDB and TactaraDB.defaultSettings
  if not d then return false end
  for _, k in ipairs(Pr.KEYS) do
    if d[k] ~= nil then TactaraCharDB[k] = Copy(d[k]) end
  end
  return true
end

---------------------------------------------------------------------------
-- "Copy settings from..." window
---------------------------------------------------------------------------

local CLASS_NAMES = {
  WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
  SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
}

local chooser

function Pr.ShowCopy()
  if not chooser then
    local ok, f = pcall(CreateFrame, "Frame", "TactaraCopySettings", UIParent, "BasicFrameTemplateWithInset")
    if not ok or not f then f = CreateFrame("Frame", "TactaraCopySettings", UIParent) end
    f:SetSize(340, 380)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if UISpecialFrames then table.insert(UISpecialFrames, "TactaraCopySettings") end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", f, "TOP", 0, -6)
    f.title:SetText("Copy Tactara settings from...")
    ns.Style.TitleIcon(f, f.title)
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.hint:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -32)
    f.hint:SetWidth(308)
    f.hint:SetJustifyH("LEFT")
    f.buttons = {}
    chooser = f
  end
  local f = chooser
  for _, b in ipairs(f.buttons) do b:Hide() end
  local others = Pr.Others()
  if #others == 0 then
    f.hint:SetText("No other characters yet. Each character shows up here after you've played it once with this version of Tactara.")
  else
    f.hint:SetText("Keys, displays, the glow, suggestions, minimap button and talent options. Your rotation and talent builds stay as they are.")
  end
  for i = 1, math.min(#others, 12) do
    local o = others[i]
    local b = f.buttons[i]
    if not b then
      b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
      b:SetSize(308, 22)
      f.buttons[i] = b
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -66 - (i - 1) * 24)
    b:SetText(("%s  |cffaaaaaa%s %s|r"):format(o.key, o.level and ("level " .. o.level) or "", CLASS_NAMES[o.class or ""] or ""))
    b.key = o.key
    b:SetScript("OnClick", function(self)
      Pr.CopyFrom(self.key)
      f:Hide()
    end)
    b:Show()
  end
  f:Show()
  return f
end

local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "PLAYER_LOGIN")
pcall(ev.RegisterEvent, ev, "PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, event)
  Pr.Save()
  if event == "PLAYER_LOGIN" and ns.startedFromDefault then
    ns.Print("New character: started with your default Tactara settings.")
  end
end)
Pr.eventFrame = ev
