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
  "Highlight", "Start", "Stop", "Play", "Add", "Hook", "Unregister", "Click", "Disable", "Toggle", "Raise", "Lower", "Has", "Insert" }

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
    GetFrameLevel = function() return 5 end,
    IsVisible = function(self) return self._shown end,
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
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(chat, m) end }
C_Timer = { After = function(d, f) table.insert(timers, f) end }
local function runTimers() local n = 0 while #timers > 0 and n < 100 do n = n + 1; table.remove(timers, 1)() end end
function InCombatLockdown() return inCombat end
function UnitClass() return "Warrior", "WARRIOR", 1 end
function GetCVarBool(k) if k == "ActionButtonUseKeyDown" then return cvarKeyDown end end
now = 1000
function GetTime() return now end
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
-- Helper / bar highlight tests
---------------------------------------------------------------------------
local IDS = { ["Heroic Strike"] = 78, Rend = 772, Charge = 100, ["Battle Shout"] = 6673, Overpower = 7384,
  Execute = 5308, Slam = 1464, Bloodrage = 2687, ["Victory Rush"] = 34428, ["Sunder Armor"] = 7386,
  ["Thunder Clap"] = 6343, ["Battle Stance"] = 2457, Cleave = 845, Hamstring = 1715,
  Pummel = 6552, ["Shield Bash"] = 72, Retaliation = 20230, ["Concussion Blow"] = 12809, ["Shield Wall"] = 871 }
local NAMES = {}
for n, id in pairs(IDS) do NAMES[id] = n end
C_Spell.GetSpellName = function(id) return NAMES[id] end
C_Spell.GetSpellTexture = function(name) return "icon:" .. tostring(name) end

local cooldowns, usable = {}, {}
C_Spell.GetSpellCooldown = function(name)
  if cooldowns[name] == "hidden" then
    return setmetatable({}, { __index = function() error("secret value") end })
  end
  return cooldowns[name] or { isActive = false, isOnGCD = false, startTime = 0, duration = 0 }
end
C_Spell.IsSpellUsable = function(name)
  local u = usable[name]
  if u == "hidden" then error("secret value") end
  if u == nil then return true, false end
  return u[1], u[2]
end
local hasTarget = false
local nameplates = 0
local playerAuras, targetAuras = {}, {}
function UnitExists(u)
  if u == "target" then return hasTarget end
  local n = u and tonumber(u:match("^nameplate(%d+)$"))
  return n ~= nil and n <= nameplates
end
function UnitCanAttack() return true end
function UnitIsDead() return false end
C_UnitAuras.GetAuraDataBySpellName = function(unit, name, filter)
  local t = (unit == "player") and playerAuras or targetAuras
  local a = t[name]
  if a == "hidden" then error("secret value") end
  return a
end

-- action bars: slots 1-9 on ActionButton1-9, a macro on slot 8, a Bartender button on slot 20
local actionSlots = {
  [1] = { "spell", 78 }, [2] = { "spell", 772 }, [3] = { "spell", 7384 }, [4] = { "spell", 1464 },
  [5] = { "spell", 100 }, [6] = { "spell", 6673 }, [7] = { "spell", 5308 }, [8] = { "macro", 3 },
  [9] = { "spell", 2687 }, [20] = { "spell", 78 },
}
function GetActionInfo(slot) local a = actionSlots[slot]; if a then return a[1], a[2] end end
function GetMacroSpell(i) if i == 3 then return 34428 end end
for i = 1, 12 do local b = CreateFrame("CheckButton", "ActionButton" .. i); b.action = i end
local bt = CreateFrame("CheckButton", "BT4Button1"); bt._state_type = "action"; bt._state_action = 20

for _, s in ipairs({ "Battle Stance", "Battle Shout", "Heroic Strike", "Rend", "Charge", "Thunder Clap", "Hamstring",
  "Bloodrage", "Sunder Armor", "Overpower", "Victory Rush", "Slam", "Execute", "Cleave" }) do known[s] = true end
