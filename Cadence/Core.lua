-- Cadence: core (namespace, saved variables, rotation storage, spell checks, events, slash commands)

local ADDON, ns = ...

ns.VERSION = "0.4.2"
ns.builtin = {}        -- [name] = rotation text shipped with the addon
ns.builtinOrder = {}   -- names in load order
ns.compiled = {}       -- .main / .aoe compiled sequences

local PREFIX = "|cff4fc3f7Cadence|r: "

function ns.Print(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. table.concat(parts, " "))
end

function ns.Debug(...)
  if CadenceDB and CadenceDB.debug then ns.Print("|cff888888[debug]|r", ...) end
end

-- Key binding labels (Esc > Options > Keybindings > AddOns > Cadence)
BINDING_HEADER_CADENCE = "Cadence"
_G["BINDING_NAME_CLICK CadenceMainButton:LeftButton"] = "Main rotation button"
_G["BINDING_NAME_CLICK CadenceAoEButton:LeftButton"] = "AoE rotation button"
_G["BINDING_NAME_CLICK CadenceInterruptButton:LeftButton"] = "Interrupt (best for your stance/gear)"

---------------------------------------------------------------------------
-- Rotation storage
---------------------------------------------------------------------------

function ns.RegisterBuiltin(text)
  local rot = ns.Parse(text)
  if not rot or not rot.name then error("Cadence: built-in rotation is missing a name: line") end
  if not ns.builtin[rot.name] then table.insert(ns.builtinOrder, rot.name) end
  ns.builtin[rot.name] = text
end

local function Saved()
  return (CadenceDB and CadenceDB.rotations) or {}
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
    CadenceDB.rotations[rot.name] = nil        -- identical to built-in: nothing to store
  else
    CadenceDB.rotations[rot.name] = text
  end
  return true, rot.name
end

-- Deletes a custom rotation, or reverts an edited built-in to the shipped version.
function ns.DeleteRotation(name)
  if not name or not CadenceDB then return end
  CadenceDB.rotations[name] = nil
  if CadenceCharDB and CadenceCharDB.active == name and not ns.IsBuiltin(name) then
    CadenceCharDB.active = "auto"
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
      tree = rot.meta.tree, weapon = rot.meta.weapon,
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
    end
  end

  knownCache[name] = known
  return known
end

ns.BUFF_REFRESH_SECONDS = 30

-- true = buff is up with plenty of time left, false = missing/expiring, nil = can't tell.
-- Only called out of combat; if the game hides the value, we treat it as "can't tell".
function ns.HasBuff(name)
  if InCombatLockdown() then return nil end
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
  CadenceDB = CadenceDB or {}
  CadenceDB.rotations = CadenceDB.rotations or {}
  CadenceDB.version = ns.VERSION
  if CadenceDB.hideErrors == nil then CadenceDB.hideErrors = true end
  CadenceDB.glowStyle = CadenceDB.glowStyle or "strong"
  CadenceCharDB = CadenceCharDB or {}
  CadenceCharDB.active = CadenceCharDB.active or "auto"
  if CadenceCharDB.showDisplay == nil then CadenceCharDB.showDisplay = true end
  if CadenceCharDB.locked == nil then CadenceCharDB.locked = false end
  if CadenceCharDB.highlight == nil then CadenceCharDB.highlight = true end
  CadenceCharDB.helperMode = CadenceCharDB.helperMode or "auto"
  if CadenceCharDB.showHelper == nil then CadenceCharDB.showHelper = true end
  if CadenceCharDB.interrupts == nil then CadenceCharDB.interrupts = true end
  if CadenceCharDB.defensives == nil then CadenceCharDB.defensives = true end
  CadenceCharDB.display = CadenceCharDB.display or {}
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
-- only printed with /cad debug on: shows whether presses turn into casts
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
  if not (CadenceDB and CadenceDB.debug) then return end
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
    ns.CreateDisplay()
    ns.CreateHelperPopup()
    ns.RequestRebuild("login", 1)
    ns.Print(("v%s loaded. Type |cffffd100/cad|r to open the editor, |cffffd100/cad help|r for commands."):format(ns.VERSION))
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
  "|cffffd100/cad|r  open the rotation editor",
  "|cffffd100/cad use <name>|r  use a rotation (e.g. /cad use prot), or |cffffd100/cad use auto|r",
  "|cffffd100/cad list|r  list rotations for your class",
  "|cffffd100/cad bind|r  press a key for the rotation (any key, even one on your bar; your keybinds stay as they are)",
  "|cffffd100/cad bind aoe|r / |cffffd100bind interrupt|r  same for AoE / the interrupt key   |cffffd100/cad unbind|r [aoe / interrupt / all]",
  "|cffffd100/cad highlight|r  glow on the next spell on your action bars (on/off)",
  "|cffffd100/cad glow strong / normal / subtle|r  how loud the glow is   |cffffd100/cad glow test|r  3-second preview",
  "|cffffd100/cad helper auto / priority / sequence|r  what the glow follows (auto: priority list, or the key's sequence while you press it)",
  "|cffffd100/cad build|r  your detected talents and weapons, and the rotation they pick",
  "|cffffd100/cad steps|r  print the current compiled sequence",
  "|cffffd100/cad spells|r  which rotation spells you've learned and which are still to come",
  "|cffffd100/cad show|r / |cffffd100hide|r [key / helper]  the key bar and/or the helper popup",
  "|cffffd100/cad lock|r / |cffffd100unlock|r  lock or move both",
  "|cffffd100/cad interrupts|r / |cffffd100defensives|r  red interrupt / orange defensive suggestions on or off",
  "|cffffd100/cad reset|r  restart the sequence from the opener",
  "|cffffd100/cad errors|r  show/hide the red 'not ready' error text while pressing (hidden by default)",
  "|cffffd100/cad test|r  print diagnostics (key binding, macros, settings)",
  "|cffffd100/cad probe|r  check what the game lets addons read (run out of combat and in combat)",
  "|cffffd100/cad debug|r  print every press, cast and game error to chat",
  "|cffffd100/cad keydown auto / off|r  troubleshooting: fire on key down (default) or key up",
  "Key bindings: Esc > Options > Keybindings > AddOns > Cadence",
}

