-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: core (namespace, saved variables, rotation storage, spell checks, events, slash commands)

local ADDON, ns = ...

ns.VERSION = "0.16.1"
ns.builtin = {}        -- [name] = rotation text shipped with the addon
ns.builtinOrder = {}   -- names in load order
ns.compiled = {}       -- .main / .aoe compiled sequences

local PREFIX = "|cff4fc3f7Tactara|r: "

function ns.Print(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. table.concat(parts, " "))
end

function ns.Debug(...)
  if TactaraDB and TactaraDB.debug then ns.Print("|cff888888[debug]|r", ...) end
end

-- Key binding labels (Esc > Options > Keybindings > AddOns > Tactara)
BINDING_HEADER_TACTARA = "Tactara"
_G["BINDING_NAME_CLICK TactaraMainButton:LeftButton"] = "Main rotation button"
_G["BINDING_NAME_CLICK TactaraAoEButton:LeftButton"] = "AoE rotation button"
_G["BINDING_NAME_CLICK TactaraInterruptButton:LeftButton"] = "Interrupt (best for your stance/gear)"

---------------------------------------------------------------------------
-- Rotation storage
---------------------------------------------------------------------------

function ns.RegisterBuiltin(text)
  local rot = ns.Parse(text)
  if not rot or not rot.name then error("Tactara: built-in rotation is missing a name: line") end
  if not ns.builtin[rot.name] then table.insert(ns.builtinOrder, rot.name) end
  ns.builtin[rot.name] = text
end

local function Saved()
  return (TactaraDB and TactaraDB.rotations) or {}
end

function ns.GetRotationText(name)
  if not name then return nil end
  return Saved()[name] or ns.builtin[name]
end

function ns.IsBuiltin(name) return name ~= nil and ns.builtin[name] ~= nil end
function ns.IsEdited(name) return ns.IsBuiltin(name) and Saved()[name] ~= nil end

-- Save rotation text under its "name:" line. Returns ok, nameOrError.
function ns.SaveRotation(text)
  local rot, err = ns.Parse(text)
  if not rot then return false, err end
  if not rot.name then return false, "Add a 'name:' line so the rotation can be saved." end
  if ns.builtin[rot.name] == text then
    TactaraDB.rotations[rot.name] = nil        -- identical to built-in: nothing to store
  else
    TactaraDB.rotations[rot.name] = text
  end
  return true, rot.name
end

-- Deletes a custom rotation, or reverts an edited built-in to the shipped version.
function ns.DeleteRotation(name)
  if not name or not TactaraDB then return end
  TactaraDB.rotations[name] = nil
  if TactaraCharDB and TactaraCharDB.active == name and not ns.IsBuiltin(name) then
    TactaraCharDB.active = "auto"
  end
end

-- Rotations usable by a class, built-ins first, then your own (alphabetical).
function ns.ListRotations(classToken)
  local seen, out = {}, {}
  local function add(name)
    if seen[name] then return end
    seen[name] = true
    local rot = ns.Parse(ns.GetRotationText(name))
    if not rot then return end
    local cls = rot.meta.class
    if classToken and cls and cls ~= "" and cls ~= "ANY" and cls ~= classToken then return end
    out[#out + 1] = {
      name = name, class = cls, detect = rot.meta.detect, default = rot.isDefault,
      tree = rot.meta.tree, weapon = rot.meta.weapon, prefer = rot.meta.prefer,
      builtin = ns.IsBuiltin(name), edited = ns.IsEdited(name),
    }
  end
  for _, n in ipairs(ns.builtinOrder) do add(n) end
  local custom = {}
  for n in pairs(Saved()) do
    if not ns.builtin[n] then custom[#custom + 1] = n end
  end
  table.sort(custom)
  for _, n in ipairs(custom) do add(n) end
  return out
end

-- Case-insensitive lookup: exact name first, then partial match.
function ns.FindRotation(query, classToken)
  if not query or query == "" then return nil end
  local q = query:lower()
  local list = ns.ListRotations(classToken)
  for _, r in ipairs(list) do if r.name:lower() == q then return r.name end end
  for _, r in ipairs(list) do if r.name:lower():find(q, 1, true) then return r.name end end
  return nil
end

function ns.GetClassToken()
  local _, token = UnitClass("player")
  return token
end

---------------------------------------------------------------------------
-- Spell / buff checks (only used out of combat, when building sequences)
---------------------------------------------------------------------------

local knownCache = {}

function ns.ClearKnownCache()
  for k in pairs(knownCache) do knownCache[k] = nil end
end

local function CleanName(name)
  name = name:gsub("^!", "")
  name = name:gsub("%s*%(.-%)%s*$", "")
  return name
end

local function SpellIDFromName(name)
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, name)
    if ok and type(info) == "table" then return info.spellID end
  end
  if GetSpellInfo then
    local ok, _, _, _, _, _, _, id = pcall(GetSpellInfo, name)
    if ok then return id end
  end
  return nil