fire("ADDON_LOADED", "Tactara")
fire("PLAYER_LOGIN")
SlashCmdList.TACTARA("use arms"); runTimers()
SlashCmdList.TACTARA("helper sequence")
local H = ns.Helper
local function litNames()
  local out = {}
  for btn in pairs(H.lit) do out[#out + 1] = btn:GetName() end
  table.sort(out)
  return table.concat(out, ",")
end
local function tick() ns.HelperRefresh() end

-- 1) nothing to suggest without an enemy target out of combat
tick()
check(ns.lastHighlight == nil and litNames() == "", "no glow without a target")

-- 2) target an enemy: the pull (Charge) glows on its button
hasTarget = true; tick()
check(ns.lastHighlight == "Charge" and litNames() == "ActionButton5", "pull glow on Charge: " .. litNames())
check(H.glows[_G.ActionButton5]._shown, "glow frame shown")

-- 3) Charge on cooldown -> opener step 1 (Bloodrage > Battle Shout)
cooldowns["Charge"] = { isActive = true, isOnGCD = false }
tick()
check(ns.lastHighlight == "Bloodrage" and litNames() == "ActionButton9", "Charge on cd -> Bloodrage: " .. tostring(ns.lastHighlight))
check(not H.glows[_G.ActionButton5]._shown, "old glow hidden")
cooldowns["Charge"] = nil

-- 4) combat + manual casts move the helper along
inCombat = true; now = now + 5
tick()
check(ns.lastHighlight == "Bloodrage", "combat start: opener step 1")
local evf = ns.helperFrame
evf._scripts.OnEvent(evf, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", IDS.Bloodrage)
check(H.idx == 2 and ns.lastHighlight == "Rend", "after Bloodrage -> Rend, got idx " .. H.idx .. " " .. tostring(ns.lastHighlight))
evf._scripts.OnEvent(evf, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", IDS.Rend)
check(H.idx == 3, "after Rend -> loop start")
local comp = ns.compiled.main
print("loop step 3: " .. comp.steps[3].label)

-- 5) inside a step: skip unusable fallbacks
usable["Overpower"] = { false, false }        -- no dodge
usable["Execute"] = { false, false }          -- target above 20%
tick()
check(ns.lastHighlight == "Slam", "no Overpower proc, no Execute -> Slam, got " .. tostring(ns.lastHighlight))
usable["Overpower"] = nil
tick()
check(ns.lastHighlight == "Overpower", "Overpower proc -> Overpower")
check(_G.ActionButton3 and litNames() == "ActionButton3", "glow on Overpower button")

-- 6) not enough rage still points at the right button
usable["Overpower"] = { false, true }
tick()
check(ns.lastHighlight == "Overpower", "waiting on Rage keeps Overpower highlighted")
usable["Overpower"] = nil

-- 7) global cooldown doesn't count as a cooldown
cooldowns["Overpower"] = { isActive = true, isOnGCD = true }
tick()
check(ns.lastHighlight == "Overpower", "GCD ignored")
-- 8) real cooldown skips to the next fallback
cooldowns["Overpower"] = { isActive = true, isOnGCD = false }
usable["Execute"] = { false, false }
tick()
check(ns.lastHighlight == "Slam", "Overpower on cooldown -> Slam")
cooldowns["Overpower"] = nil; usable["Execute"] = nil

-- 9) hidden values (restricted fights): fall back to the step's first spell
cooldowns["Overpower"] = "hidden"; usable["Overpower"] = "hidden"
tick()
check(ns.lastHighlight == "Overpower", "hidden cooldown/usable -> rotation order")
cooldowns["Overpower"] = nil; usable["Overpower"] = nil

-- 10) a manual cast of a later step jumps ahead
local before = H.idx
local target
for k = 1, 3 do
  local i = before
  for _ = 1, k do i = ns.NextStepIdx(comp, i) end
  if comp.steps[i].spells[1] == "Victory Rush" then target = i end