local function HandleSlash(msg)
  msg = ns.trim(msg or "")
  local cmd, rest = msg:match("^(%S*)%s*(.-)$")
  cmd = (cmd or ""):lower()

  if cmd == "" or cmd == "edit" or cmd == "config" or cmd == "options" then
    ns.Editor.Toggle()
  elseif cmd == "help" or cmd == "?" then
    for _, l in ipairs(HELP) do ns.Print(l) end
  elseif cmd == "use" then
    if rest:lower() == "auto" or rest == "" then
      CadenceCharDB.active = "auto"
      ns.Print("Auto-pick on: the rotation follows your talents.")
    else
      local name = ns.FindRotation(rest, ns.GetClassToken())
      if not name then
        ns.Print("No rotation matching '" .. rest .. "'. Try /cad list.")
        return
      end
      CadenceCharDB.active = name
    end
    ns.RequestRebuild("use", 0.05)
  elseif cmd == "list" then
    local list = ns.ListRotations(ns.GetClassToken())
    if #list == 0 then ns.Print("No rotations for your class yet. Make one with /cad.") end
    for _, r in ipairs(list) do
      local tag = r.edited and " (edited)" or (r.builtin and "" or " (yours)")
      local mark = (r.name == ns.activeName) and " |cff00ff00< active|r" or ""
      ns.Print("- " .. r.name .. tag .. mark)
    end
    ns.Print("Mode: " .. (CadenceCharDB.active == "auto" and "auto-pick" or "manual"))
  elseif cmd == "bind" then
    ns.StartKeyCapture(rest:lower())
  elseif cmd == "unbind" then
    ns.Unbind(rest:lower())
  elseif cmd == "macro" or cmd == "macros" then
    ns.Print("WoW doesn't let an action-bar macro run Cadence (a macro can't /click another macro). "
      .. "Use |cffffd100/cad bind|r instead: pick any key, even one your action bar uses, and Cadence "
      .. "takes it over without changing your keybinds. You can delete old 'Cadence' macros.")
  elseif cmd == "steps" or cmd == "dump" or cmd == "preview" then
    ns.PrintSequence(ns.compiled.main, "Main button")
    ns.PrintSequence(ns.compiled.aoe, "AoE button", true)
  elseif cmd == "show" or cmd == "hide" then
    local on = (cmd == "show")
    local what = rest:lower()
    if what == "" or what == "key" or what == "bar" or what == "all" or what == "both" then CadenceCharDB.showDisplay = on end
    if what == "" or what == "helper" or what == "popup" or what == "all" or what == "both" then CadenceCharDB.showHelper = on end
    ns.HelperRefresh()
  elseif cmd == "lock" then
    CadenceCharDB.locked = true
    ns.HelperRefresh()
  elseif cmd == "unlock" then
    CadenceCharDB.locked = false
    ns.HelperRefresh()
  elseif cmd == "interrupts" or cmd == "defensives" then
    local v = rest:lower()
    local cur = CadenceCharDB[cmd]
    if v == "on" then cur = true elseif v == "off" then cur = false else cur = not cur end
    CadenceCharDB[cmd] = cur
    ns.HelperRefresh()
    ns.Print((cmd == "interrupts" and "Interrupt suggestions " or "Defensive suggestions ") .. (cur and "on." or "off."))
  elseif cmd == "reset" then
    ns.ResetSequence()
  elseif cmd == "keydown" then
    local v = rest:lower()
    if v == "off" then CadenceCharDB.keyDown = false else CadenceCharDB.keyDown = nil end
    ns.SyncKeyDown()
    ns.Print("Cadence now fires on " .. (ns.useKeyDown and "key down (default)" or "key up")
      .. ". Your existing Cadence macros were updated too.")
    if not ns.useKeyDown and ns.cvarKeyDown then
      ns.Print("|cffff5555Your game is set to cast on key down, so key-up mode won't cast. Use /cad keydown auto.|r")
    end
  elseif cmd == "test" or cmd == "diag" then
    ns.Diagnose()
  elseif cmd == "probe" then
    ns.Probe()
  elseif cmd == "spells" then
    ns.ReportSpells()
  elseif cmd == "glow" and rest ~= "" and rest:lower() ~= "on" and rest:lower() ~= "off" then
    local style = rest:lower()
    if style == "test" or style == "preview" then style = nil end
    if style and not ns.GLOW_STYLES[style] then
      ns.Print("Glow styles: strong (default), normal, subtle. /cad glow test shows a preview.")
      return
    end
    ns.SetGlowStyle(style)
    ns.Print(("Glow: %s. Previewing on your bars for 3 seconds (blue = next, red = interrupt, orange = defensive).")
      :format(CadenceDB.glowStyle))
  elseif cmd == "highlight" or cmd == "glow" then
    local v = rest:lower()
    if v == "on" then CadenceCharDB.highlight = true
    elseif v == "off" then CadenceCharDB.highlight = false
    else CadenceCharDB.highlight = not CadenceCharDB.highlight end
    ns.HelperRefresh()
    ns.Print("Bar highlight " .. (CadenceCharDB.highlight and "on" or "off") .. ".")
    if ns.Editor and ns.Editor.OnRebuilt then ns.Editor.OnRebuilt() end
  elseif cmd == "helper" then
    local v = rest:lower()
    if v == "priority" or v == "sequence" or v == "auto" then
      CadenceCharDB.helperMode = v
      ns.HelperRefresh()
    end
    ns.Print("Helper follows: " .. (CadenceCharDB.helperMode == "auto"
      and "auto (priority list, or the key's sequence while you're pressing it)" or CadenceCharDB.helperMode))
  elseif cmd == "build" then
    ns.InvalidateBuild()
    ns.Print(ns.BuildSummary())
    local name, auto, why = ns.ResolveActive()
    ns.Print(("Rotation for this build: |cffffd100%s|r (%s)%s"):format(tostring(name), tostring(why),
      auto and "" or " - auto-pick is off, /cad use auto to turn it on"))
  elseif cmd == "errors" then
    CadenceDB.hideErrors = not CadenceDB.hideErrors
    ns.Print("Error text while pressing Cadence buttons: " .. (CadenceDB.hideErrors and "hidden" or "shown"))
  elseif cmd == "debug" then
    CadenceDB.debug = not CadenceDB.debug
    ns.Print("Debug " .. (CadenceDB.debug and "on" or "off"))
  else
    ns.Print("Unknown command. /cad help for the list.")
  end
end

SLASH_CADENCE1 = "/cadence"
SLASH_CADENCE2 = "/cad"
SlashCmdList["CADENCE"] = HandleSlash
ns.HandleSlash = HandleSlash