end

function ns.IsKnown(name)
  if type(name) ~= "string" or name == "" then return false end
  local cached = knownCache[name]
  if cached ~= nil then return cached end

  local clean = CleanName(name)
  local known = false

  -- Modern spellbook API
  if C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell then
    local ok, slot, bank = pcall(C_SpellBook.FindSpellBookSlotForSpell, clean, false, true, false, false)
    if ok and slot then
      known = true
      if C_SpellBook.GetSpellBookItemInfo and Enum and Enum.SpellBookItemType then
        local ok2, info = pcall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
        if ok2 and type(info) == "table" and info.itemType == Enum.SpellBookItemType.FutureSpell then
          known = false
        end
      end
    end
  end

  -- Fallbacks by spell ID
  if not known then
    local id = SpellIDFromName(clean)
    if id then
      if IsPlayerSpell then
        local ok, r = pcall(IsPlayerSpell, id)
        if ok and r then known = true end
      end
      if not known and C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, r = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and r then known = true end
      end
      if not known and IsSpellKnown then
        local ok, r = pcall(IsSpellKnown, id)
        if ok and r then known = true end
      end
      if not known and IsSpellKnown then   -- pet abilities (Spell Lock, Growl, ...)
        local ok, r = pcall(IsSpellKnown, id, true)
        if ok and r then known = true end
      end
    end
  end

  knownCache[name] = known
  return known
end

ns.BUFF_REFRESH_SECONDS = 30