end
evf._scripts.OnEvent(evf, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", IDS["Victory Rush"])
if target then
  check(H.idx == ns.NextStepIdx(comp, target), "jumped past the Victory Rush step")
else
  print("(Victory Rush not within lookahead from step " .. before .. ")")
end
-- macro button (slot 8) found for Victory Rush
local vr = ns.ButtonsForSpell("Victory Rush")
check(#vr == 1 and vr[1] == _G.ActionButton8, "spell inside a macro is found on the bar")
-- Bartender button found for Heroic Strike
local hs = ns.ButtonsForSpell("Heroic Strike")
local names = {}
for _, b in ipairs(hs) do names[#names + 1] = b:GetName() end
table.sort(names)
check(table.concat(names, ",") == "ActionButton1,BT4Button1", "Blizzard + Bartender buttons: " .. table.concat(names, ","))

-- 11) a cast that isn't in the next steps doesn't move anything
local idxBefore = H.idx
evf._scripts.OnEvent(evf, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", IDS["Hamstring"])
check(H.idx == idxBefore, "unrelated cast ignored")

-- 12) Tactara key press syncs to the button and swallows its own cast event
local main = frames.TactaraMainButton
click(main, true)
check(H.idx == main._attrs.idx, "helper follows the Tactara button")
local afterPress = H.idx
evf._scripts.OnEvent(evf, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", IDS.Slam)
check(H.idx == afterPress, "cast right after a Tactara press doesn't double-advance")

-- 13) stance swap re-pages the bar: glow follows the spell to its new button
now = now + 5
H.idx = 3; usable["Execute"] = { false, false }
tick()
local spellNow = ns.lastHighlight
local oldBtn = litNames()
-- move that spell to slot 11
for slot, a in pairs(actionSlots) do if a[1] == "spell" and NAMES[a[2]] == spellNow then actionSlots[slot] = nil end end
actionSlots[11] = { "spell", IDS[spellNow] }
evf._scripts.OnEvent(evf, "UPDATE_SHAPESHIFT_FORM")
check(litNames() == "ActionButton11", "after stance page swap: " .. oldBtn .. " -> " .. litNames())

-- 14) key bar shows the key's next press; helper popup shows the best priority pick
check(ns.display.icons[1]._texture == "icon:" .. ns.KeyQueue(1)[1], "key bar icon 1 = key's next press")
check(ns.helperPopup.icons[1].tex._texture == "icon:" .. ns.HelperQueue(1, true, "priority")[1], "popup icon 1 = best priority pick")

-- 15) highlight off -> glows cleared
SlashCmdList.TACTARA("highlight")
check(litNames() == "" and ns.lastHighlight == nil, "/tac highlight off clears glows")
SlashCmdList.TACTARA("highlight")
check(litNames() ~= "", "/tac highlight on again")

