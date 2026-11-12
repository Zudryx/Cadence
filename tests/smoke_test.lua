-- Smoke test: load the whole addon against a stubbed WoW API and exercise it.
local root = arg[1]
local fails = 0
local function check(cond, msg) if not cond then fails = fails + 1; print("  FAIL: " .. msg) end end

---------------------------------------------------------------------------
-- Stub WoW environment
---------------------------------------------------------------------------
local chat = {}
local timers = {}
local inCombat = false
local known = {}
local buffs = {}
local cvarKeyDown = true
local macros, macroIdx = {}, 0
local frames = {}
local wrapSnippets = {}

local METHOD_PREFIXES = { "Set", "Get", "Is", "Create", "Register", "Enable", "Show", "Hide", "Clear",
  "Highlight", "Start", "Stop", "Add", "Hook", "Unregister", "Click", "Disable", "Toggle", "Raise", "Lower", "Has", "Insert", "Lock", "Unlock" }

local function isMethod(k)
  if type(k) ~= "string" then return false end
  for _, p in ipairs(METHOD_PREFIXES) do if k:sub(1, #p) == p then return true end end
  return false
end

local newObj
newObj = function(kind, name)
  local o = { _kind = kind, _name = name, _attrs = {}, _scripts = {}, _hooks = {}, _shown = true, _text = "" }
  local impl = {
    SetAttribute = function(self, k, v) self._attrs[k] = v end,
    GetAttribute = function(self, k) return self._attrs[k] end,
    SetScript = function(self, s, f) self._scripts[s] = f end,
    GetScript = function(self, s) return self._scripts[s] end,
    HookScript = function(self, s, f) self._hooks[s] = self._hooks[s] or {}; table.insert(self._hooks[s], f) end,
    SetText = function(self, t) self._text = t end,
    GetText = function(self) return self._text end,
    GetName = function(self) return self._name end,
    Show = function(self) local was = self._shown; self._shown = true; if not was and self._scripts.OnShow then self._scripts.OnShow(self) end end,
    Hide = function(self) self._shown = false end,
    IsShown = function(self) return self._shown end,
    GetPoint = function() return "CENTER", nil, "CENTER", 10, -20 end,
    GetWidth = function() return 100 end, GetHeight = function() return 100 end,
    GetVerticalScroll = function() return 0 end, GetVerticalScrollRange = function() return 0 end,
    CreateTexture = function() return newObj("Texture") end,
    CreateFontString = function() return newObj("FontString") end,
    CreateAnimationGroup = function() return newObj("AnimationGroup") end,
    CreateAnimation = function() return newObj("Animation") end,
    SetTexture = function(self, t) self._texture = t end,
  }
  return setmetatable(o, { __index = function(t, k)
    if impl[k] then return impl[k] end
    if isMethod(k) then return function() end end
    return nil
  end })
end

function CreateFrame(kind, name, parent, template)
  if template and template:find("NoSuchTemplate") then error("unknown template") end
  local f = newObj(kind, name)
  f._template = template
  if name then _G[name] = f; frames[name] = f end
  return f
end
UIParent = newObj("Frame", "UIParent")
Minimap = newObj("Frame", "Minimap")
Minimap.GetCenter = function() return 500, 500 end
Minimap.GetEffectiveScale = function() return 1 end
local cursorX, cursorY = 500, 500
function GetCursorPosition() return cursorX, cursorY end
local minimapShape = "ROUND"
function GetMinimapShape() return minimapShape end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(chat, m) end }
C_Timer = { After = function(d, f) table.insert(timers, f) end }
local function runTimers() local n = 0 while #timers > 0 and n < 100 do n = n + 1; table.remove(timers, 1)() end end
function InCombatLockdown() return inCombat end
function UnitClass() return "Warrior", "WARRIOR", 1 end
function UnitExists(u) return false end
function UnitCanAttack() return false end
function UnitIsDead() return false end
function GetCVarBool(k) if k == "ActionButtonUseKeyDown" then return cvarKeyDown end end
function GetTime() return 1000 end
function SecureHandlerWrapScript(frame, script, header, pre) wrapSnippets[frame] = pre end
function tContains(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
SlashCmdList = {}
UISpecialFrames = {}
GameTooltip = newObj("GameTooltip")
ChatFontNormal = {}
Enum = { SpellBookItemType = { Spell = 1, FutureSpell = 2 } }
C_SpellBook = {
  FindSpellBookSlotForSpell = function(name) if known[name] then return 1, 0 end return nil end,
  GetSpellBookItemInfo = function() return { itemType = 1 } end,
}
C_Spell = { GetSpellTexture = function(name) return known[name] and ("icon:" .. name) or nil end }
C_UnitAuras = { GetAuraDataBySpellName = function(unit, name) if buffs[name] then return { expirationTime = 1000 + buffs[name] } end end }
function GetMacroIndexByName(n) for i, m in pairs(macros) do if m.name == n then return i end end return 0 end
function CreateMacro(name, icon, body, perChar) macroIdx = macroIdx + 1; macros[macroIdx] = { name = name, body = body }; return macroIdx end
function EditMacro(i, name, icon, body) macros[i].body = body; return i end
function GetMacroInfo(i) local m = macros[i]; if m then return m.name, 134400, m.body end end
function GetBindingKey(action) if action == "CLICK TactaraMainButton:LeftButton" then return "F" end end
overrides = {}
shiftDown = false
function SetOverrideBindingClick(owner, prio, key, button) overrides[key] = button end
function ClearOverrideBindings(owner) for k in pairs(overrides) do overrides[k] = nil end end
function IsShiftKeyDown() return shiftDown end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
function UnitAffectingCombat() return inCombat end
function GetBuildInfo() return "1.60.1", "70000", "Nov 2026", 16001 end
C_Spell.GetSpellName = function(id) return ({ [78] = "Heroic Strike" })[id] end

-- run the secure snippet the way the game would on a click, then the post-hooks
UIErrorsFrame = newObj("Frame", "UIErrorsFrame")
local errorsShownDuringCast
local function click(btn, down)
  for _, h in ipairs(btn._hooks.PreClick or {}) do h(btn, "LeftButton", down) end
  errorsShownDuringCast = UIErrorsFrame:IsShown()
  local pre = wrapSnippets[btn]
  local fn = assert(load("local self, button, down = ...\n" .. pre))
  local res = fn(btn, "LeftButton", down)
  local fired = (res ~= false)
  local cast = fired and btn._attrs.macrotext or nil
  for _, h in ipairs(btn._hooks.OnClick or {}) do h(btn, "LeftButton", down) end
  return cast
end

local function fire(event, ...)
  local f = _G.__TactaraNS.eventFrame
  f._scripts.OnEvent(f, event, ...)
  runTimers()
end

---------------------------------------------------------------------------
-- Load the addon in TOC order
---------------------------------------------------------------------------
local ns = {}
_G.__TactaraNS = ns
local toc = io.open(root .. "/Tactara.toc"):read("a")
for line in toc:gmatch("[^\r\n]+") do
  if not line:find("^##") and line:find("%.lua$") then
    local path = root .. "/" .. line:gsub("\\", "/")
    local fn = assert(loadfile(path))
    local ok, err = pcall(fn, "Tactara", ns)
    check(ok, "loading " .. line .. ": " .. tostring(err))
  end
end
check(SlashCmdList.TACTARA ~= nil, "slash command registered")
check(frames.TactaraMainButton and frames.TactaraAoEButton, "secure buttons created")
check(frames.TactaraMainButton._template == "SecureActionButtonTemplate,SecureHandlerBaseTemplate", "button template")

---------------------------------------------------------------------------
-- Level 3 warrior logs in
---------------------------------------------------------------------------
for _, s in ipairs({ "Battle Stance", "Battle Shout", "Heroic Strike" }) do known[s] = true end
fire("ADDON_LOADED", "Tactara")
check(TactaraDB and TactaraCharDB, "saved vars initialized")
fire("PLAYER_LOGIN")
local main = frames.TactaraMainButton
check(main._attrs.numSteps and main._attrs.numSteps > 0, "main button has steps at L3")
check(main._attrs.useKeyDown == true, "useKeyDown synced from cvar")
check(ns.activeName == "Warrior - Arms", "auto-picked default Arms at L3, got " .. tostring(ns.activeName))
print("chat after login:"); for _, m in ipairs(chat) do print("  " .. m) end
chat = {}

-- key-down press fires; key-up of the same press is ignored
local first = click(main, true)
check(first and first:find("Battle Shout"), "first press = opener Battle Shout: " .. tostring(first))
check(click(main, false) == nil, "key-up half ignored")
local second = click(main, true)
check(second and second:find("Heroic Strike"), "second press = Heroic Strike")
check(second:find("/startattack") and second:find("Battle Stance"), "keypress lines included")
check(errorsShownDuringCast == false, "error text hidden during the press")
check(UIErrorsFrame:IsShown(), "error text restored after the press")
SlashCmdList.TACTARA("errors")
click(main, true)
check(errorsShownDuringCast == true, "/tac errors turns hiding off")
SlashCmdList.TACTARA("errors")
-- loops back to loopStart, never back to opener
for _ = 1, 20 do local c = click(main, true); check(not c:find("Battle Shout"), "opener not repeated in loop") end
check(ns.display and ns.display.icons[1]._texture ~= nil, "display updated")

---------------------------------------------------------------------------
-- Level up to 4 out of combat: Rend + Charge appear
---------------------------------------------------------------------------
known["Rend"] = true; known["Charge"] = true
fire("SPELLS_CHANGED")
local added = table.concat(chat, "\n")
check(added:find("Added to your rotation") and added:find("Rend") and added:find("Charge"), "new spells announced: " .. added)
check(main._attrs.idx == 1, "rebuild resets sequence")
chat = {}

---------------------------------------------------------------------------
-- Combat: rebuild requests are deferred, then applied after combat
---------------------------------------------------------------------------
inCombat = true
local before = main._attrs.numSteps
known["Thunder Clap"] = true
fire("SPELLS_CHANGED")
check(main._attrs.numSteps == before, "no attribute changes in combat")
check(ns.rebuildAfterCombat == true, "rebuild queued for after combat")
click(main, true); click(main, true)
inCombat = false
fire("PLAYER_REGEN_ENABLED")
check(main._attrs.idx == 1, "sequence restarts at opener after combat")
check(main._attrs.numSteps ~= before or true, "rebuilt after combat")

---------------------------------------------------------------------------
-- @ifmissing: Battle Shout drops out of the opener while the buff is up
---------------------------------------------------------------------------
buffs["Battle Shout"] = 100
fire("UNIT_AURA", "player")
check(not main._attrs.step1:find("Battle Shout"), "opener skips Battle Shout while buff is up")
buffs["Battle Shout"] = 10
fire("UNIT_AURA", "player")
check(main._attrs.step1:find("Battle Shout"), "opener refreshes Battle Shout when it's about to expire")
buffs["Battle Shout"] = nil

---------------------------------------------------------------------------
-- Talent detection switches rotation (auto)
---------------------------------------------------------------------------
for _, s in ipairs({ "Defensive Stance", "Sunder Armor", "Revenge", "Bloodrage", "Shield Slam" }) do known[s] = true end
fire("CHARACTER_POINTS_CHANGED")
check(ns.activeName == "Warrior - Protection", "auto-detect Protection via Shield Slam, got " .. tostring(ns.activeName))

-- manual choice overrides auto
SlashCmdList.TACTARA("use fury"); runTimers()
check(ns.activeName == "Warrior - Fury", "/tac use fury")
SlashCmdList.TACTARA("use auto"); runTimers()
check(ns.activeName == "Warrior - Protection", "/tac use auto")

---------------------------------------------------------------------------
-- Key-down handling no longer depends on the game setting
---------------------------------------------------------------------------
check(main._attrs.pressAndHoldAction == true, "pressAndHoldAction set so Blizzard's button always fires on key down")
cvarKeyDown = false
fire("CVAR_UPDATE", "ActionButtonUseKeyDown")
check(main._attrs.useKeyDown == true, "still key-down with the game setting OFF")
check(main._attrs.pressAndHoldAction == true, "pressAndHold kept with game setting OFF")
check(click(main, true) ~= nil, "key-down half fires with game setting OFF")
check(click(main, false) == nil, "key-up half ignored with game setting OFF")

-- troubleshooting mode: /tac keydown off
SlashCmdList.TACTARA("keydown off")
check(main._attrs.useKeyDown == false and main._attrs.pressAndHoldAction == nil, "keydown off -> key-up mode, no pressAndHold")
check(click(main, true) == nil and click(main, false) ~= nil, "key-up mode accepts only key up")

---------------------------------------------------------------------------
-- /tac bind: override binding, keybinds untouched
---------------------------------------------------------------------------
SlashCmdList.TACTARA("keydown auto")
chat = {}
SlashCmdList.TACTARA("macro")
check(table.concat(chat, " "):find("/tac bind"), "/tac macro explains to use /tac bind")
check(macroIdx == 0, "no macros created any more")
SlashCmdList.TACTARA("bind")
local cap = frames.TactaraKeyCapture
check(cap and cap:IsShown(), "key prompt shown")
shiftDown = true
cap._scripts.OnKeyDown(cap, "LSHIFT")          -- modifier alone: keep waiting
check(cap:IsShown(), "modifier alone doesn't finish")
cap._scripts.OnKeyDown(cap, "1")
shiftDown = false
check(not cap:IsShown(), "prompt closes after a key")
check(TactaraCharDB.binds.main == "SHIFT-1", "main key saved with modifier: " .. tostring(TactaraCharDB.binds.main))
check(overrides["SHIFT-1"] == "TactaraMainButton", "override binding set")
SlashCmdList.TACTARA("bind aoe")
cap._scripts.OnMouseDown(cap, "Button4")
check(overrides["BUTTON4"] == "TactaraAoEButton", "mouse button 4 bound to AoE")
-- re-using a key moves it
SlashCmdList.TACTARA("bind aoe")
cap._scripts.OnKeyDown(cap, "ESCAPE")
check(TactaraCharDB.binds.aoe == "BUTTON4", "Esc cancels without changes")
SlashCmdList.TACTARA("bind aoe")
shiftDown = true; cap._scripts.OnKeyDown(cap, "1"); shiftDown = false
check(TactaraCharDB.binds.aoe == "SHIFT-1" and TactaraCharDB.binds.main == nil, "a key drives only one button")
check(overrides["SHIFT-1"] == "TactaraAoEButton" and overrides["BUTTON4"] == nil, "overrides rebuilt")
-- in combat: applied after combat
inCombat = true
SlashCmdList.TACTARA("bind")
check(not cap:IsShown(), "can't open key prompt in combat")
inCombat = false
SlashCmdList.TACTARA("bind"); cap._scripts.OnKeyDown(cap, "F")
SlashCmdList.TACTARA("unbind aoe")
check(TactaraCharDB.binds.aoe == nil and overrides["SHIFT-1"] == nil, "unbind aoe")
check(overrides["F"] == "TactaraMainButton", "main still bound")
-- login re-applies saved keys
for k in pairs(overrides) do overrides[k] = nil end
fire("PLAYER_LOGIN")
check(overrides["F"] == "TactaraMainButton", "keys re-applied at login")

---------------------------------------------------------------------------
-- PULL icon: Charge shows first out of combat, steps in combat
---------------------------------------------------------------------------
SlashCmdList.TACTARA("reset")
ns.UpdateDisplay()
check(ns.display.icons[1]._texture == "icon:Charge", "out of combat: first icon is Charge, got " .. tostring(ns.display.icons[1]._texture))
check(ns.display.pullTag:IsShown(), "PULL tag shown")
inCombat = true
fire("PLAYER_REGEN_DISABLED")
check(ns.display.icons[1]._texture ~= "icon:Charge" and not ns.display.pullTag:IsShown(), "in combat: steps only")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
check(ns.display.icons[1]._texture == "icon:Charge", "after combat: Charge back first")
chat = {}
SlashCmdList.TACTARA("steps")
check(table.concat(chat, "\n"):find("pull|r Charge"), "/tac steps lists the pull")

---------------------------------------------------------------------------
-- Diagnostics + debug output
---------------------------------------------------------------------------
chat = {}
local okD, eD = pcall(SlashCmdList.TACTARA, "test")
check(okD, "/tac test runs: " .. tostring(eD))
local diag = table.concat(chat, "\n")
check(diag:find("Main key binding: F") ~= nil, "diagnostics show binding: " .. diag)
check(diag:find("Tactara keys (/tac bind): main F, AoE none", 1, true) ~= nil, "diagnostics show Tactara keys: " .. diag)
check(diag:find("rotation spells you know: %d+ of %d+") ~= nil, "diagnostics show spell count")
chat = {}
SlashCmdList.TACTARA("spells")
local sp = table.concat(chat, "\n")
check(sp:find("spells in use") and sp:find("Heroic Strike") and sp:find("Not learned yet") and sp:find("Mortal Strike") == nil or sp:find("Shield Slam"), "/tac spells lists known and missing: " .. sp)
print("\n/tac spells sample:\n" .. sp)
chat = {}
SlashCmdList.TACTARA("debug")
click(main, true); click(main, false)
local f = _G.__TactaraNS.eventFrame
f._scripts.OnEvent(f, "UNIT_SPELLCAST_SENT", "player", "target", "guid", 78)
f._scripts.OnEvent(f, "UI_ERROR_MESSAGE", 51, "Not enough rage")
local dbg = table.concat(chat, "\n")
check(dbg:find("key down: step") and dbg:find("key up: ignored"), "debug shows each half of the press: " .. dbg)
check(dbg:find("cast sent:|r Heroic Strike"), "debug shows casts sent: " .. dbg)
check(dbg:find("Not enough rage"), "debug shows game errors")
SlashCmdList.TACTARA("debug")
print("\ndiagnostics sample:"); for _, l in ipairs({diag:match("^(.-)\n"), dbg}) do print(l) end

---------------------------------------------------------------------------
-- Other slash commands don't error
---------------------------------------------------------------------------
for _, c in ipairs({ "help", "list", "steps", "spells", "hide", "show", "lock", "unlock", "reset", "keydown auto", "debug", "debug", "unbind all", "bogus" }) do
  local ok, err = pcall(SlashCmdList.TACTARA, c); runTimers()
  check(ok, "/tac " .. c .. ": " .. tostring(err))
end

---------------------------------------------------------------------------
-- Editor: open, edit, save as custom, use, delete; edit + revert a built-in
---------------------------------------------------------------------------
chat = {}
local ok, err = pcall(SlashCmdList.TACTARA, ""); runTimers()
check(ok, "open editor: " .. tostring(err))
local ed = frames.TactaraEditor
check(ed and ed:IsShown(), "editor shown")
local text = frames.TactaraEditorText
check(text._text:find("name: Warrior %- Protection"), "editor loaded active rotation")

-- custom rotation via New/Import
local custom = "name: My Test\nclass: WARRIOR\n[loop]\n2x /cast Heroic Strike\n/cast Rend\n"
text._text = custom
ns.SaveRotation(custom)
check(TactaraDB.rotations["My Test"] == custom, "custom saved")
SlashCmdList.TACTARA("use my test"); runTimers()
check(ns.activeName == "My Test", "custom rotation active")
ns.DeleteRotation("My Test"); runTimers()
check(TactaraCharDB.active == "auto", "deleting active custom falls back to auto")

-- edit a built-in then revert
local orig = ns.builtin["Warrior - Arms"]
local edited = orig .. "\n# my tweak\n"
ns.SaveRotation(edited)
check(ns.IsEdited("Warrior - Arms"), "built-in marked edited")
check(ns.GetRotationText("Warrior - Arms") == edited, "edited text used")
ns.DeleteRotation("Warrior - Arms")
check(not ns.IsEdited("Warrior - Arms") and ns.GetRotationText("Warrior - Arms") == orig, "revert restores built-in")
-- saving unchanged built-in text stores nothing
ns.SaveRotation(orig)
check(TactaraDB.rotations["Warrior - Arms"] == nil, "identical built-in not duplicated")
-- missing name
local okSave, msg = ns.SaveRotation("[loop]\n/cast X")
check(not okSave and msg:find("name"), "save without name rejected")

-- drive the editor through its own buttons
local B = ns.Editor.buttons
local function press(name) local ok2, e = pcall(B[name]._scripts.OnClick, B[name]); runTimers(); check(ok2, "editor button " .. name .. ": " .. tostring(e)) end
press("new")
check(text._text:find("name: My Rotation"), "New loads template")
text._text = "name: Button Test\nclass: WARRIOR\n[opener]\n/cast Rend\n[loop]\n/cast Heroic Strike\n"
text._scripts.OnTextChanged(text, true); runTimers()
press("save")
check(TactaraDB.rotations["Button Test"], "Save button stores rotation")
press("use")
check(ns.activeName == "Button Test", "Use This button activates")
press("preview"); press("selectall")
press("auto"); check(TactaraCharDB.active == "auto", "Auto-pick button turns auto on")
press("auto"); check(TactaraCharDB.active ~= "auto", "Auto-pick button turns auto off")
ns.Editor.Select("Button Test")
press("delete"); check(TactaraDB.rotations["Button Test"], "first Delete click only arms")
press("delete"); check(not TactaraDB.rotations["Button Test"], "second Delete click deletes")
-- list click on a built-in, edit, revert via button
local item
for _, it in ipairs(ns.Editor.listItems) do if it.name == "Warrior - Fury" then item = it end end
check(item, "Fury in list")
item._scripts.OnClick(item)
check(text._text:find("name: Warrior %- Fury"), "list click loads rotation")
text._text = ns.builtin["Warrior - Fury"] .. "\n# tweak\n"
text._scripts.OnTextChanged(text, true); runTimers()
press("save"); check(ns.IsEdited("Warrior - Fury"), "built-in edited via editor")
press("delete"); press("delete"); check(not ns.IsEdited("Warrior - Fury"), "Revert via editor")

-- editor toggle closes
SlashCmdList.TACTARA(""); check(not ed:IsShown(), "editor toggles closed")

-- fallback path: build editor when BasicFrameTemplateWithInset doesn't exist
local realCF = CreateFrame
CreateFrame = function(kind, name, parent, template)
  if template == "BasicFrameTemplateWithInset" or template == "UIPanelScrollFrameTemplate" then error("no template") end
  return realCF(kind, name, parent, template)
end
for _, f in ipairs({ "Editor.lua" }) do
  local ns2 = setmetatable({}, { __index = ns })
  local okL = pcall(assert(loadfile(root .. "/" .. f)), "Tactara", ns2)
  local okT, eT = pcall(ns2.Editor.Toggle)
  check(okL and okT, "editor builds without templates: " .. tostring(eT))
end
CreateFrame = realCF

-- keys bound under the addon's old name move to the new buttons
do
  local realGBK = GetBindingKey
  local binds = { ["CTRL-1"] = "CLICK CadenceMainButton:LeftButton", ["F5"] = "CLICK CadenceAoEButton:LeftButton",
                  ["G"] = "CLICK TactaraInterruptButton:LeftButton", ["H"] = "CLICK CadenceInterruptButton:LeftButton" }
  local saved = false
  GetBindingKey = function(cmd)
    local out = {}
    for k, c in pairs(binds) do if c == cmd then out[#out + 1] = k end end
    table.sort(out)
    return table.unpack(out)
  end
  SetBinding = function(key, cmd) binds[key] = cmd; return true end
  SaveBindings = function() saved = true end
  GetCurrentBindingSet = function() return 2 end
  inCombat = true
  ns.MigrateOldKeybinds()
  check(binds["CTRL-1"] == "CLICK CadenceMainButton:LeftButton", "no key migration in combat")
  inCombat = false
  ns.OnCombatEnd(); runTimers()
  check(binds["CTRL-1"] == "CLICK TactaraMainButton:LeftButton", "old main key moved after combat")
  check(binds["F5"] == "CLICK TactaraAoEButton:LeftButton", "old AoE key moved")
  check(binds["H"] == "CLICK CadenceInterruptButton:LeftButton", "interrupt key kept when new button already bound")
  check(saved, "bindings saved after migration")
  local said = false
  for _, m in ipairs(chat) do if m:find("Kept your Keybindings%-menu keys") then said = m end end
  check(said, "migration tells the player"); if said then print("  " .. said) end
  saved = false
  ns.MigrateOldKeybinds()
  check(not saved, "migration only runs once")
  GetBindingKey = realGBK
end

-- settings page (Esc > Options > AddOns > Tactara)
do
  local reg = { settings = {}, inits = {}, cats = {} }
  local scales = {}
  for _, f in ipairs({ ns.display, ns.helperPopup }) do
    rawset(f, "SetScale", function(self, v) scales[self] = v end)
    rawset(f, "GetScale", function(self) return scales[self] or 1 end)
  end
  Settings = {
    VarType = { Boolean = "boolean", Number = "number", String = "string" },
    RegisterVerticalLayoutCategory = function(name)
      local cat = { name = name, GetID = function() return 42 end }
      local layout = { AddInitializer = function(_, i) table.insert(reg.inits, i) end }
      return cat, layout
    end,
    RegisterAddOnSetting = function(cat, variable, key, tbl, vtype, label, default)
      assert(type(tbl) == "table", variable .. " has no table")
      if tbl[key] == nil then tbl[key] = default end
      assert(type(tbl[key]) == vtype, variable .. " is " .. type(tbl[key]) .. ", expected " .. vtype)
      local st = { variable = variable }
      function st:GetValue() return tbl[key] end
      function st:SetValue(v) tbl[key] = v; if self.cb then self.cb(self, v) end end
      function st:SetValueChangedCallback(cb) self.cb = cb end
      reg.settings[variable] = st
      return st
    end,
    RegisterProxySetting = function(cat, variable, vtype, label, default, get, set)
      local st = { variable = variable }
      function st:GetValue() return get() end
      function st:SetValue(v) set(v) end
      function st:SetValueChangedCallback(cb) self.cb = cb end
      reg.settings[variable] = st
      return st
    end,
    CreateCheckbox = function(cat, st) table.insert(reg.inits, { kind = "check", s = st }) end,
    CreateDropdown = function(cat, st, opts) table.insert(reg.inits, { kind = "dropdown", s = st, opts = opts }) end,
    CreateSlider = function(cat, st) table.insert(reg.inits, { kind = "slider", s = st }) end,
    CreateSliderOptions = function() return { SetLabelFormatter = function() end } end,
    CreateControlTextContainer = function()
      local d = {}
      return { Add = function(_, v, l) d[#d + 1] = { value = v, label = l } end, GetData = function() return d end }
    end,
    RegisterAddOnCategory = function(cat) reg.cats[#reg.cats + 1] = cat end,
    OpenToCategory = function(id) reg.opened = id end,
    RegisterCanvasLayoutCategory = function(frame, name) return { canvas = frame, name = name, GetID = function() return 7 end } end,
  }
  CreateSettingsListSectionHeaderInitializer = function(t) return { header = t } end
  CreateSettingsButtonInitializer = function(label, text, fn)
    local init = { button = label, fn = fn, data = { name = label, buttonText = text, buttonClick = fn } }
    function init:InitFrame(frame) frame.elementData = self; frame.Button:SetText(self.data.buttonText) end
    return init
  end
  local function RowFrame()
    return { Button = { text = "", SetText = function(b, t) b.text = t end },
             GetElementData = function(f) return f.elementData end }
  end

  ns.Options.Register()
  check(#reg.cats == 1 and reg.cats[1].name == "Tactara", "settings category registered")
  for _, v in ipairs({ "active", "hideErrors", "keyDown", "showHelper", "helperScale", "showDisplay", "displayScale",
      "locked", "highlight", "glowStyle", "helperMode", "interrupts", "defensives", "helperCooldowns", "helperTint",
      "helperIdle", "keyIdle", "fadeAlpha", "keyIcons", "helperIcons", "minimapButton",
      "talentAutoLearn", "talentGlow", "talentReminders", "talentButton", "prePull", "trainerReminder" }) do
    check(reg.settings["Tactara_" .. v] ~= nil, "setting " .. v)
  end
  local function S(v) return reg.settings["Tactara_" .. v] end
  local function Btn(label) for _, i in ipairs(reg.inits) do if i.button == label then return i.fn end end end
  -- key rows show the key they're set to, and update while the page is open
  local function Init(label) for _, i in ipairs(reg.inits) do if i.button == label then return i end end end
  TactaraCharDB.binds = {}
  local wasCombat = inCombat
  ns.Options.OnKeysChanged()
  local row = RowFrame()
  Init("One-button key"):InitFrame(row)
  check(row.Button.text == "F (Keybindings)", "main key row shows the Keybindings-menu key (" .. row.Button.text .. ")")
  local aoeRow = RowFrame()
  Init("AoE key"):InitFrame(aoeRow)
  check(aoeRow.Button.text == "Not set (click)", "unset key row says so (" .. aoeRow.Button.text .. ")")
  inCombat = false
  ns.SetTactaraKey("aoe", "G")
  check(aoeRow.Button.text == "G", "setting a key updates the open page (" .. aoeRow.Button.text .. ")")
  Init("Interrupt key"):InitFrame(aoeRow)          -- the list reused that frame for another row
  ns.SetTactaraKey("aoe", "H")
  check(aoeRow.Button.text ~= "H", "a reused row frame isn't overwritten")
  local again = RowFrame()
  Init("AoE key"):InitFrame(again)
  check(again.Button.text == "H", "reopening the page shows the new key")
  Btn("Give keys back")()
  check(row.Button.text == "F (Keybindings)", "giving keys back refreshes the rows")
  inCombat = wasCombat

  local headers = 0
  for _, i in ipairs(reg.inits) do if i.header then headers = headers + 1 end end
  check(headers == 8, "eight sections on the page (" .. headers .. ")")

  S("showHelper"):SetValue(false)
  check(TactaraCharDB.showHelper == false and not ns.helperPopup:IsShown(), "unticking the helper hides it")
  S("showHelper"):SetValue(true)
  check(TactaraCharDB.showHelper == true, "ticking the helper shows it")
  S("helperScale"):SetValue(1.5)
  check(ns.helperPopup:GetScale() == 1.5 and TactaraCharDB.helperScale == 1.5, "helper size slider")
  check(TactaraCharDB.helperPos and math.abs(TactaraCharDB.helperPos.x - 10 / 1.5) < 0.01, "resizing keeps the popup in place")
  Btn("Positions")()
  check(TactaraCharDB.helperScale == 1 and ns.helperPopup:GetScale() == 1, "reset puts the size back")
  S("keyIdle"):SetValue("hide")
  check(TactaraCharDB.keyIdle == "hide", "key bar between-fights dropdown")
  S("fadeAlpha"):SetValue(0.6)
  check(TactaraCharDB.fadeAlpha == 0.6, "see-through slider")
  S("keyIdle"):SetValue("show"); S("fadeAlpha"):SetValue(0.45)
  local iconOpts
  for _, i in ipairs(reg.inits) do if i.kind == "dropdown" and i.s == S("keyIcons") then iconOpts = i.opts() end end
  check(iconOpts and #iconOpts == 11 and iconOpts[1].value == 1 and iconOpts[11].value == 0, "icon count choices: 1-10 and all")
  S("keyIcons"):SetValue(0)
  check(TactaraCharDB.keyIcons == 0, "key bar icons dropdown")
  S("keyIcons"):SetValue(3)

  local opts
  for _, i in ipairs(reg.inits) do if i.kind == "dropdown" and i.s == S("active") then opts = i.opts() end end
  check(opts and opts[1].value == "auto" and #opts >= 4, "rotation list: automatic + your class's rotations")
  S("active"):SetValue("Warrior - Fury"); runTimers()
  check(TactaraCharDB.active == "Warrior - Fury" and ns.activeName == "Warrior - Fury", "picking a rotation in settings")
  S("active"):SetValue("auto"); runTimers()
  check(TactaraCharDB.active == "auto", "back to automatic")

  S("glowStyle"):SetValue("subtle")
  check(TactaraDB.glowStyle == "subtle", "glow strength from settings")
  S("glowStyle"):SetValue("strong")
  S("keyDown"):SetValue(false)
  check(TactaraCharDB.keyDown == false and ns.useKeyDown == false, "key-up from settings")
  S("keyDown"):SetValue(true)
  check(TactaraCharDB.keyDown == nil and ns.useKeyDown == true, "key-down back on")
  S("interrupts"):SetValue(false)
  check(TactaraCharDB.interrupts == false, "interrupt suggestions off")
  S("interrupts"):SetValue(true)

  ns.Options.Open()
  check(reg.opened == 42, "Options.Open opens the page")
  reg.opened = nil
  SlashCmdList.TACTARA("options")
  check(reg.opened == 42, "/tac options opens the page")
  local realShow, shown = ns.Editor.Show, false
  ns.Editor.Show = function() shown = true end
  Btn("Rotation editor")()
  ns.Editor.Show = realShow
  check(shown, "editor button opens the editor")

  -- a client missing part of the API gets the plain command list instead
  local before = ns.Options
  local fresh = assert(loadfile(root .. "/Options.lua"))
  fresh("Tactara", ns)
  Settings.CreateSlider = nil
  reg.cats = {}
  ns.Options.Register()
  check(#reg.cats == 1 and reg.cats[1].canvas ~= nil, "fallback page when the settings API is incomplete")
  ns.Options = before
  Settings = nil
end

-- minimap addon-menu entry
do
  check(type(Tactara_OnAddonCompartmentClick) == "function", "addon menu click handler exists")
  local okE = pcall(Tactara_OnAddonCompartmentEnter, nil, UIParent)
  local okL = pcall(Tactara_OnAddonCompartmentLeave)
  local opened = false
  local realOpen = ns.Options.Open
  ns.Options.Open = function() opened = true end
  Tactara_OnAddonCompartmentClick(nil, "RightButton")
  ns.Options.Open = realOpen
  check(okE and okL and opened, "addon menu: tooltip and right-click opens settings")
end

-- minimap button
do
  local b = frames.TactaraMinimapButton
  check(b ~= nil and b:IsShown(), "minimap button made at login and shown")
  check(TactaraCharDB.minimapButton == true and TactaraCharDB.minimapAngle == 225, "minimap defaults: on, lower left")
  local function near(a, b2) return math.abs(a - b2) < 0.01 end
  -- Minimap is 100 wide in the stubs: round radius 55
  local x, y = ns.MinimapButtonOffset(0, "ROUND", 100, 100)
  check(near(x, 55) and near(y, 0), "round minimap, angle 0: right edge")
  x, y = ns.MinimapButtonOffset(90, "ROUND", 100, 100)
  check(near(x, 0) and near(y, 55), "round minimap, angle 90: top")
  x, y = ns.MinimapButtonOffset(45, "SQUARE", 100, 100)
  local d = (math.sqrt(2 * 55 * 55) - 10) * math.cos(math.rad(45))
  check(near(x, d) and near(y, d) and x > 55 * math.cos(math.rad(45)), "square minimap pushes the button toward the corner")
  x, y = ns.MinimapButtonOffset(0, "SQUARE", 100, 100)
  check(near(x, 55) and near(y, 0), "square minimap, angle 0: still on the edge")
  x, y = ns.MinimapButtonOffset(135, "CORNER-TOPLEFT", 100, 100)
  check(near(x, -55 * math.cos(math.rad(45))), "corner shape: its round quarter stays round")
  x, y = ns.MinimapButtonOffset(315, "CORNER-TOPLEFT", 100, 100)
  check(x > 55 * math.cos(math.rad(45)) + 0.01, "corner shape: the square quarters are pushed out")
  x, y = ns.MinimapButtonOffset(135, "NOT-A-SHAPE", 100, 100)
  check(near(x, -55 * math.cos(math.rad(45))), "unknown shape counts as round")
  -- clicks
  local edited, opened = false, false
  local realToggle, realOpen = ns.Editor.Toggle, ns.Options.Open
  ns.Editor.Toggle = function() edited = true end
  ns.Options.Open = function() opened = true end
  b:GetScript("OnClick")(b, "LeftButton")
  b:GetScript("OnClick")(b, "RightButton")
  ns.Editor.Toggle, ns.Options.Open = realToggle, realOpen
  check(edited and opened, "minimap button: left-click editor, right-click settings")
  check(pcall(b:GetScript("OnEnter"), b) and pcall(b:GetScript("OnLeave"), b), "minimap button tooltip")
  -- drag: cursor straight above the minimap's center = 90 degrees
  b:GetScript("OnDragStart")(b)
  check(b.dragging and b:GetScript("OnUpdate") ~= nil, "drag starts following the cursor")
  cursorX, cursorY = 500, 600
  b:GetScript("OnUpdate")(b)
  check(TactaraCharDB.minimapAngle == 90, "dragging above the minimap: angle 90 (" .. tostring(TactaraCharDB.minimapAngle) .. ")")
  cursorX, cursorY = 400, 500
  b:GetScript("OnUpdate")(b)
  check(TactaraCharDB.minimapAngle == 180, "dragging left: angle 180")
  b:GetScript("OnDragStop")(b)
  check(not b.dragging and b:GetScript("OnUpdate") == nil, "drag stops")
  -- show / hide / reset
  SlashCmdList.TACTARA("minimap")
  check(TactaraCharDB.minimapButton == false and not b:IsShown(), "/tac minimap hides it")
  SlashCmdList.TACTARA("minimap")
  check(TactaraCharDB.minimapButton == true and b:IsShown(), "/tac minimap shows it again")
  SlashCmdList.TACTARA("minimap reset")
  check(TactaraCharDB.minimapAngle == 225 and b:IsShown(), "/tac minimap reset")
  -- the addon menu entry uses the same tooltip
  local lines = {}
  local realAdd = GameTooltip.AddLine
  GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
  Tactara_OnAddonCompartmentEnter(nil, UIParent)
  GameTooltip.AddLine = realAdd
  check(lines[1] == "Tactara " .. ns.VERSION and #lines == 5 and lines[5] == "Shift-click: talent planner", "addon menu tooltip (no drag line)")
end

-- every class gets its own rotation picked and built without errors
do
  local realClass = UnitClass
  local NAMES = { PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest", SHAMAN = "Shaman",
    MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid", WARRIOR = "Warrior" }
  local saved = TactaraCharDB.active
  TactaraCharDB.active = "auto"
  for token, label in pairs(NAMES) do
    UnitClass = function() return label, token, 1 end
    local ok, err = pcall(ns.Rebuild, "class test")
    check(ok, token .. " rebuild: " .. tostring(err))
    check(ns.activeName and ns.activeName:find("^" .. label .. " %- ") ~= nil, token .. " picks a " .. label .. " rotation (" .. tostring(ns.activeName) .. ")")
    local okH, errH = pcall(ns.HelperRefresh)
    check(okH, token .. " helper refresh: " .. tostring(errH))
  end
  UnitClass = realClass
  TactaraCharDB.active = saved
  ns.Rebuild("back to warrior")
end

-- fallback when BasicFrameTemplateWithInset is missing (older/odd clients)
print("\nchat sample:"); for i = 1, math.min(#chat, 8) do print("  " .. chat[i]) end
print(fails == 0 and "\nSMOKE TEST PASSED" or ("\n" .. fails .. " FAILURE(S)"))
os.exit(fails == 0 and 0 or 1)