-- Spells on your stance bar: Paladin auras (Forever's "Aura" bar), Warrior
-- stances, Druid forms, Shadowform... The game tells addons which one is on
-- even when it hides your buffs, and it's right after a reload too.
-- true = this one is on, false = it's on the bar but not on, nil = not a
-- stance bar spell (or the game won't say).
function ns.FormActive(name)
  if not (name and GetNumShapeshiftForms and GetShapeshiftFormInfo) then return nil end
  local okN, n = pcall(function() return tonumber(GetNumShapeshiftForms()) end)
  if not (okN and n) then return nil end
  local english = ns.Locale and ns.Locale.English(name) or name
  local wantId = ns.Locale and ns.Locale.IdFor and ns.Locale.IdFor(english)
  for i = 1, n do
    local ok, _, active, _, spellID = pcall(GetShapeshiftFormInfo, i)
    if ok and spellID then
      local okId, id = pcall(function() return tonumber(spellID) end)
      local fname = okId and id and ns.Locale and ns.Locale.NameOf(id)
      local match = (fname and (fname == name or ns.Locale.English(fname) == english)) or (okId and id and id == wantId)
      if match then
        local okA, on = pcall(function() return active and true or false end)
        if okA then return on end
        return nil
      end
    end
  end
  return nil
end

-- true = buff is up with plenty of time left, false = missing/expiring, nil = can't tell.
-- Only called out of combat; if the game hides the value, we treat it as "can't tell".
function ns.HasBuff(name)
  if InCombatLockdown() then return nil end
  local form = ns.FormActive(name)
  if form ~= nil then return form end
  local mine = ns.TrackedRemaining and ns.TrackedRemaining("player", name)
  local ok, aura = false, nil
  if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
    ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
  end
  if ok and aura ~= nil then
    local ok2, longEnough = pcall(function()
      local exp = aura.expirationTime
      if not exp or exp == 0 then return true end
      return (exp - GetTime()) >= ns.BUFF_REFRESH_SECONDS
    end)
    if ok2 then return longEnough and true or false end
  end
  if mine then return mine >= ns.BUFF_REFRESH_SECONDS end   -- our own timer from your cast
  if ok then return false end
  return nil
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------

local function InitDB()
  ns.freshInstall = TactaraDB == nil
  TactaraDB = TactaraDB or {}
  ns.previousVersion = TactaraDB.version   -- the version you last played with
  TactaraDB.rotations = TactaraDB.rotations or {}
  TactaraDB.version = ns.VERSION
  if TactaraDB.hideErrors == nil then TactaraDB.hideErrors = true end
  TactaraDB.glowStyle = TactaraDB.glowStyle or "strong"
  local fresh = TactaraCharDB == nil
  TactaraCharDB = TactaraCharDB or {}
  -- a character Tactara hasn't seen starts from your saved default settings
  ns.startedFromDefault = fresh and ns.Profiles and ns.Profiles.StartFromDefault() or false
  TactaraCharDB.active = TactaraCharDB.active or "auto"
  if TactaraCharDB.showDisplay == nil then TactaraCharDB.showDisplay = true end
  if TactaraCharDB.locked == nil then TactaraCharDB.locked = false end
  if TactaraCharDB.highlight == nil then TactaraCharDB.highlight = true end
  TactaraCharDB.helperMode = TactaraCharDB.helperMode or "auto"
  if TactaraCharDB.showHelper == nil then TactaraCharDB.showHelper = true end
  if TactaraCharDB.interrupts == nil then TactaraCharDB.interrupts = true end
  if TactaraCharDB.defensives == nil then TactaraCharDB.defensives = true end
  TactaraCharDB.display = TactaraCharDB.display or {}
  TactaraCharDB.displayScale = tonumber(TactaraCharDB.displayScale) or 1
  TactaraCharDB.helperScale = tonumber(TactaraCharDB.helperScale) or 1
  if TactaraCharDB.helperCooldowns == nil then TactaraCharDB.helperCooldowns = true end
  if TactaraCharDB.helperTint == nil then TactaraCharDB.helperTint = true end
  local IDLE = { show = true, fade = true, hide = true }
  if not IDLE[TactaraCharDB.helperIdle] then TactaraCharDB.helperIdle = "fade" end
  if not IDLE[TactaraCharDB.keyIdle] then TactaraCharDB.keyIdle = "show" end
  if TactaraCharDB.minimapButton == nil then TactaraCharDB.minimapButton = true end
  if TactaraCharDB.trainerReminder == nil then TactaraCharDB.trainerReminder = true end
  local PREPULL = { both = true, helper = true, off = true }
  if not PREPULL[TactaraCharDB.prePull] then TactaraCharDB.prePull = "both" end
  if not PREPULL[TactaraCharDB.supplies] then TactaraCharDB.supplies = "both" end
  for _, k in ipairs({ "interruptSound", "defensiveSound" }) do
    local v = TactaraCharDB[k]
    if not (v == "off" or (ns.SoundFor and ns.SoundFor(v))) then TactaraCharDB[k] = "off" end
  end
  local ang = tonumber(TactaraCharDB.minimapAngle)
  TactaraCharDB.minimapAngle = ang and (ang % 360) or 225
  for _, k in ipairs({ "keyIcons", "helperIcons" }) do
    local v = tonumber(TactaraCharDB[k])
    TactaraCharDB[k] = (v and v >= 0 and v <= 10) and math.floor(v) or 3
  end
  local fa = tonumber(TactaraCharDB.fadeAlpha)
  TactaraCharDB.fadeAlpha = (fa and fa >= 0.1 and fa <= 0.9) and fa or 0.45
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
ns.eventFrame = events

local function SafeRegister(event, unit)
  if unit and events.RegisterUnitEvent then
    pcall(events.RegisterUnitEvent, events, event, unit)
  else
    pcall(events.RegisterEvent, events, event)
  end
end

SafeRegister("ADDON_LOADED")
SafeRegister("PLAYER_LOGIN")
SafeRegister("PLAYER_REGEN_ENABLED")
SafeRegister("PLAYER_REGEN_DISABLED")
SafeRegister("CVAR_UPDATE")
SafeRegister("UNIT_AURA", "player")
-- only printed with /tac debug on: shows whether presses turn into casts
SafeRegister("UI_ERROR_MESSAGE")
SafeRegister("UNIT_SPELLCAST_SENT", "player")
SafeRegister("UNIT_SPELLCAST_SUCCEEDED", "player")
SafeRegister("UNIT_SPELLCAST_FAILED", "player")
-- anything that can change which spells you know
for _, e in ipairs({
  "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "LEARNED_SPELL_IN_TAB",
  "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED",
  "TRAIT_CONFIG_UPDATED", "UPDATE_SHAPESHIFT_FORMS", "PLAYER_SPECIALIZATION_CHANGED",
  "PLAYER_EQUIPMENT_CHANGED", "TRAIT_CONFIG_LIST_UPDATED",
}) do
  SafeRegister(e)
end
SafeRegister("UNIT_PET", "player")   -- pet abilities (Spell Lock, ...) come and go with the pet

local rebuildQueued = false

function ns.RequestRebuild(reason, delay)
  if not ns.loggedIn then return end
  if InCombatLockdown() then
    ns.rebuildAfterCombat = true
    return
  end
  if rebuildQueued then return end
  rebuildQueued = true
  C_Timer.After(delay or 0.25, function()
    rebuildQueued = false
    ns.Rebuild(reason)
  end)
end

local function SpellNameFromID(id)
  local ok, name = pcall(function()
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
  end)
  return (ok and name) and tostring(name) or tostring(id)
end

local function DebugCombatEvent(event, ...)
  if not (TactaraDB and TactaraDB.debug) then return end
  pcall(function(...)
    if event == "UI_ERROR_MESSAGE" then
      local _, message = ...
      ns.Debug("|cffff5555game error:|r " .. tostring(message))
    elseif event == "UNIT_SPELLCAST_SENT" then
      local _, _, _, spellID = ...
      ns.Debug("|cff00ff00cast sent:|r " .. SpellNameFromID(spellID))
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
      local _, _, spellID = ...
      ns.Debug("|cff00ff00cast succeeded:|r " .. SpellNameFromID(spellID))
    elseif event == "UNIT_SPELLCAST_FAILED" then
      local _, _, spellID = ...
      ns.Debug("|cffffaa00cast failed:|r " .. SpellNameFromID(spellID))
    end
  end, ...)
end

events:SetScript("OnEvent", function(self, event, arg1, ...)
  if event == "UI_ERROR_MESSAGE" or event:find("^UNIT_SPELLCAST") then
    DebugCombatEvent(event, arg1, ...)
    return
  end
  if event == "ADDON_LOADED" then
    if arg1 == ADDON then InitDB() end
    return
  elseif event == "PLAYER_LOGIN" then
    ns.loggedIn = true
    ns.SyncKeyDown()
    ns.ApplyBindings()
    C_Timer.After(2, ns.MigrateOldKeybinds)   -- bindings are fully loaded by then
    ns.CreateDisplay()
    ns.CreateHelperPopup()
    ns.ApplyDisplayScales()
    ns.Options.Register()
    ns.UpdateMinimapButton()
    ns.RequestRebuild("login", 1)
    ns.Print(("v%s loaded. Type |cffffd100/tac|r to open the editor, |cffffd100/tac help|r for commands."):format(ns.VERSION))
    return
  elseif event == "PLAYER_REGEN_ENABLED" then
    ns.OnCombatEnd()
    return
  elseif event == "PLAYER_REGEN_DISABLED" then
    ns.UpdateDisplay()   -- swap the PULL icon for the fight's steps
    return
  elseif event == "CVAR_UPDATE" then
    ns.SyncKeyDown()
    return
  elseif event == "UNIT_AURA" then
    if ns.usesBuffChecks and not InCombatLockdown() then ns.RequestRebuild("aura", 0.5) end
    return
  end
  ns.RequestRebuild(event)
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local HELP = {
  "|cffffd100/tac|r  open the rotation editor   |cffffd100/tac options|r  settings page (also Esc > Options > AddOns)",
  "|cffffd100/tac use <name>|r  use a rotation (e.g. /tac use prot), or |cffffd100/tac use auto|r",
  "|cffffd100/tac list|r  list rotations for your class",
  "|cffffd100/tac bind|r  press a key for the rotation (any key, even one on your bar; your keybinds stay as they are)",
  "|cffffd100/tac bind aoe|r / |cffffd100bind interrupt|r  same for AoE / the interrupt key   |cffffd100/tac unbind|r [aoe / interrupt / all]",
  "|cffffd100/tac highlight|r  glow on the next spell on your action bars (on/off)",
  "|cffffd100/tac talents|r  talent planner (|cffffd100/tac talents learn|r, |cffffd100learn all|r, |cffffd100auto|r)",
  "|cffffd100/tac copy|r [name]  copy keys and display settings from another character",
  "|cffffd100/tac defaults|r  new characters start with this character's settings (|cffffd100/tac defaults clear|r)",
  "|cffffd100/tac minimap|r  show or hide the minimap button (|cffffd100/tac minimap reset|r puts it back)",
  "|cffffd100/tac new|r  what's new in this version of Tactara",
  "|cffffd100/tac export|r / |cffffd100import|r  your settings as text, to back up or share (keys only if you choose)",
  "|cffffd100/tac trainer|r  spells waiting at your class trainer (|cffffd100/tac trainer on|r / |cffffd100off|r: the level-up reminder)",
  "|cffffd100/tac prepull|r on|helper|off  reminders before a fight: missing buffs, pet, poison or weapon imbue",
  "|cffffd100/tac supplies|r  ammo, Soul Shards, reagents or totems running low (|cffffd100on|r / |cffffd100helper|r / |cffffd100off|r: the reminder)",
  "|cffffd100/tac icons|r helper|key 1-10|all  how many icons each display shows",
  "|cffffd100/tac fade|r helper|key show|fade|hide  how the displays look when you're not fighting (|cffffd100/tac fade 40|r = see-through amount)",
  "|cffffd100/tac glow strong / normal / subtle|r  how loud the glow is   |cffffd100/tac glow test|r  3-second preview",
  "|cffffd100/tac helper auto / priority / sequence|r  what the glow follows (auto: priority list, or the key's sequence while you press it)",
  "|cffffd100/tac build|r  your detected talents and weapons, and the rotation they pick",
  "|cffffd100/tac steps|r  print the current compiled sequence",
  "|cffffd100/tac spells|r  which rotation spells you've learned and which are still to come",
  "|cffffd100/tac show|r / |cffffd100hide|r [key / helper]  the key bar and/or the helper popup",
  "|cffffd100/tac lock|r / |cffffd100unlock|r  lock or move both",
  "|cffffd100/tac interrupts|r / |cffffd100defensives|r  red interrupt / orange defensive suggestions on or off",
  "|cffffd100/tac sound|r interrupt|defensive <sound>|on|off  a sound when the slot lights up (|cffffd100/tac sound|r lists the sounds, |cffffd100/tac sound test|r plays them)",
  "|cffffd100/tac reset|r  restart the sequence from the opener",
  "|cffffd100/tac reset keybinds|r (or |cffffd100/tac keys|r)  the key setup window: one-button, AoE and interrupt keys, and Remove",
  "|cffffd100/tac errors|r  show/hide the red 'not ready' error text while pressing (hidden by default)",
  "|cffffd100/tac test|r  print diagnostics (key binding, macros, settings)",
  "|cffffd100/tac probe|r  check what the game lets addons read (run out of combat and in combat)",
  "|cffffd100/tac probe talents|r  report how your talents look to Tactara, in a window you can copy from (changes nothing)",
  "|cffffd100/tac probe locale|r  check Tactara's spell IDs (for games in other languages) against the game (changes nothing)",
  "|cffffd100/tac probe reminders|r  report what Tactara sees for the trainer, before-the-pull and supply reminders (changes nothing)",
  "|cffffd100/tac debug|r  print every press, cast and game error to chat",
  "|cffffd100/tac keydown auto / off|r  troubleshooting: fire on key down (default) or key up",
  "Key bindings: Esc > Options > Keybindings > AddOns > Tactara",
  "Tactara is an assistant: it never presses anything for you. Every cast comes from your own key press.",
}

local function HandleSlash(msg)
  msg = ns.trim(msg or "")
  local cmd, rest = msg:match("^(%S*)%s*(.-)$")
  cmd = (cmd or ""):lower()

  if cmd == "" or cmd == "edit" or cmd == "config" then
    ns.Editor.Toggle()
  elseif cmd == "options" or cmd == "settings" or cmd == "opt" then
    ns.Options.Open()
  elseif cmd == "help" or cmd == "?" then
    for _, l in ipairs(HELP) do ns.Print(l) end
  elseif cmd == "use" then
    if rest:lower() == "auto" or rest == "" then
      TactaraCharDB.active = "auto"
      ns.Print("Auto-pick on: the rotation follows your talents.")
    else
      local name = ns.FindRotation(rest, ns.GetClassToken())
      if not name then
        ns.Print("No rotation matching '" .. rest .. "'. Try /tac list.")
        return
      end
      TactaraCharDB.active = name
    end
    ns.RequestRebuild("use", 0.05)
  elseif cmd == "list" then
    local list = ns.ListRotations(ns.GetClassToken())
    if #list == 0 then ns.Print("No rotations for your class yet. Make one with /tac.") end
    for _, r in ipairs(list) do
      local tag = r.edited and " (edited)" or (r.builtin and "" or " (yours)")
      local mark = (r.name == ns.activeName) and " |cff00ff00< active|r" or ""
      ns.Print("- " .. r.name .. tag .. mark)
    end
    ns.Print("Mode: " .. (TactaraCharDB.active == "auto" and "auto-pick" or "manual"))
  elseif cmd == "bind" then
    ns.StartKeyCapture(rest:lower())
  elseif cmd == "unbind" then
    ns.Unbind(rest:lower())
  elseif cmd == "macro" or cmd == "macros" then
    ns.Print("WoW doesn't let an action-bar macro run Tactara (a macro can't /click another macro). "
      .. "Use |cffffd100/tac bind|r instead: pick any key, even one your action bar uses, and Tactara "
      .. "takes it over without changing your keybinds. You can delete old 'Tactara' macros.")
  elseif cmd == "steps" or cmd == "dump" or cmd == "preview" then
    ns.PrintSequence(ns.compiled.main, "Main button")
    ns.PrintSequence(ns.compiled.aoe, "AoE button", true)
  elseif cmd == "show" or cmd == "hide" then
    local on = (cmd == "show")
    local what = rest:lower()
    if what == "" or what == "key" or what == "bar" or what == "all" or what == "both" then TactaraCharDB.showDisplay = on end
    if what == "" or what == "helper" or what == "popup" or what == "all" or what == "both" then TactaraCharDB.showHelper = on end
    ns.HelperRefresh()
  elseif cmd == "talents" or cmd == "talent" then
    local sub = rest:lower()
    if sub:match("^learn") then
      local learned, why = ns.Talents.Learn(sub:match("all") and "all" or 1)
      if not learned then ns.Print("Couldn't learn: " .. tostring(why)) end
    elseif sub:match("^auto") then
      TactaraCharDB.talentAutoLearn = not TactaraCharDB.talentAutoLearn
      ns.Print("Learning talents when you level up: " .. (TactaraCharDB.talentAutoLearn and "on" or "off (you'll get a reminder instead)"))
    else
      ns.TalentPlanner.Toggle()
    end
  elseif cmd == "minimap" then
    if rest:lower():match("^reset") then
      ns.ResetMinimapButton()
      ns.Print("Minimap button moved back to its starting spot.")
    else
      TactaraCharDB.minimapButton = not TactaraCharDB.minimapButton
      ns.UpdateMinimapButton()
      ns.Print("Minimap button " .. (TactaraCharDB.minimapButton and "on" or "off (the minimap's addon menu still has Tactara)"))
    end
  elseif cmd == "export" or cmd == "share" then
    ns.Share.ShowExport()
  elseif cmd == "import" then
    ns.Share.ShowImport()
  elseif cmd == "new" or cmd == "news" or cmd == "whatsnew" or cmd == "changes" then
    ns.Welcome.Show(nil)
  elseif cmd == "trainer" then
    local v = rest:lower()
    if v == "on" or v == "off" then
      TactaraCharDB.trainerReminder = (v == "on")
      ns.Print("Trainer reminder after a level-up " .. v .. ".")
    else
      ns.Reminders.ShowTrainer()
    end
  elseif cmd == "prepull" or cmd == "pull" then
    local v = rest:lower()
    local MODES = { on = "both", both = "both", chat = "both", helper = "helper", popup = "helper", off = "off" }
    if MODES[v] then
      TactaraCharDB.prePull = MODES[v]
    else
      TactaraCharDB.prePull = (TactaraCharDB.prePull == "off") and "both" or "off"
    end
    ns.Reminders.ResetChatThrottle()
    ns.HelperRefresh()
    local say = { both = "on (under the helper popup and in chat)", helper = "under the helper popup only", off = "off" }
    ns.Print("Before-the-pull reminders " .. say[TactaraCharDB.prePull] .. ".")
  elseif cmd == "supplies" or cmd == "supply" or cmd == "ammo" or cmd == "reagents" then
    local v = rest:lower()
    local MODES = { on = "both", both = "both", chat = "both", helper = "helper", popup = "helper", off = "off" }
    if MODES[v] then
      TactaraCharDB.supplies = MODES[v]
      ns.Reminders.ResetSupplyChat()
      ns.Reminders.MarkSupplies()
      ns.HelperRefresh()
      local say = { both = "on (under the helper popup, in chat and at vendors)", helper = "under the helper popup only", off = "off" }
      ns.Print("Supply reminders " .. say[TactaraCharDB.supplies] .. ".")
    else
      ns.Reminders.ShowSupplies()
    end
  elseif cmd == "sound" or cmd == "sounds" then
    local a, b = rest:lower():match("^(%S*)%s*(%S*)")
    local KINDS = { interrupt = "interrupt", interrupts = "interrupt", int = "interrupt", kick = "interrupt",
      defensive = "defensive", defensives = "defensive", def = "defensive" }
    local function Label(key)
      local s = ns.SoundFor(key)
      return s and s.label or "off"
    end
    if a == "test" or a == "play" then
      local i, d = TactaraCharDB.interruptSound, TactaraCharDB.defensiveSound
      i = (i ~= "off") and i or ns.SOUND_DEFAULTS.interrupt
      d = (d ~= "off") and d or ns.SOUND_DEFAULTS.defensive
      ns.PlayAlert(i)
      C_Timer.After(1.5, function() ns.PlayAlert(d) end)
      ns.Print(("Playing the interrupt sound (%s), then the defensive sound (%s)."):format(Label(i), Label(d)))
    elseif KINDS[a] then
      local kind = KINDS[a]
      local key
      if b == "off" then key = "off"
      elseif b == "on" or b == "" then
        key = (b == "" and TactaraCharDB[kind .. "Sound"] ~= "off") and "off" or ns.SOUND_DEFAULTS[kind]
      elseif ns.SoundFor(b) then key = b
      end
      if key then
        TactaraCharDB[kind .. "Sound"] = key
        if key ~= "off" then ns.PlayAlert(key) end
        ns.Print(("Sound when the %s slot lights up: %s."):format(kind, Label(key)))
      else
        ns.Print("No sound called \"" .. b .. "\". /tac sound lists them.")
      end
    else
      local names = {}
      for _, s in ipairs(ns.SOUNDS) do names[#names + 1] = s.key .. " (" .. s.label .. ")" end
      ns.Print(("Sounds: interrupt %s, defensive %s. Pick one with /tac sound interrupt|defensive <sound>|off: %s. /tac sound test plays them.")
        :format(Label(TactaraCharDB.interruptSound), Label(TactaraCharDB.defensiveSound), table.concat(names, ", ")))
    end
  elseif cmd == "copy" then
    local who = rest
    if who == "" then
      ns.Profiles.ShowCopy()
    else
      local found
      for _, o in ipairs(ns.Profiles.Others()) do
        if o.key:lower():find(who:lower(), 1, true) then found = o.key break end
      end
      if found then ns.Profiles.CopyFrom(found) else ns.Print("No character called \"" .. who .. "\" has Tactara settings yet. |cffffd100/tac copy|r lists them.") end
    end
  elseif cmd == "defaults" then
    if rest:lower():match("^clear") then ns.Profiles.ClearDefault() else ns.Profiles.SaveDefault() end
  elseif cmd == "icons" then
    local a, b = rest:lower():match("^(%S*)%s*(%S*)")
    local function Count(v)
      if v == "all" then return 0 end
      local num = tonumber(v)
      return num and num >= 1 and num <= 10 and math.floor(num) or nil
    end
    if (a == "helper" or a == "popup" or a == "key" or a == "bar") and Count(b) then
      TactaraCharDB[(a == "key" or a == "bar") and "keyIcons" or "helperIcons"] = Count(b)
    elseif Count(a) then
      TactaraCharDB.keyIcons, TactaraCharDB.helperIcons = Count(a), Count(a)
    else
      ns.Print("/tac icons helper|key 1-10 or all (all = the whole rotation on the key bar, everything usable now on the helper).")
    end
    ns.HelperRefresh()
    local function Say(v) return v == 0 and "all" or tostring(v) end
    ns.Print(("Icons: helper %s, key bar %s."):format(Say(TactaraCharDB.helperIcons), Say(TactaraCharDB.keyIcons)))
  elseif cmd == "fade" then
    local a, b = rest:lower():match("^(%S*)%s*(%S*)")
    local pct = tonumber(a)
    local MODES = { show = "show", normal = "show", fade = "fade", ["see-through"] = "fade", hide = "hide" }
    if pct then
      TactaraCharDB.fadeAlpha = math.max(10, math.min(90, pct)) / 100
    elseif (a == "helper" or a == "popup" or a == "key" or a == "bar") and MODES[b] then
      TactaraCharDB[(a == "key" or a == "bar") and "keyIdle" or "helperIdle"] = MODES[b]
    elseif MODES[a] then
      TactaraCharDB.helperIdle, TactaraCharDB.keyIdle = MODES[a], MODES[a]
    else
      ns.Print("/tac fade helper|key show|fade|hide, or /tac fade 40 for how visible see-through is (10-90%).")
    end
    ns.HelperRefresh()
    ns.Print(("When not fighting: helper %s, key bar %s, see-through %d%%."):format(
      TactaraCharDB.helperIdle, TactaraCharDB.keyIdle, math.floor(TactaraCharDB.fadeAlpha * 100 + 0.5)))
  elseif cmd == "lock" then
    TactaraCharDB.locked = true
    ns.HelperRefresh()
  elseif cmd == "unlock" then
    TactaraCharDB.locked = false
    ns.HelperRefresh()
  elseif cmd == "interrupts" or cmd == "defensives" then
    local v = rest:lower()
    local cur = TactaraCharDB[cmd]
    if v == "on" then cur = true elseif v == "off" then cur = false else cur = not cur end
    TactaraCharDB[cmd] = cur
    ns.HelperRefresh()
    ns.Print((cmd == "interrupts" and "Interrupt suggestions " or "Defensive suggestions ") .. (cur and "on." or "off."))
  elseif cmd == "reset" and (rest:lower():match("^key") or rest:lower():match("^bind")) then
    ns.Welcome.ResetKeys()
  elseif cmd == "keys" or cmd == "keybinds" then
    ns.Welcome.ResetKeys()
  elseif cmd == "reset" then
    ns.ResetSequence()
  elseif cmd == "keydown" then
    local v = rest:lower()
    if v == "off" then TactaraCharDB.keyDown = false else TactaraCharDB.keyDown = nil end
    ns.SyncKeyDown()
    ns.Print("Tactara now fires on " .. (ns.useKeyDown and "key down (default)" or "key up")
      .. ". Your existing Tactara macros were updated too.")
    if not ns.useKeyDown and ns.cvarKeyDown then
      ns.Print("|cffff5555Your game is set to cast on key down, so key-up mode won't cast. Use /tac keydown auto.|r")
    end
  elseif cmd == "test" or cmd == "diag" then
    ns.Diagnose()
  elseif cmd == "probe" then
    local what = rest:lower()
    if what:match("^talent") then ns.ProbeTalents()
    elseif what:match("^remind") or what:match("^trainer") or what:match("^pull") or what:match("^suppl")
      or what:match("^ammo") then ns.ProbeReminders()
    elseif what:match("^locale") or what:match("^lang") then ns.ProbeLocale()
    else ns.Probe() end
  elseif cmd == "spells" then
    ns.ReportSpells()
  elseif cmd == "glow" and rest ~= "" and rest:lower() ~= "on" and rest:lower() ~= "off" then
    local style = rest:lower()
    if style == "test" or style == "preview" then style = nil end
    if style and not ns.GLOW_STYLES[style] then
      ns.Print("Glow styles: strong (default), normal, subtle. /tac glow test shows a preview.")
      return
    end
    ns.SetGlowStyle(style)
    ns.Print(("Glow: %s. Previewing on your bars for 3 seconds (blue = next, red = interrupt, orange = defensive).")
      :format(TactaraDB.glowStyle))
  elseif cmd == "highlight" or cmd == "glow" then
    local v = rest:lower()
    if v == "on" then TactaraCharDB.highlight = true
    elseif v == "off" then TactaraCharDB.highlight = false
    else TactaraCharDB.highlight = not TactaraCharDB.highlight end
    ns.HelperRefresh()
    ns.Print("Bar highlight " .. (TactaraCharDB.highlight and "on" or "off") .. ".")
    if ns.Editor and ns.Editor.OnRebuilt then ns.Editor.OnRebuilt() end
  elseif cmd == "helper" then
    local v = rest:lower()
    if v == "priority" or v == "sequence" or v == "auto" then
      TactaraCharDB.helperMode = v
      ns.HelperRefresh()
    end
    ns.Print("Helper follows: " .. (TactaraCharDB.helperMode == "auto"
      and "auto (priority list, or the key's sequence while you're pressing it)" or TactaraCharDB.helperMode))
  elseif cmd == "build" then
    ns.InvalidateBuild()
    ns.Print(ns.BuildSummary())
    local name, auto, why = ns.ResolveActive()
    ns.Print(("Rotation for this build: |cffffd100%s|r (%s)%s"):format(tostring(name), tostring(why),
      auto and "" or " - auto-pick is off, /tac use auto to turn it on"))
  elseif cmd == "errors" then
    TactaraDB.hideErrors = not TactaraDB.hideErrors
    ns.Print("Error text while pressing Tactara buttons: " .. (TactaraDB.hideErrors and "hidden" or "shown"))
  elseif cmd == "debug" then
    TactaraDB.debug = not TactaraDB.debug
    ns.Print("Debug " .. (TactaraDB.debug and "on" or "off"))
  else
    ns.Print("Unknown command. /tac help for the list.")
  end
end

-- Entry in the minimap's addon menu (shows Tactara's icon). Left-click opens the
-- rotation editor, right-click the settings page.
-- (the minimap button in Minimap.lua does the same)
function Tactara_OnAddonCompartmentClick(_, button)
  ns.LauncherClick(button)
end

function Tactara_OnAddonCompartmentEnter(_, menuButton)
  ns.LauncherTooltip(menuButton, "ANCHOR_LEFT")
end

function Tactara_OnAddonCompartmentLeave()
  if GameTooltip then GameTooltip:Hide() end
end

SLASH_TACTARA1 = "/tactara"
SLASH_TACTARA2 = "/tac"
SlashCmdList["TACTARA"] = HandleSlash
ns.HandleSlash = HandleSlash