-- 15b) glow strength + preview
local g1 = H.glows[next(H.lit)]
check(g1 and g1.style == "strong" and #g1.parts == 13, "default glow is strong: 2 halo rings + border + tint = 13 parts, got " .. tostring(g1 and #g1.parts))
local pendingBefore = #timers
SlashCmdList.TACTARA("glow subtle")
check(TactaraDB.glowStyle == "subtle", "/tac glow subtle saved")
local kinds = {}
for btn, kind in pairs(H.lit) do kinds[#kinds + 1] = kind; check(H.glows[btn].style == "subtle", "preview uses the new style") end
table.sort(kinds)
check(table.concat(kinds, ",") == "defensive,interrupt,next", "preview shows all three colors: " .. table.concat(kinds, ","))
tick()
check(#kinds == 3 and ns.previewing, "preview isn't overwritten by the tick")
runTimers()
check(not ns.previewing, "preview ends after its timer")
local g2 = H.glows[next(H.lit)]
check(g2 and g2.style == "subtle" and #g2.parts == 5, "subtle glow: border + tint only, got " .. tostring(g2 and #g2.parts))
chat = {}
SlashCmdList.TACTARA("glow sparkly")
check(table.concat(chat):find("Glow styles"), "unknown style explains the options")
SlashCmdList.TACTARA("glow strong")
runTimers()
check(H.glows[next(H.lit)].style == "strong", "back to strong")

-- 16) combat ends: back to the start, glow goes to Charge (target still up)
inCombat = false
fire("PLAYER_REGEN_ENABLED")
tick()
check(H.idx == 1 and ns.lastHighlight == "Charge", "after combat: reset, Charge glows")

-- 17) diagnostics mention the highlight
chat = {}
SlashCmdList.TACTARA("test")
check(table.concat(chat, "\n"):find("bar highlight ON %(%a[%a ]+%) | timers: .- | %d+ action buttons found | now pointing at: Charge"), "diagnostics line: " .. table.concat(chat, "\n"))

-- 18) /tac probe runs in and out of combat, with missing and present APIs
function GetNumTalentTabs() return 3 end
function GetTalentTabInfo(i) return i, ({ "Arms", "Fury", "Protection" })[i], "", 0, ({ 5, 0, 0 })[i] end
function UnitPower() return 12 end
function UnitHealth() return 40 end
function UnitHealthMax() return 100 end
issecretvalue = function(v) return v == "SECRET" end
targetAuras["Rend"] = { expirationTime = "SECRET", duration = 21 }
for _, combat in ipairs({ false, true }) do
  inCombat = combat
  chat = {}
  local okP, eP = pcall(SlashCmdList.TACTARA, "probe")
  check(okP, "/tac probe runs (combat=" .. tostring(combat) .. "): " .. tostring(eP))
  local out = table.concat(chat, "\n")
  check(out:find("talents %(Tactara reader%)") and out:find("talent layout"), "probe shows talent reader + layout")
  check(out:find("no such API"), "probe reports missing APIs")
  check(out:find("Rend on target: |cffff5555HIDDEN"), "probe flags hidden values")
  if combat then print("\nprobe sample:\n" .. out) end
end
inCombat = false
targetAuras["Rend"] = nil

---------------------------------------------------------------------------
-- 19) priority mode (best spell right now)
---------------------------------------------------------------------------
SlashCmdList.TACTARA("helper priority")
inCombat = true; hasTarget = true; nameplates = 1; now = now + 60   -- let earlier Rend/Battle Shout timers run out
for k in pairs(cooldowns) do cooldowns[k] = nil end
for k in pairs(usable) do usable[k] = nil end
local function pick() ns.HelperRefresh(); return ns.lastHighlight end
check(pick() == "Battle Shout", "Battle Shout missing -> top priority, got " .. tostring(pick()))
playerAuras["Battle Shout"] = { expirationTime = now + 100, duration = 120 }
check(pick() == "Bloodrage", "Battle Shout up -> Bloodrage")
playerAuras["Battle Shout"] = { expirationTime = now + 2, duration = 120 }
check(pick() == "Battle Shout", "Battle Shout about to expire -> refresh it")
playerAuras["Battle Shout"] = { expirationTime = now + 100, duration = 120 }
cooldowns["Bloodrage"] = { isActive = true, isOnGCD = false }
check(pick() == "Overpower", "1 enemy: skip AoE lines -> Overpower, got " .. tostring(pick()))
nameplates = 3
check(pick() == "Thunder Clap", "3 enemies -> Thunder Clap, got " .. tostring(pick()))
nameplates = 1
usable["Overpower"] = { false, false }
usable["Execute"] = { false, false }
usable["Victory Rush"] = { false, false }
check(pick() == "Rend", "Rend not on target -> Rend, got " .. tostring(pick()))
targetAuras["Rend"] = { expirationTime = now + 15, duration = 21 }
check(pick() == "Slam", "Rend up -> Slam, got " .. tostring(pick()))
usable["Slam"] = { false, true }
check(pick() == "Heroic Strike", "ready spell beats one waiting on Rage, got " .. tostring(pick()))
usable["Heroic Strike"] = { false, true }
check(pick() == "Slam", "everything waiting on Rage -> best of those, got " .. tostring(pick()))
usable["Slam"] = nil; usable["Heroic Strike"] = nil
-- hidden auras: lines that need them are skipped, not guessed
playerAuras["Battle Shout"] = "hidden"; targetAuras["Rend"] = "hidden"
check(pick() == "Slam", "hidden auras -> skip those lines, got " .. tostring(pick()))
playerAuras["Battle Shout"] = { expirationTime = now + 100, duration = 120 }; targetAuras["Rend"] = nil
-- 19b) own timers when the game won't report buffs/debuffs (Forever's behaviour)
local savedAuraFn = C_UnitAuras.GetAuraDataBySpellName
C_UnitAuras.GetAuraDataBySpellName = function() return nil end   -- lookup comes back empty
now = now + 200
check(pick() == "Battle Shout", "no info, no timer -> Battle Shout")
evf._scripts.OnEvent(evf, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", IDS["Battle Shout"])
check(pick() ~= "Battle Shout", "after casting Battle Shout it drops off (timer), got " .. tostring(pick()))
now = now + 118
check(pick() == "Battle Shout", "timer about to run out -> refresh Battle Shout")
evf._scripts.OnEvent(evf, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", IDS["Battle Shout"])
check(pick() == "Rend", "next up: Rend, got " .. tostring(pick()))
evf._scripts.OnEvent(evf, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", IDS.Rend)
check(pick() == "Slam", "after casting Rend it drops off, got " .. tostring(pick()))
-- unreadable target IDs: a new target clears the Rend timer
ns.trackerFrame._scripts.OnEvent(ns.trackerFrame, "PLAYER_TARGET_CHANGED")
check(pick() == "Rend", "new target -> Rend again")
-- readable target IDs: timers stick to each target
local guid = "Creature-A"
function UnitGUID(u) if u == "target" then return guid end end
evf._scripts.OnEvent(evf, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", IDS.Rend)
check(pick() == "Slam", "Rend on A")
guid = "Creature-B"; ns.trackerFrame._scripts.OnEvent(ns.trackerFrame, "PLAYER_TARGET_CHANGED")
check(pick() == "Rend", "B has no Rend")
guid = "Creature-A"; ns.trackerFrame._scripts.OnEvent(ns.trackerFrame, "PLAYER_TARGET_CHANGED")
check(pick() == "Slam", "back on A: Rend still ticking")
-- a cast that isn't a buff/debuff check isn't tracked
evf._scripts.OnEvent(evf, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", IDS["Heroic Strike"])
check(not ns.TrackerSummary():find("Heroic Strike"), "Heroic Strike not tracked")
print("timers: " .. ns.TrackerSummary())
-- the game's real answer wins and teaches the real duration
C_UnitAuras.GetAuraDataBySpellName = function(unit, name)
  if name == "Battle Shout" then return { expirationTime = now + 50, duration = 90 } end
end
check(pick() ~= "Battle Shout", "game says Battle Shout is up")
C_UnitAuras.GetAuraDataBySpellName = function() return nil end
now = now + 200
evf._scripts.OnEvent(evf, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", IDS["Battle Shout"])
now = now + 88
check(pick() == "Battle Shout", "learned 90s duration: refresh at 88s")
-- out of combat the opener skips Battle Shout while our timer has time left
evf._scripts.OnEvent(evf, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", IDS["Battle Shout"])
inCombat = false; fire("PLAYER_REGEN_ENABLED")
check(not frames.TactaraMainButton._attrs.step1:find("Battle Shout"), "opener skips Battle Shout (timer)")
inCombat = true
C_UnitAuras.GetAuraDataBySpellName = savedAuraFn
UnitGUID = nil
now = now + 200
playerAuras["Battle Shout"] = { expirationTime = now + 100, duration = 120 }
targetAuras["Rend"] = nil

-- helper popup shows the top 3
ns.UpdateHelperPopup()
local strip = {}
for i = 1, 3 do strip[i] = ns.helperPopup.icons[i].tex._texture end
check(strip[1] == "icon:Rend", "strip 1 = best pick: " .. tostring(strip[1]))
check(strip[2] ~= strip[1] and strip[2] ~= nil, "strip 2 = next best: " .. tostring(strip[2]))
print("priority strip: " .. table.concat(strip, ", "))
-- auto mode: the key's sequence while pressing, priority after a pause
SlashCmdList.TACTARA("helper auto")
check(ns.HelperUsesPriority(ns.compiled.main), "auto mode idles on the priority list")
click(frames.TactaraMainButton, true)
check(not ns.HelperUsesPriority(ns.compiled.main), "auto mode follows the key right after a press")
now = now + 4
check(ns.HelperUsesPriority(ns.compiled.main), "back to priority after a few seconds")
for k in pairs(usable) do usable[k] = nil end
inCombat = false; fire("PLAYER_REGEN_ENABLED")

---------------------------------------------------------------------------
-- 20) reading the build: weapons, then talents
---------------------------------------------------------------------------
SlashCmdList.TACTARA("use auto"); runTimers()
local items = { [16] = 1001 }
local EQUIP = { [1001] = "INVTYPE_2HWEAPON", [1002] = "INVTYPE_WEAPON", [1003] = "INVTYPE_SHIELD", [1004] = "INVTYPE_WEAPONMAINHAND" }
function GetInventoryItemID(_, slot) return items[slot] end
C_Item = { GetItemInfoInstant = function(id) return id, "Weapon", "x", EQUIP[id] end }
dualWield = false
function IsDualWielding() return dualWield end
known["Defensive Stance"] = true; known["Revenge"] = true
fire("PLAYER_EQUIPMENT_CHANGED")
check(ns.activeName == "Warrior - Arms" and ns.activeWhy == "your two-hander", "two-hander -> Arms: " .. tostring(ns.activeWhy))
items = { [16] = 1004, [17] = 1003 }
fire("PLAYER_EQUIPMENT_CHANGED")
check(ns.activeName == "Warrior - Protection" and ns.activeWhy == "your shield", "shield -> Protection: " .. tostring(ns.activeName))
items = { [16] = 1002, [17] = 1002 }; dualWield = true
fire("PLAYER_EQUIPMENT_CHANGED")
check(ns.activeName == "Warrior - Fury" and ns.activeWhy == "your dual wield", "dual wield -> Fury: " .. tostring(ns.activeName))

-- talents via C_Traits: three trees, points decide
local TREES = {
  [11] = { { "Improved Heroic Strike", 0 }, { "Deep Wounds", 0 }, { "Mortal Strike", 0 }, { "Tactical Mastery", 0 } },
  [12] = { { "Cruelty", 0 }, { "Improved Slam", 0 }, { "Death Wish", 0 }, { "Bloodthirst", 0 } },
  [13] = { { "Shield Specialization", 0 }, { "Last Stand", 0 }, { "Shield Slam", 0 }, { "Defiance", 0 } },
}
local nodeIndex = {}
local function setupTraits(trees, subTrees)
  local nid = 0
  nodeIndex = {}
  local treeNodes = {}
  for treeID, list in pairs(trees) do
    treeNodes[treeID] = {}
    for i, t in ipairs(list) do
      nid = nid + 1
      nodeIndex[nid] = { name = t[1], rank = t[2], tree = treeID, x = (treeID - 11) * 1000 + i * 10 }
      table.insert(treeNodes[treeID], nid)
    end
  end
  C_ClassTalents = { GetActiveConfigID = function() return 4545363 end }
  C_Traits = {
    GetConfigInfo = function() local ids = {}; for id in pairs(treeNodes) do ids[#ids + 1] = id end; table.sort(ids); return { treeIDs = ids } end,
    GetTreeNodes = function(treeID) return treeNodes[treeID] end,
    GetNodeInfo = function(_, nodeID)
      local n = nodeIndex[nodeID]
      return { ID = nodeID, ranksPurchased = n.rank, entryIDs = { nodeID }, posX = n.x,
        subTreeID = subTrees and (n.tree) or nil }
    end,
    GetEntryInfo = function(_, entryID) return { definitionID = entryID } end,
    GetDefinitionInfo = function(defID) return { overrideName = nodeIndex[defID].name } end,
  }
end
TREES[11][2][2] = 5; TREES[11][4][2] = 5         -- 10 points in Arms
TREES[13][1][2] = 3                             -- 3 in Protection
setupTraits(TREES)
fire("TRAIT_CONFIG_UPDATED")
check(ns.activeName == "Warrior - Arms" and ns.activeWhy == "10 talent points in Arms", "talents beat weapon: " .. tostring(ns.activeName) .. " / " .. tostring(ns.activeWhy))
-- single combined tree (all tabs in one), split by position
local merged = { [11] = {} }
for _, id in ipairs({ 11, 12, 13 }) do for _, t in ipairs(TREES[id]) do table.insert(merged[11], { t[1], t[2] }) end end
TREES[13][1][2] = 3; TREES[13][2][2] = 5; TREES[13][4][2] = 5
merged = { [11] = {} }
for _, id in ipairs({ 11, 12, 13 }) do for _, t in ipairs(TREES[id]) do table.insert(merged[11], { t[1], t[2] }) end end
setupTraits(merged)
for nid, n in pairs(nodeIndex) do n.x = nid * 10 end   -- 12 nodes left to right: Arms | Fury | Prot
fire("TRAIT_CONFIG_UPDATED")
check(ns.activeName == "Warrior - Protection", "one combined tree split into columns: " .. tostring(ns.activeName) .. " / " .. tostring(ns.activeWhy))
chat = {}
SlashCmdList.TACTARA("build")
local b = table.concat(chat, "\n")
check(b:find("weapon: dual") and b:find("Arms 10") and b:find("Protection 13") and b:find("Warrior %- Protection"), "/tac build summary: " .. b)
print("\n" .. b)
-- manual choice still wins
SlashCmdList.TACTARA("use fury"); runTimers()
check(ns.activeName == "Warrior - Fury", "manual choice beats auto-pick")
-- probe with the talent + gear APIs present
chat = {}
local okP2, eP2 = pcall(SlashCmdList.TACTARA, "probe")
local p2 = table.concat(chat, "\n")

check(okP2 and p2:find("talents %(Tactara reader%): 3 trees, 12 talents, Arms 10 %/ Fury 0 %/ Protection 13") and p2:find("talent layout: config 4545363, 1 trees, 12 nodes"), "probe with talents: " .. p2)
check(p2:find("weapon %(Tactara reader%): dual") and p2:find("main hand / off hand: INVTYPE_WEAPON, INVTYPE_WEAPON"), "probe gear")
-- talent API missing -> falls back cleanly
C_ClassTalents = nil
SlashCmdList.TACTARA("use auto"); runTimers()
check(ns.activeName == "Warrior - Fury", "no talent API: weapon decides (dual -> Fury), got " .. tostring(ns.activeName))

---------------------------------------------------------------------------
-- 21) interrupts + defensives
---------------------------------------------------------------------------
SlashCmdList.TACTARA("use arms"); runTimers()
known["Pummel"] = true; known["Shield Bash"] = true; known["Retaliation"] = true
fire("SPELLS_CHANGED")
for i, sp in ipairs({ "Pummel", "Shield Bash", "Retaliation" }) do
  local b = CreateFrame("CheckButton", "MultiBarBottomLeftButton" .. i); b.action = 24 + i
  actionSlots[24 + i] = { "spell", IDS[sp] }
end
evf._scripts.OnEvent(evf, "ACTIONBAR_SLOT_CHANGED")
inCombat = true; hasTarget = true; nameplates = 1
for k in pairs(usable) do usable[k] = nil end
for k in pairs(cooldowns) do cooldowns[k] = nil end
local casting, channel, castHidden = nil, nil, false
function UnitCastingInfo(u)
  if castHidden then error("secret value") end
  if u == "target" and casting then return casting.name, "", "", 0, 0, false, 1, casting.locked end
end
function UnitChannelInfo(u)
  if u == "target" and channel then return channel.name, "", "", 0, 0, false, channel.locked end
end
local playerHP, hpHidden = 100, false
function UnitHealth(u) if u == "player" then if hpHidden then error("secret value") end return playerHP end return 40 end
function UnitHealthMax(u) return 100 end
local utilFrame = ns.utilityFrame

-- interrupt
check(frames.TactaraInterruptButton._attrs.step1 == "/cast Pummel\n/cast Shield Bash", "interrupt key macro: " .. tostring(frames.TactaraInterruptButton._attrs.step1))
tick()
check(ns.lastUtility.interrupt == nil and ns.lastUtility.castState == "none", "no cast -> no interrupt")
casting = { name = "Fireball", locked = false }
utilFrame._scripts.OnEvent(utilFrame, "UNIT_SPELLCAST_START", "target")
check(ns.lastUtility.interrupt == "Pummel", "interruptible cast -> Pummel, got " .. tostring(ns.lastUtility.interrupt))
check(H.lit[_G.MultiBarBottomLeftButton1] == "interrupt", "red glow on Pummel's button")
check(H.glows[_G.MultiBarBottomLeftButton1].kind == "interrupt", "glow colored red")
check(ns.helperPopup.interrupt:IsShown() and ns.helperPopup.interrupt.tex._texture == "icon:Pummel", "popup interrupt slot shows Pummel")
usable["Pummel"] = { false, false }            -- wrong stance
tick()
check(ns.lastUtility.interrupt == "Shield Bash", "Pummel not usable in this stance -> Shield Bash")
cooldowns["Shield Bash"] = { isActive = true, isOnGCD = false }
tick()
check(ns.lastUtility.interrupt == nil and not ns.helperPopup.interrupt:IsShown(), "both unavailable -> nothing")
usable["Pummel"] = nil; cooldowns["Shield Bash"] = nil
casting = { name = "Shadow Bolt", locked = true }
tick()
check(ns.lastUtility.castState == "uninterruptible" and ns.lastUtility.interrupt == nil, "uninterruptible cast ignored")
casting = nil; channel = { name = "Drain Life", locked = false }
tick()
check(ns.lastUtility.interrupt == "Pummel", "channel can be interrupted")
castHidden = true
tick()
check(ns.lastUtility.castState == "unknown" and ns.lastUtility.interrupt == nil, "hidden cast info -> no guess")
castHidden = false
SlashCmdList.TACTARA("interrupts off")
check(ns.lastUtility.interrupt == nil, "/tac interrupts off")
SlashCmdList.TACTARA("interrupts on")
channel = nil

-- defensive
playerHP = 40; nameplates = 3
tick()
check(ns.lastUtility.defensive == "Retaliation", "40% health, 3 enemies -> Retaliation, got " .. tostring(ns.lastUtility.defensive))
check(H.lit[_G.MultiBarBottomLeftButton3] == "defensive" and H.glows[_G.MultiBarBottomLeftButton3].kind == "defensive", "orange glow on Retaliation")
check(ns.helperPopup.defensive:IsShown(), "popup defensive slot shown")
nameplates = 1
tick()
check(ns.lastUtility.defensive == nil, "1 enemy -> Retaliation's check fails")
nameplates = 3; playerHP = 90
tick()
check(ns.lastUtility.defensive == nil, "healthy -> no defensive")
playerHP = 40; hpHidden = true
tick()
check(ns.lastUtility.defensive == nil, "health hidden -> no guess")
hpHidden = false
inCombat = false
tick()
check(ns.lastUtility.defensive == nil, "out of combat -> no defensive")
inCombat = true
SlashCmdList.TACTARA("defensives off")
check(ns.lastUtility.defensive == nil, "/tac defensives off")
SlashCmdList.TACTARA("defensives on")

-- interrupt key press doesn't move the rotation
local idxBefore2 = H.idx
local cast = click(frames.TactaraInterruptButton, true)
check(cast == "/cast Pummel\n/cast Shield Bash", "interrupt key casts its macro")
check(H.idx == idxBefore2 and ns.lastClicked ~= frames.TactaraInterruptButton, "interrupt key doesn't touch the sequence")
inCombat = true
SlashCmdList.TACTARA("bind interrupt")
check(frames.TactaraKeyCapture == nil or not frames.TactaraKeyCapture:IsShown(), "can't set keys in combat")
inCombat = false
SlashCmdList.TACTARA("bind interrupt")
frames.TactaraKeyCapture._scripts.OnKeyDown(frames.TactaraKeyCapture, "Q")
inCombat = true
check(overrides["Q"] == "TactaraInterruptButton", "/tac bind interrupt")

-- two displays, shown/hidden separately
SlashCmdList.TACTARA("hide helper")
check(not ns.helperPopup:IsShown() and ns.display:IsShown(), "hide helper keeps the key bar")
SlashCmdList.TACTARA("hide key")
check(not ns.display:IsShown(), "hide key")
SlashCmdList.TACTARA("show")
check(ns.helperPopup:IsShown() and ns.display:IsShown(), "show brings both back")

-- probe has the new lines
chat = {}
SlashCmdList.TACTARA("probe")
local p3 = table.concat(chat, "\n")
check(p3:find("YOUR health / max: 40, 100") and p3:find("Tactara reads target cast as: none"), "probe health + cast lines")
inCombat = false

print(fails == 0 and "\nHELPER TEST PASSED" or ("\n" .. fails .. " FAILURE(S)"))
os.exit(fails == 0 and 0 or 1)
