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
    SetChecked = function(self, v) self._checked = v and true or false end,
    GetChecked = function(self) return self._checked end,
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
    SetAlpha = function(self, a) self._alpha = a end,
    GetAlpha = function(self) return self._alpha or 1 end,
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

-- 14b) the display look: framed icons in Tactara's cyan, or just the icons
do
  local S = ns.Style
  local pop, bar = ns.helperPopup, ns.display
  local function edges(h) return h.edges.thickness, h.edges.color end
  check(S.Brand("Tactara") == "|cff4fc3f7Tactara|r" and ns.GLOW_COLORS.next == S.BRAND, "one accent: chat prefix, glow and frames")
  check(TactaraCharDB.displayStyle == "standard" and S.Look() == "standard", "standard look by default")
  local t, c = edges(pop.icons[1])
  check(t == 2 and c == S.BRAND, "best spell now: a cyan frame")
  t, c = edges(pop.icons[2])
  check(t == 1 and c == S.DARK, "the ones after it: a thin dark frame")
  t, c = edges(pop.interrupt)
  check(t == 2 and c == ns.GLOW_COLORS.interrupt and pop.interrupt.tag:IsShown() and pop.interrupt.tag:GetText() == "INTERRUPT"
    and pop.interrupt.tag.captionColor == ns.GLOW_COLORS.interrupt, "interrupt slot: red frame, red caption")
  t, c = edges(pop.defensive)
  check(t == 2 and c == ns.GLOW_COLORS.defensive and pop.defensive.tag:GetText() == "DEFENSIVE", "defensive slot: orange")
  t, c = edges(bar.icons[1])
  check(t == 2 and c == S.BRAND and bar.icons[1].edges:IsShown(), "key bar: next press framed in cyan")
  check(edges(bar.icons[2]) == 1, "key bar: the rest thin")
  check(pop.pullTag.captionColor == S.BRAND and bar.pullTag.captionColor == S.BRAND, "PULL in cyan")

  SlashCmdList.TACTARA("look minimal")
  check(TactaraCharDB.displayStyle == "minimal", "/tac look minimal")
  check(edges(pop.icons[1]) == 0 and edges(pop.icons[2]) == 0 and edges(bar.icons[1]) == 0, "minimal: no frames on spell icons")
  t, c = edges(pop.interrupt)
  check(t == 1 and c == ns.GLOW_COLORS.interrupt and not pop.interrupt.tag:IsShown(), "minimal: interrupt keeps a thin red edge, no caption")
  SlashCmdList.TACTARA("look")
  check(TactaraCharDB.displayStyle == "standard" and edges(pop.icons[1]) == 2 and pop.interrupt.tag:IsShown(), "/tac look toggles back")
  SlashCmdList.TACTARA("look shiny")
  check(TactaraCharDB.displayStyle == "standard", "unknown look: unchanged")

  -- an icon that's hidden takes its frame with it
  local keep = TactaraCharDB.keyIcons
  TactaraCharDB.keyIcons = 1
  ns.UpdateDisplay()
  check(not bar.icons[2]:IsShown() and not bar.icons[2].edges:IsShown(), "hidden key bar icon: no frame left behind")
  TactaraCharDB.keyIcons = keep
  ns.UpdateDisplay()
  check(bar.icons[2].edges:IsShown(), "and back")
end

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

-- 19c) Paladin auras (and stances, forms) are on the stance bar: it knows
-- which one is on even when buffs are hidden, and after a reload
do
  local forms = {}
  GetNumShapeshiftForms = function() return #forms end
  GetShapeshiftFormInfo = function(i)
    local f = forms[i]
    return "icon", f.on, true, f.id
  end
  local realName = C_Spell.GetSpellName
  C_Spell.GetSpellName = function(id) return ({ [10293] = "Devotion Aura", [10301] = "Retribution Aura" })[id] or realName(id) end
  C_UnitAuras.GetAuraDataBySpellName = function() return nil end   -- Forever hides the buff
  local dev = { kind = "missing", arg = "Devotion Aura" }
  local ret = { kind = "missing", arg = "Retribution Aura" }
  inCombat = false
  check(ns.CheckLive(dev) == true and ns.FormActive("Devotion Aura") == nil, "no stance bar, hidden buff, no timer: missing")
  forms = { { id = 10293, on = true }, { id = 10301, on = false } }
  check(ns.FormActive("Devotion Aura") == true, "Devotion Aura is on (stance bar)")
  check(ns.CheckLive(dev) == false, "@missing Devotion Aura: not missing while it's on")
  check(ns.HasBuff("Devotion Aura") == true, "@ifmissing sees it too")
  check(ns.CheckLive(ret) == true and ns.HasBuff("Retribution Aura") == false, "the aura that isn't on is missing")
  forms[1].on, forms[2].on = false, true
  check(ns.CheckLive(dev) == true and ns.CheckLive(ret) == false, "switch auras: the stance bar follows")
  forms = { { id = 999999, on = true } }
  C_Spell.GetSpellName = function(id) return id == 999999 and "Devotion Aura" or realName(id) end
  check(ns.CheckLive(dev) == false, "matched by name when the rank's ID is a different one")
  C_Spell.GetSpellName = function(id) return ({ [10293] = "Devotion Aura" })[id] or realName(id) end
  forms = { { id = 10293, on = false } }
  C_Spell.GetSpellName = realName
  check(ns.FormActive("Devotion Aura") == false, "matched by spell ID when the name isn't readable")
  check(ns.FormActive("Blessing of Might") == nil and ns.FormActive("Battle Shout") == nil, "spells not on the stance bar: not a form")
  -- before the pull: no reminder for an aura that's on
  forms = { { id = 10293, on = true } }
  check(ns.LiveOK({ live = { dev } }) == false, "an aura that's on isn't listed before the pull")
  GetShapeshiftFormInfo = function() error("secret value") end
  check(ns.FormActive("Devotion Aura") == nil, "the game hides the stance bar: no guess")
  GetNumShapeshiftForms, GetShapeshiftFormInfo = nil, nil
  C_Spell.GetSpellName = realName
  C_UnitAuras.GetAuraDataBySpellName = savedAuraFn
  inCombat = true
end
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
-- talent probe: read only, report in a copy window
do
  local shownTitle, shownText
  local realShow = ns.ShowCopyText
  ns.ShowCopyText = function(title, text) shownTitle, shownText = title, text end
  local bought = false
  C_Traits.PurchaseRank = function() bought = true end
  C_Traits.CommitConfig = function() bought = true end
  C_Traits.CanPurchaseRank = function() return true end
  local okT, report = pcall(SlashCmdList.TACTARA, "probe talents")
  ns.ShowCopyText = realShow
  check(okT and shownTitle == "Tactara talent probe" and shownText, "talent probe opens a copy window")
  shownText = shownText or ""
  check(shownText:find("12 talents") and shownText:find("Shield Slam") and shownText:find("config 4545363"),
    "talent probe lists the talents: " .. shownText:sub(1, 200))
  check(shownText:find("functions there: [^\n]*C_Traits.PurchaseRank") and shownText:find("functions missing: [^\n]*C_Traits.GetConditionInfo"),
    "talent probe lists which talent functions exist")
  check(not bought, "talent probe never learns or commits anything")
  check(shownText:find("PlayerSpellsFrame: not there"), "talent probe reports the talent window")
  C_Traits.PurchaseRank, C_Traits.CommitConfig, C_Traits.CanPurchaseRank = nil, nil, nil
  -- the copy window itself builds with the frame stand-ins
  local okW, w = pcall(realShow, "title", "line 1\nline 2")
  check(okW and w and w:IsShown(), "copy window: " .. tostring(w))
end
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

-- a sound when the interrupt or defensive slot lights up (off unless picked)
do
  local played = {}
  PlaySound = function(id, channel) played[#played + 1] = id .. ":" .. tostring(channel); return true end
  SOUNDKIT = { RAID_WARNING = 8959, READY_CHECK = 8960 }
  local function count() local n = #played; played = {}; return n end
  check(TactaraCharDB.interruptSound == "off" and TactaraCharDB.defensiveSound == "off", "sounds start off")
  casting, channel = nil, nil
  playerHP = 90; tick()
  casting = { name = "Fireball", locked = false }; playerHP = 40; tick()
  check(ns.lastUtility.interrupt == "Pummel" and ns.lastUtility.defensive == "Retaliation" and count() == 0, "no sound while off")
  casting = nil; playerHP = 90; tick()

  SlashCmdList.TACTARA("sound interrupt raid")
  check(TactaraCharDB.interruptSound == "raid" and played[1] == "8959:Master", "/tac sound interrupt raid plays it once: " .. tostring(played[1]))
  count()
  now = now + 5
  casting = { name = "Fireball", locked = false }; tick()
  check(played[1] == "8959:Master" and count() == 1, "interrupt lights up: raid warning on the master channel")
  tick(); tick()
  check(count() == 0, "still lit: no more sounds")
  casting = nil; tick()
  casting = { name = "Frostbolt", locked = false }; tick()
  check(count() == 0, "a new cast within 1.5 seconds: quiet")
  casting = nil; tick()
  now = now + 2
  casting = { name = "Frostbolt", locked = false }; tick()
  check(count() == 1, "the next cast after that: a sound")
  casting = nil
  SlashCmdList.TACTARA("interrupts off")
  now = now + 2
  casting = { name = "Fireball", locked = false }; tick()
  check(count() == 0, "interrupt suggestions off: no sound")
  SlashCmdList.TACTARA("interrupts on")
  casting = nil; tick(); count()

  SlashCmdList.TACTARA("sound defensive ready")
  count()
  playerHP = 40; tick()
  check(played[1] == "8960:Master" and count() == 1, "defensive lights up: ready check")
  playerHP = 90; tick(); playerHP = 40; tick()
  check(count() == 0, "health bobbing: once per 10 seconds")
  playerHP = 90; tick()
  now = now + 11
  playerHP = 40; tick()
  check(count() == 1, "after 10 seconds: again")
  playerHP = 90; tick()

  SOUNDKIT = nil
  now = now + 11
  playerHP = 40; tick()
  check(played[1] == "8960:Master", "no SOUNDKIT table: the sound's number")
  playerHP = 90; tick(); count()
  SlashCmdList.TACTARA("sound test"); runTimers()
  check(#played == 2 and played[1] == "8959:Master" and played[2] == "8960:Master", "/tac sound test plays both: " .. table.concat(played, ","))
  count()
  SlashCmdList.TACTARA("sound interrupt nosuch")
  check(TactaraCharDB.interruptSound == "raid" and table.concat(chat, " "):find("No sound called"), "unknown sound name")
  SlashCmdList.TACTARA("sound interrupt off")
  SlashCmdList.TACTARA("sound defensive")
  check(TactaraCharDB.interruptSound == "off" and TactaraCharDB.defensiveSound == "off", "off, and a toggle")
  SlashCmdList.TACTARA("sound defensive")
  check(TactaraCharDB.defensiveSound == ns.SOUND_DEFAULTS.defensive, "toggled back on to the default")
  SlashCmdList.TACTARA("sound")
  check(table.concat(chat, " "):find("Sounds: interrupt off, defensive Alarm clock"), "/tac sound says what's set")
  PlaySound = function() error("no sound") end
  now = now + 11
  playerHP = 40
  check(pcall(tick), "a sound that errors doesn't break the helper")
  PlaySound = nil
  playerHP = 90; tick()
  check(pcall(tick), "no PlaySound at all: fine")
  TactaraCharDB.defensiveSound = "off"
  ns.ResetUtilitySounds()
  casting = nil; playerHP = 40; nameplates = 3
  tick()
end

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

-- between fights: show / see-through / hide
do
  local wasCombat, wasTarget, wasLocked = inCombat, hasTarget, TactaraCharDB.locked
  TactaraCharDB.locked = true
  check(TactaraCharDB.helperIdle == "fade" and TactaraCharDB.keyIdle == "show" and TactaraCharDB.fadeAlpha == 0.45,
    "defaults: helper see-through, key bar normal, 45%")
  inCombat, hasTarget = false, false
  ns.HelperRefresh()
  check(ns.helperPopup:IsShown() and ns.helperPopup:GetAlpha() == 0.45, "helper see-through between fights")
  check(ns.display:IsShown() and ns.display:GetAlpha() == 1, "key bar normal between fights")
  SlashCmdList.TACTARA("fade key hide")
  check(TactaraCharDB.keyIdle == "hide" and not ns.display:IsShown(), "/tac fade key hide")
  SlashCmdList.TACTARA("fade 30")
  check(TactaraCharDB.fadeAlpha == 0.3 and ns.helperPopup:GetAlpha() == 0.3, "/tac fade 30")
  SlashCmdList.TACTARA("fade 5")
  check(TactaraCharDB.fadeAlpha == 0.1, "see-through can't go below 10%")
  hasTarget = true
  ns.HelperRefresh()
  check(ns.display:IsShown() and ns.display:GetAlpha() == 1 and ns.helperPopup:GetAlpha() == 1, "targeting an enemy brings both back")
  hasTarget = false; inCombat = true
  ns.HelperRefresh()
  check(ns.display:IsShown() and ns.helperPopup:GetAlpha() == 1, "in combat: both full")
  inCombat = false
  TactaraCharDB.locked = false
  ns.HelperRefresh()
  check(ns.display:IsShown() and ns.display:GetAlpha() == 0.1, "unlocked: hidden key bar shows see-through so you can move it")
  TactaraCharDB.locked = true
  SlashCmdList.TACTARA("fade show")
  ns.HelperRefresh()
  check(TactaraCharDB.helperIdle == "show" and ns.helperPopup:GetAlpha() == 1 and ns.display:IsShown(), "/tac fade show sets both")
  SlashCmdList.TACTARA("fade helper fade"); SlashCmdList.TACTARA("fade 45")
  check(TactaraCharDB.helperIdle == "fade" and TactaraCharDB.keyIdle == "show" and TactaraCharDB.fadeAlpha == 0.45, "back to defaults")
  inCombat, hasTarget, TactaraCharDB.locked = wasCombat, wasTarget, wasLocked
  ns.HelperRefresh()
end

-- how many icons each display shows: 1-10 or all
do
  local function ShownKey()
    local c = 0
    for i, t in ipairs(ns.display.icons) do if t:IsShown() then c = i end end
    return c
  end
  local function ShownHelper()
    local c = 0
    for i, h in ipairs(ns.helperPopup.icons) do if h:IsShown() then c = i end end
    return c
  end
  check(TactaraCharDB.keyIcons == 3 and TactaraCharDB.helperIcons == 3, "default: 3 icons each")
  ns.HelperRefresh()
  check(ShownKey() == 3, "key bar shows 3 (" .. ShownKey() .. ")")
  SlashCmdList.TACTARA("icons key 1")
  check(TactaraCharDB.keyIcons == 1 and ShownKey() == 1 and not ns.display.icons[2]:IsShown(), "key bar down to 1 icon")
  SlashCmdList.TACTARA("icons key 7")
  local q7 = ns.KeyQueue(7)
  check(#q7 == 7 and ShownKey() == 7, "key bar shows 7 (" .. ShownKey() .. ")")
  local same = true
  for i = 1, 7 do if ns.display.icons[i]._texture ~= "icon:" .. q7[i] then same = false end end
  check(same, "the 7 icons are the key's next 7 presses")
  SlashCmdList.TACTARA("icons key all")
  local comp = ns.CompiledFor(ns.mainButton)
  local whole = ns.KeyQueue(ns.MAX_ICONS, true)
  local pullN = (comp.pull and not inCombat) and 1 or 0
  local loopLen = #comp.steps - (comp.loopStart or 1) + 1
  check(TactaraCharDB.keyIcons == 0 and #whole >= loopLen and #whole <= #comp.steps + pullN,
    ("whole rotation: %d icons for %d steps (loop %d)"):format(#whole, #comp.steps, loopLen))
  check(ShownKey() == #whole, "key bar shows the whole rotation (" .. ShownKey() .. ")")
  check(#ns.KeyQueue(5) == 5, "a number still repeats the loop when it's short")
  SlashCmdList.TACTARA("icons helper 5")
  local hq = ns.HelperQueue(5, true, "priority")
  check(TactaraCharDB.helperIcons == 5 and ShownHelper() == #hq and #hq <= 5, "helper shows up to 5 (" .. ShownHelper() .. ")")
  check(ns.helperPopup.slots == 5, "helper keeps room for 5")
  SlashCmdList.TACTARA("icons helper all")
  local every = ns.HelperQueue(ns.MAX_ICONS, true, "priority", true)
  check(ShownHelper() == #every and ns.helperPopup.slots == math.max(#every, 1), "helper shows everything usable (" .. #every .. ")")
  SlashCmdList.TACTARA("icons helper 11")
  check(TactaraCharDB.helperIcons == 0, "11 isn't allowed")
  SlashCmdList.TACTARA("icons 3")
  check(TactaraCharDB.keyIcons == 3 and TactaraCharDB.helperIcons == 3 and ShownKey() == 3 and ns.helperPopup.slots == 3, "/tac icons 3 sets both back")
  -- a one-step loop with all doesn't run forever
  local fake = { steps = { { icon = "Heroic Strike", spells = { "Heroic Strike" } } }, loopStart = 1 }
  local realComp = ns.CompiledFor
  ns.CompiledFor = function() return fake end
  check(#ns.KeyQueue(ns.MAX_ICONS, true) == 1 + ((not inCombat and fake.pull) and 1 or 0), "one-step rotation, all = 1 icon")
  check(#ns.KeyQueue(4) == 4, "one-step rotation, 4 = the same step 4 times")
  ns.CompiledFor = realComp
end

-- probe has the new lines
chat = {}
SlashCmdList.TACTARA("probe")
local p3 = table.concat(chat, "\n")
check(p3:find("YOUR health / max: 40, 100") and p3:find("Tactara reads target cast as: none"), "probe health + cast lines")
inCombat = false

-- helper icons: cooldown sweep and tints (red range, blue power, grey unusable)
do
  local inRange = {}
  C_Spell.IsSpellInRange = function(spell, unit)
    local v = inRange[spell]
    if v == "hidden" then error("secret value") end
    return v
  end
  hasTarget = true
  -- cooldowns
  cooldowns["Mortal Strike"] = { isActive = true, isOnGCD = false, startTime = now - 2, duration = 6 }
  local st, du = ns.IconCooldown("Mortal Strike")
  check(st == now - 2 and du == 6, "cooldown sweep reads the cooldown")
  cooldowns["Mortal Strike"] = { isActive = true, isOnGCD = true, startTime = now, duration = 1.5 }
  st, du = ns.IconCooldown("Mortal Strike")
  check(st == 0 and du == 0, "no sweep for the global cooldown")
  cooldowns["Mortal Strike"] = "hidden"
  check(ns.IconCooldown("Mortal Strike") == nil, "hidden cooldown -> no sweep")
  cooldowns["Mortal Strike"] = nil
  -- tints
  check(ns.IconTint("Heroic Strike") == "none", "ready + in range -> plain")
  usable["Heroic Strike"] = { false, true }
  check(ns.IconTint("Heroic Strike") == "power", "short on rage -> blue")
  usable["Heroic Strike"] = { false, false }
  check(ns.IconTint("Heroic Strike") == "unusable", "can't be used -> grey")
  usable["Heroic Strike"] = nil
  inRange["Heroic Strike"] = false
  check(ns.IconTint("Heroic Strike") == "range", "out of range -> red")
  inRange["Heroic Strike"] = "hidden"
  check(ns.IconTint("Heroic Strike") == "none", "hidden range -> plain")
  usable["Heroic Strike"] = "hidden"
  check(ns.IconTint("Heroic Strike") == "none", "hidden usable -> plain")
  usable["Heroic Strike"] = nil
  inRange["Heroic Strike"] = false
  TactaraCharDB.helperTint = false
  check(ns.IconTint("Heroic Strike") == "none", "tints can be turned off")
  TactaraCharDB.helperTint = true
  -- on the popup
  local holder = { tex = CreateFrame("Frame"), key = CreateFrame("Frame"), cd = CreateFrame("Cooldown") }
  local cdSet
  holder.cd.SetCooldown = function(_, a, b) cdSet = { a, b } end
  cooldowns["Heroic Strike"] = { isActive = true, isOnGCD = false, startTime = now - 1, duration = 4 }
  ns.UpdateIconState(holder, "Heroic Strike")
  check(holder.tint == "range" and cdSet and cdSet[2] == 4, "popup icon gets the tint and the sweep")
  TactaraCharDB.helperCooldowns = false
  cdSet = nil
  ns.UpdateIconState(holder, "Heroic Strike")
  check(holder.cdDur == 0, "sweep can be turned off")
  TactaraCharDB.helperCooldowns = true
  cooldowns["Heroic Strike"], inRange["Heroic Strike"] = nil, nil
  C_Spell.IsSpellInRange = nil
  hasTarget = false
  local okR = pcall(ns.HelperRefresh)
  check(okR, "helper refresh with the new icon states")
end

-- new live checks: @creature, @nopet, @combo
do
  local creature = "Undead"
  UnitCreatureType = function() return creature end
  hasTarget = true
  check(ns.CheckLive({ kind = "creature", arg = "Undead, Demon" }) == true, "@creature matches Undead")
  creature = "Humanoid"
  check(ns.CheckLive({ kind = "creature", arg = "Undead, Demon" }) == false, "@creature skips Humanoid")
  UnitCreatureType = function() error("secret value") end
  check(ns.CheckLive({ kind = "creature", arg = "Undead" }) == nil, "@creature unknown when hidden")
  local realExists = UnitExists
  local petUp = false
  UnitExists = function(u) if u == "pet" then return petUp end return realExists(u) end
  check(ns.CheckLive({ kind = "nopet", arg = "" }) == true, "@nopet with no pet")
  petUp = true
  check(ns.CheckLive({ kind = "nopet", arg = "" }) == false, "@nopet with a pet")
  UnitExists = realExists
  -- combo points: hidden by the game -> counted from builders, reset by finishers
  GetComboPoints = function() error("secret value") end
  inCombat = false
  ns.trackerFrame._scripts.OnEvent(ns.trackerFrame, "PLAYER_REGEN_ENABLED")
  ns.TrackCast("Sinister Strike"); ns.TrackCast("Sinister Strike"); ns.TrackCast("Mutilate")
  check(ns.ComboPoints() == 4, "combo count from builders (" .. tostring(ns.ComboPoints()) .. ")")
  check(ns.CheckLive({ kind = "combo", arg = "4" }) == true and ns.CheckLive({ kind = "combo", arg = "5" }) == false, "@combo uses the count")
  ns.TrackCast("Mutilate"); ns.TrackCast("Mutilate")
  check(ns.ComboPoints() == 5, "combo count caps at 5")
  ns.TrackCast("Eviscerate")
  check(ns.ComboPoints() == 0, "finisher resets the count")
  GetComboPoints = function() return 3 end
  check(ns.ComboPoints() == 3, "game's combo points win when shown")
  GetComboPoints = nil
  hasTarget = false
  -- parser: @nopet needs no value, [@player] is still a macro target
  local r = ns.Parse("name: t\n[priority]\n/cast Call Pet @nopet\n/cast [@player] Flash Heal @health 40\n/cast Exorcism @creature Undead, Demon")
  check(#r.warnings == 0, "new annotations parse: " .. table.concat(r.warnings, "; "))
  check(r.sections.priority[1].conds[1].kind == "nopet", "@nopet parsed")
  check(r.sections.priority[2].cmd == "/cast [@player] Flash Heal", "[@player] kept in the command")
end

-- two rotations on one tree: the one whose "prefer:" talents you took wins
do
  local realList, realBuild = ns.ListRotations, ns.ReadBuild
  ns.ListRotations = function() return {
    { name = "Cat", tree = "Feral", prefer = "Shifting Power", default = true },
    { name = "Bear", tree = "Feral", prefer = "Primal Bite, Natural Reaction" },
  } end
  ns.ReadBuild = function() return { top = "Feral", weapon = nil,
    talents = { trees = { { name = "Feral", points = 20 } }, talents = { ["Primal Bite"] = 1, ["Natural Reaction"] = 2 } } } end
  local saved = TactaraCharDB.active
  TactaraCharDB.active = "auto"
  check(ns.ResolveActive() == "Bear", "bear talents pick the bear rotation")
  ns.ReadBuild = function() return { top = "Feral", weapon = nil,
    talents = { trees = { { name = "Feral", points = 20 } }, talents = { ["Shifting Power"] = 1 } } } end
  check(ns.ResolveActive() == "Cat", "cat talents pick the cat rotation")
  ns.ListRotations, ns.ReadBuild, TactaraCharDB.active = realList, realBuild, saved
end


---------------------------------------------------------------------------
-- Talent builds and learning, on the real Warrior tree from the probe
---------------------------------------------------------------------------
do
  local T = ns.Talents
  local FIX = dofile(root .. "/../tests/talent_fixtures/warrior.lua")
  local byId, order = {}, {}
  local function reset()
    byId, order = {}, {}
    for _, n in ipairs(FIX) do
      byId[n.id] = { id = n.id, x = n.x, y = n.y, rank = n.rank, max = n.max, name = n.name, spell = n.spell, to = n.to, staged = 0 }
      order[#order + 1] = n.id
    end
  end
  reset()
  local earned, canAdd, forceStaged, refuse = 3, true, false, {}
  local commits, rollbacks, onPurchase = 0, 0, nil
  local function anyStaged()
    for _, n in pairs(byId) do if n.staged > 0 then return true end end
    return false
  end
  local realCT, realTraits = C_ClassTalents, C_Traits
  C_ClassTalents = {
    GetActiveConfigID = function() return 5914191 end,
    CanChangeTalents = function() return true, canAdd, (not canAdd) and "TEST: not now" or nil end,
    CommitConfig = function()
      commits = commits + 1
      for _, n in pairs(byId) do n.rank = n.rank + n.staged; n.staged = 0 end
      return true
    end,
  }
  C_Traits = {
    GetConfigInfo = function() return { treeIDs = { 1117 } } end,
    GetTreeNodes = function() return order end,
    GetNodeInfo = function(_, id)
      local n = byId[id]
      local edges = {}
      for _, t in ipairs(n.to) do edges[#edges + 1] = { targetNode = t } end
      return { ID = id, posX = n.x, posY = n.y, maxRanks = n.max, ranksPurchased = n.rank + n.staged,
        entryIDs = { id }, visibleEdges = edges, subTreeID = 0 }
    end,
    GetEntryInfo = function(_, id) return { definitionID = id, maxRanks = byId[id].max } end,
    GetDefinitionInfo = function(id) return { spellID = byId[id].spell, overrideName = byId[id].name } end,
    GetTreeCurrencyInfo = function() return { { maxQuantity = earned } } end,
    CanPurchaseRank = function(_, id) return not refuse[id] end,
    PurchaseRank = function(_, id)
      if onPurchase then return onPurchase(id) end
      byId[id].staged = byId[id].staged + 1
      return true
    end,
    ConfigHasStagedChanges = function() return forceStaged or anyStaged() end,
    RollbackConfig = function() rollbacks = rollbacks + 1; for _, n in pairs(byId) do n.staged = 0 end end,
  }

  -- reading the tree
  local tree, why = T.ReadTree()
  check(tree ~= nil, "talent tree read: " .. tostring(why))
  tree = tree or { list = {}, trees = {}, byName = {}, nodes = {} }
  check(#tree.list == 53 and #tree.trees == 3, ("53 talents in 3 trees (%d, %d)"):format(#tree.list, #tree.trees))
  check(tree.trees[1] and tree.trees[1].name == "Arms" and tree.trees[2].name == "Fury" and tree.trees[3].name == "Protection",
    "trees named Arms / Fury / Protection: " .. tostring(tree.trees[1] and tree.trees[1].name) .. ", "
      .. tostring(tree.trees[2] and tree.trees[2].name) .. ", " .. tostring(tree.trees[3] and tree.trees[3].name))
  local function N(name) return tree.byName[name:lower()] end
  check(N("Mortal Strike").row == 7 and N("Anger Management").row == 3 and N("Deflection").row == 1, "rows from the game's layout")
  check(N("Improved Heroic Strike").col == 1 and N("Improved Overpower").col == 4 and N("Bastion").tree == 3, "columns and trees")
  check(#N("Deep Wounds").from == 1 and N("Deep Wounds").from[1] == N("Improved Rend").id, "arrow: Improved Rend into Deep Wounds")
  check(tree.earned == 3 and tree.spent == 3 and tree.unspent == 0, "points: 3 earned, 3 spent")

  -- the built-in builds are legal, 51 points each
  local builds = T.BuildsForClass("WARRIOR")
  check(#builds == 6, "six Warrior builds (three leveling, three level 60)")
  local want = { ["Warrior - Arms"] = "33/16/2", ["Warrior - Fury"] = "16/33/2", ["Warrior - Protection"] = "4/16/31",
    ["Warrior - Arms (level 60)"] = "32/17/2", ["Warrior - Fury (level 60)"] = "18/33/0", ["Warrior - Protection (level 60)"] = "5/15/31" }
  for _, b in ipairs(builds) do
    local split, sim = T.Split(b, tree)
    check(sim.ok and sim.total == 51, b.name .. " is legal with 51 points: "
      .. (sim.firstError and ("level " .. sim.firstError.level .. " " .. sim.firstError.err) or tostring(sim.total)))
    check(split == want[b.name], b.name .. " splits " .. want[b.name] .. " (" .. split .. ")")
    local again = T.Parse(T.Export(b))
    check(table.concat(again.picks, ",") == table.concat(b.picks, ",") and again.level == b.level, b.name .. " survives export and import")
  end

  -- the rules
  local function firstErr(picks)
    local sim = T.Simulate(picks, tree)
    return sim.firstError and sim.firstError.err or "ok", sim.firstError and sim.firstError.index
  end
  check(firstErr({ "Mortal Strike" }):find("needs 30 points in Arms"), "row rule: Mortal Strike needs 30 in Arms")
  local p = { "Deflection", "Deflection", "Deflection", "Deflection", "Deflection",
    "Improved Heroic Strike", "Improved Heroic Strike", "Improved Heroic Strike",
    "Improved Overpower", "Improved Overpower", "Improved Rend", "Deep Wounds" }
  local e, at = firstErr(p)
  check(e:find("needs Improved Rend 3/3") and at == 12, "arrow rule: Deep Wounds needs Improved Rend maxed (" .. e .. ")")
  check(firstErr({ "Improved Rend", "Improved Rend", "Improved Rend", "Improved Rend" }):find("already 3/3"), "max rank rule")
  check(firstErr({ "Bladestorm" }):find("no talent called Bladestorm"), "unknown talents are flagged")
  local many = {}
  for _, b in ipairs(builds) do if b.name == "Warrior - Arms" then for _, x in ipairs(b.picks) do many[#many + 1] = x end end end
  many[#many + 1] = "Improved Heroic Strike"
  local e52, at52 = firstErr(many)
  check(e52:find("more than 51") and at52 == 52, "52nd point is one too many")

  -- where you are in a build (you have Improved Heroic Strike 1, Improved Rend 1, Improved Bloodrage 1)
  local arms = T.GetBuild("Warrior - Arms")
  local prog = T.Progress(arms, tree)
  check(prog.next and prog.next.node.name == "Improved Rend" and prog.next.rank == 2, "next in Arms: Improved Rend 2/3")
  check(#prog.offPlan == 1 and prog.offPlan[1] == "Improved Heroic Strike", "Improved Heroic Strike isn't in the Arms build")

  -- your own builds
  local mine = T.SaveCustom({ name = "Warrior - Arms", class = "WARRIOR", picks = { "Deflection", "Deflection" } })
  check(mine.name == "Warrior - Arms 2" and T.GetBuild("Warrior - Arms 2") and #T.GetBuild("Warrior - Arms 2").picks == 2,
    "copying a built-in build gets its own name")
  check(T.RenameCustom("Warrior - Arms 2", "Tank leveling") and T.GetBuild("Tank leveling") and not T.GetBuild("Warrior - Arms 2"), "rename")
  check(not T.RenameCustom("Tank leveling", "Warrior - Fury"), "can't take a built-in build's name")
  check(#T.BuildsForClass("WARRIOR") == 7, "your build is listed after the built-in ones")
  T.DeleteCustom("Tank leveling")
  check(#T.BuildsForClass("WARRIOR") == 6, "delete")

  -- learning
  chat = {}
  local learned, reason = T.Learn(1)
  check(not learned and reason:find("pick a build"), "learning needs a build: " .. tostring(reason))
  T.SetActive("Warrior - Arms")
  learned, reason = T.Learn(1)
  check(not learned and reason:find("no talent points"), "learning needs a spare point")
  earned = 6   -- level 15: three points to spend
  inCombat = true
  learned, reason = T.Learn(1)
  check(not learned and reason:find("combat"), "never in combat")
  inCombat = false
  canAdd = false
  learned, reason = T.Learn(1)
  check(not learned and reason == "TEST: not now", "the game says no: " .. tostring(reason))
  canAdd = true
  forceStaged = true
  learned, reason = T.Learn(1)
  check(not learned and reason:find("aren't applied yet"), "unapplied changes in the talent window come first")
  forceStaged = false
  chat = {}
  learned, reason = T.Learn(1)
  runTimers()
  check(learned and #learned == 1 and byId[N("Improved Rend").id].rank == 2 and commits == 1, "Learn next: Improved Rend 2/3")
  check(table.concat(chat, "\n"):find("Learned: Improved Rend 2/3"), "says what it learned: " .. table.concat(chat, " | "))
  chat = {}
  learned = T.Learn("all")
  runTimers()
  check(learned and #learned == 2 and byId[N("Improved Rend").id].rank == 3 and byId[N("Deflection").id].rank == 1,
    "Learn all: Improved Rend 3/3 and Deflection 1/5")
  -- the game won't take the next one
  earned = 7
  refuse[N("Deflection").id] = true
  local before = commits
  learned, reason = T.Learn(1)
  check(not learned and reason:find("won't take Deflection") and commits == before and rollbacks > 0, "game refuses: nothing committed")
  refuse = {}

  -- talent window glow
  local glowOn, glowOff = {}, {}
  local realShow, realHide = ns.ShowButtonGlow, ns.HideButtonGlow
  ns.ShowButtonGlow = function(btn, kind) glowOn[#glowOn + 1] = { btn = btn, kind = kind } end
  ns.HideButtonGlow = function(btn) glowOff[#glowOff + 1] = btn end
  local buttons = {}
  PlayerSpellsFrame = { TalentsFrame = {
    IsVisible = function() return true end,
    GetTalentButtonByNodeID = function(_, id) buttons[id] = buttons[id] or { id = id }; return buttons[id] end,
  } }
  T.UpdateTalentWindowGlow()
  check(#glowOn == 1 and glowOn[1].btn.id == N("Deflection").id and glowOn[1].kind == "next", "talent window: the next talent glows")
  TactaraCharDB.talentGlow = false
  T.UpdateTalentWindowGlow()
  check(#glowOff == 1 and #glowOn == 1, "glow can be turned off")
  TactaraCharDB.talentGlow = nil

  -- blocked by the game: remember it and fall back to the glow
  onPurchase = function() T.HandleEvent("ADDON_ACTION_FORBIDDEN", "Tactara", "PurchaseRank()") end
  chat = {}
  learned, reason = T.Learn(1)
  check(not learned and reason:find("doesn't let addons") and TactaraDB.talentLearnBlocked == "70000", "blocked learning is remembered")
  check(table.concat(chat, "\n"):find("glow the next talent"), "and explained")
  onPurchase = nil
  learned, reason = T.Learn(1)
  check(not learned and reason:find("doesn't let addons"), "no second try on the same game build")
  T.blocked, TactaraDB.talentLearnBlocked = false, nil

  -- level up: reminder, or learning by itself when that's on
  chat = {}
  T.HandleEvent("PLAYER_LEVEL_UP", 16)
  runTimers()
  check(table.concat(chat, "\n"):find("1 talent point to spend. Next in Warrior %- Arms: Deflection 2/5"), "level up reminder: " .. table.concat(chat, " | "))
  TactaraCharDB.talentAutoLearn = true
  inCombat = true
  T.HandleEvent("PLAYER_LEVEL_UP", 16)
  runTimers()
  check(byId[N("Deflection").id].rank == 1, "auto-learn waits for the fight to end")
  inCombat = false
  chat = {}
  T.HandleEvent("PLAYER_REGEN_ENABLED")
  runTimers()
  check(byId[N("Deflection").id].rank == 2 and table.concat(chat, "\n"):find("Learned: Deflection 2/5"), "auto-learn after combat")
  TactaraCharDB.talentAutoLearn = nil
  ns.ShowButtonGlow, ns.HideButtonGlow = realShow, realHide
  PlayerSpellsFrame = nil
  ns.TalentTest = { byId = byId, reset = reset, setEarned = function(v) earned = v end }
end


-- the talent planner window (still on the real Warrior tree)
do
  local T, P = ns.Talents, ns.TalentPlanner
  ns.TalentTest.setEarned(7)
  local okShow, eShow = pcall(P.Show)
  check(okShow, "planner opens: " .. tostring(eShow))
  check(P.Selected() and P.Selected().name == "Warrior - Arms", "opens on the build you're using")
  local shown = 0
  for _, b in ipairs(P.debug.buttons) do if b:IsShown() and b.node then shown = shown + 1 end end
  check(shown == 53, "all 53 talents drawn (" .. shown .. ")")
  local function Btn(name)
    for _, b in ipairs(P.debug.buttons) do if b.node and b.node.name == name then return b end end
  end
  local order = P.debug.ui.orderText:GetText() or ""
  check(order:find("10  Improved Rend 1/3") and order:find("50  Lingering Rage 5/5"), "level by level list")
  -- a full built-in build: adding one more is refused, and no copy is made
  local before = #T.BuildsForClass("WARRIOR")
  Btn("Mortal Strike"):GetScript("OnClick")(Btn("Mortal Strike"), "LeftButton")
  check(#T.BuildsForClass("WARRIOR") == before and (P.debug.status() or ""):find("more than 51"), "can't go past 51 points")
  -- a new build of your own
  P.debug.ui.new:GetScript("OnClick")(P.debug.ui.new)
  check(P.Selected() and P.Selected().name == "My build" and #P.Selected().picks == 0, "New makes an empty build")
  local rend = Btn("Improved Rend")
  for _ = 1, 3 do rend:GetScript("OnClick")(rend, "LeftButton") end
  check(#P.Selected().picks == 3, "three clicks, three points")
  local dw = Btn("Deep Wounds")
  dw:GetScript("OnClick")(dw, "LeftButton")
  check(#P.Selected().picks == 3 and (P.debug.status() or ""):find("needs 10 points in Arms"), "Deep Wounds refused: " .. tostring(P.debug.status()))
  rend:GetScript("OnClick")(rend, "RightButton")
  check(#P.Selected().picks == 2, "right-click takes one back")
  -- changing a built-in build makes your own copy
  P.Select("Warrior - Fury")
  local hs = Btn("Improved Heroic Strike")
  P.debug.ui.undo:GetScript("OnClick")(P.debug.ui.undo)
  check(P.Selected().name == "My Fury build" and #P.Selected().picks == 50 and #T.GetBuild("Warrior - Fury").picks == 51,
    "Undo on Tactara's build edits your copy: " .. tostring(P.Selected().name))
  hs:GetScript("OnClick")(hs, "LeftButton")
  check(#P.Selected().picks == 51 and P.Selected().picks[51] == "Improved Heroic Strike", "and you can finish it your way")
  -- share and import
  local copied, copyOpts
  local realCopy = ns.ShowCopyText
  ns.ShowCopyText = function(_, text, opts) copied, copyOpts = text, opts end
  P.debug.ui.share:GetScript("OnClick")(P.debug.ui.share)
  check(copied and copied:find("name: My Fury build") and copied:find("order:") and copied:find("Dual Wield Specialization 5"), "Share gives the build as text")
  P.debug.ui.import:GetScript("OnClick")(P.debug.ui.import)
  check(copyOpts and copyOpts.editable and copyOpts.onAccept, "Import opens a box to paste into")
  local okI = copyOpts and copyOpts.onAccept(T.Export(T.GetBuild("Warrior - Protection")))
  check(okI and P.Selected().name == "Warrior - Protection 2" and #P.Selected().picks == 51, "imported build saved: " .. tostring(P.Selected().name))
  check(copyOpts.onAccept("hello") == false, "junk isn't imported")
  ns.ShowCopyText = realCopy
  -- use it, then learn from the window
  P.debug.ui.use:GetScript("OnClick")(P.debug.ui.use)
  check(T.ActiveBuild().name == "Warrior - Protection 2", "Use this build")
  local learnCalls = {}
  local realLearn = T.Learn
  T.Learn = function(n) learnCalls[#learnCalls + 1] = n; return {}, nil end
  P.debug.ui.learn:GetScript("OnClick")(P.debug.ui.learn)
  P.debug.ui.learnAll:GetScript("OnClick")(P.debug.ui.learnAll)
  T.Learn = realLearn
  check(learnCalls[1] == 1 and learnCalls[2] == "all", "Learn next / Learn all buttons")
  -- rename and delete your build
  P.debug.ui.name:SetText("Prot (mine)")
  P.debug.ui.name:GetScript("OnEnterPressed")(P.debug.ui.name)
  check(P.Selected().name == "Prot (mine)" and TactaraCharDB.talentBuild == "Prot (mine)", "rename keeps it in use")
  local del = P.debug.ui.delete
  del:GetScript("OnClick")(del)
  del:GetScript("OnClick")(del)
  check(not T.GetBuild("Prot (mine)") and TactaraCharDB.talentBuild == nil, "delete asks once, then deletes")
  -- slash commands and the minimap shortcut
  local toggled = 0
  local realToggle = P.Toggle
  P.Toggle = function() toggled = toggled + 1 end
  SlashCmdList.TACTARA("talents")
  IsShiftKeyDown = function() return true end
  ns.LauncherClick("LeftButton")
  IsShiftKeyDown = nil
  P.Toggle = realToggle
  check(toggled == 2, "/tac talents and shift-click open the planner")
  chat = {}
  SlashCmdList.TACTARA("talents auto")
  check(TactaraCharDB.talentAutoLearn == true and table.concat(chat, " "):find("on"), "/tac talents auto")
  SlashCmdList.TACTARA("talents auto")
  check(not TactaraCharDB.talentAutoLearn, "/tac talents auto again: off")
end


-- start a build from the talents you have, and the button in the game's talent window
do
  local T, P = ns.Talents, ns.TalentPlanner
  local tree = T.ReadTree()
  local b = P.FromMyTalents()
  local sim = b and T.Simulate(b.picks, tree)
  check(b and b.name == "My talents" and #b.picks == tree.spent and sim.ok,
    ("Start from my talents: %s points, legal %s"):format(tostring(b and #b.picks), tostring(sim and sim.ok)))
  check(P.Selected() and P.Selected().name == "My talents", "and it's selected to keep planning")
  local mixed = { ["Improved Heroic Strike"] = true, ["Improved Bloodrage"] = true }
  local found = 0
  for _, p in ipairs(b and b.picks or {}) do if mixed[p] then found = found + 1 end end
  check(found >= 2, "it keeps points that aren't in any Tactara build")

  local tf = CreateFrame("Frame", "StubTalentsFrame")
  tf.GetTalentButtonByNodeID = function() return nil end
  PlayerSpellsFrame = { TalentsFrame = tf }
  T.HandleEvent("ADDON_LOADED", "Blizzard_PlayerSpells")
  local wb = frames.TactaraTalentWindowButton
  check(wb and wb:IsShown() and wb._text == "Tactara planner", "planner button in the talent window")
  local toggled = 0
  local realToggle = P.Toggle
  P.Toggle = function() toggled = toggled + 1 end
  if wb then wb:GetScript("OnClick")(wb) end
  P.Toggle = realToggle
  check(toggled == 1, "the button opens the planner")
  check(wb and pcall(wb:GetScript("OnEnter"), wb), "button tooltip")
  TactaraCharDB.talentButton = false
  T.UpdateWindowButton()
  check(wb and not wb:IsShown(), "the button can be turned off")
  TactaraCharDB.talentButton = nil
  T.UpdateWindowButton()
  check(wb and wb:IsShown(), "and back on")
  PlayerSpellsFrame = nil
end


-- the other classes' real trees: odd positions and stray talents in the game data
do
  local T = ns.Talents
  local realCT, realTraits, realClass = C_ClassTalents, C_Traits, UnitClass
  local function Install(fix)
    local byId, order = {}, {}
    for _, n in ipairs(fix) do byId[n.id] = n; order[#order + 1] = n.id end
    UnitClass = function() return fix.class, fix.class, 1 end
    C_ClassTalents = { GetActiveConfigID = function() return 1 end, CanChangeTalents = function() return true, true end }
    C_Traits = {
      GetConfigInfo = function() return { treeIDs = { 1 } } end,
      GetTreeNodes = function() return order end,
      GetNodeInfo = function(_, id)
        local n = byId[id]
        local edges = {}
        for _, t in ipairs(n.to) do edges[#edges + 1] = { targetNode = t } end
        return { ID = id, posX = n.x, posY = n.y, maxRanks = n.max, ranksPurchased = n.rank, entryIDs = { id }, visibleEdges = edges, subTreeID = 0 }
      end,
      GetEntryInfo = function(_, id) return { definitionID = id, maxRanks = byId[id].max } end,
      GetDefinitionInfo = function(id) return { spellID = byId[id].spell, overrideName = byId[id].name } end,
      GetTreeCurrencyInfo = function() return { { maxQuantity = 0 } } end,
    }
  end
  local expect = {
    shaman = { count = 50, names = { "Elemental", "Enhancement", "Restoration" } },
    warlock = { count = 52, names = { "Affliction", "Demonology", "Destruction" } },
    priest = { count = 52, names = { "Discipline", "Holy", "Shadow" } },   -- 53 in the data, one stray
    warrior = { count = 53, names = { "Arms", "Fury", "Protection" } },
    rogue = { count = 54, names = { "Assassination", "Combat", "Subtlety" } },
    mage = { count = 53, names = { "Arcane", "Fire", "Frost" } },
    druid = { count = 52, names = { "Balance", "Feral", "Restoration" } },
    paladin = { count = 51, names = { "Holy", "Protection", "Retribution" } },
    hunter = { count = 50, names = { "Beast Mastery", "Marksmanship", "Survival" } },   -- 52 in the data, two strays
  }
  for class, want in pairs(expect) do
    local fix = dofile(root .. "/../tests/talent_fixtures/" .. class .. ".lua")
    Install(fix)
    local tree, why = T.ReadTree()
    check(tree ~= nil, class .. " tree reads: " .. tostring(why))
    if tree then
      check(#tree.list == want.count, ("%s: %d talents (%d)"):format(class, want.count, #tree.list))
      local got = {}
      for i, tr in ipairs(tree.trees) do got[i] = tr.name end
      check(table.concat(got, "/") == table.concat(want.names, "/"), class .. " trees: " .. table.concat(got, "/"))
      local maxRow, maxCol = 0, 0
      for _, tr in ipairs(tree.trees) do maxRow = math.max(maxRow, tr.rows); maxCol = math.max(maxCol, tr.cols) end
      check(maxRow == 7 and maxCol <= 4, ("%s: 7 rows, at most 4 columns (%d, %d)"):format(class, maxRow, maxCol))
      -- every 31-point talent is on the bottom row, with one arrow at most
      -- (Moonkin Form has none), and every talent can be reached
      for _, node in ipairs(tree.list) do
        if node.row == 7 then check(#node.from <= 1, class .. ": " .. node.name .. " on the bottom row has one arrow at most") end
      end
      check(T.Simulate(T.FromCurrent(tree), tree).ok, class .. ": empty tree is fine")
    end
  end
  -- Tactara's builds for every class: legal on that class's real tree, 51
  -- points, and the split their source line says
  for class in pairs(expect) do
    Install(dofile(root .. "/../tests/talent_fixtures/" .. class .. ".lua"))
    local tree = T.ReadTree()
    local builds = {}
    for _, b in ipairs(T.BuildsForClass(class:upper())) do
      if T.IsBuiltin(b.name) then builds[#builds + 1] = b end
    end
    local leveling, at60 = 0, 0
    for _, b in ipairs(builds) do if T.IsLevel60(b) then at60 = at60 + 1 else leveling = leveling + 1 end end
    check(leveling == 3 and at60 == (class == "druid" and 4 or 3),
      ("%s: three leveling builds and %d level 60 (%d, %d)"):format(class, class == "druid" and 4 or 3, leveling, at60))
    for _, b in ipairs(builds) do
      local sim = T.Simulate(b.picks, tree)
      check(sim.ok and sim.total == 51, ("%s is legal with 51 points: %s"):format(b.name,
        sim.firstError and (sim.firstError.level .. " " .. sim.firstError.name .. ": " .. sim.firstError.err) or tostring(sim.total)))
      local want = (b.source or ""):match("%((%d+/%d+/%d+)%)")
      check(want and T.Split(b, tree) == want, ("%s split %s (source says %s)"):format(b.name, T.Split(b, tree), tostring(want)))
      local main = 0
      for t, tr in ipairs(tree.trees) do if tr.name == b.tree then main = sim.perTree[t] or 0 end end
      -- leveling builds go 31 deep; a level 60 build's tree is at least its biggest
      local most = 0
      for _, n in pairs(sim.perTree) do most = math.max(most, n) end
      if T.IsLevel60(b) then
        check(main == most and b.name:find("%(level 60%)$"), ("%s: most points in %s (%d)"):format(b.name, tostring(b.tree), main))
      else
        check(main >= 31, ("%s: 31+ points in %s (%d)"):format(b.name, tostring(b.tree), main))
      end
    end
  end
  -- Warlock: talents a few units off the grid still share a row
  Install(dofile(root .. "/../tests/talent_fixtures/warlock.lua"))
  local w = T.ReadTree()
  local function N(t, name) return t.byName[name:lower()] end
  check(N(w, "Improved Life Tap").row == 1 and N(w, "Suppression").row == 1 and N(w, "Amplify Curse").row == 3,
    "Warlock: Improved Life Tap (2120) and Amplify Curse (3320) are on their rows")
  check(T.Simulate({ "Suppression" }, w).ok, "Warlock: Suppression needs no points first")
  check(N(w, "Amplify Curse").col == 3 and N(w, "Curse of Exhaustion").from[1] == N(w, "Amplify Curse").id, "Warlock: Amplify Curse column and arrow")
  -- Priest: the stray second Holy Specialization is ignored
  Install(dofile(root .. "/../tests/talent_fixtures/priest.lua"))
  local p = T.ReadTree()
  check(N(p, "Holy Specialization").id == 110855 and N(p, "Holy Specialization").row == 1 and p.trees[N(p, "Holy Specialization").tree].name == "Holy",
    "Priest: Holy Specialization is the real one, row 1 of Holy")
  check(not p.nodes[105865], "Priest: the stray copy isn't on the trees")
  check(T.Simulate({ "Holy Specialization", "Holy Specialization" }, p).ok, "Priest: Holy Specialization can be taken")
  -- Hunter: the stray second Lightning Reflexes, the far-off Improved Serpent
  -- Sting and the arrow back up from Bestial Wrath are left out
  Install(dofile(root .. "/../tests/talent_fixtures/hunter.lua"))
  local h = T.ReadTree()
  check(N(h, "Lightning Reflexes").id == 110859 and not h.nodes[104982] and not h.nodes[105003],
    "Hunter: strays left out")
  check(#N(h, "Intimidation").from == 1 and N(h, "Intimidation").from[1] == N(h, "Bestial Swiftness").id
    and N(h, "Bestial Wrath").from[1] == N(h, "Intimidation").id and #N(h, "Bestial Wrath").to == 0,
    "Hunter: Bestial Swiftness > Intimidation > Bestial Wrath, no arrow back up")
  local bm = {}
  local function take(name, n) for _ = 1, n do bm[#bm + 1] = name end end
  take("Endurance Training", 5); take("Improved Aspect of the Monkey", 3); take("Focused Fire", 2)
  take("Bestial Swiftness", 1); take("Unleashed Fury", 5); take("Ferocity", 5); take("Spirit Bond", 2)
  take("Intimidation", 1); take("Bestial Discipline", 2); take("Frenzy", 5); take("Bestial Wrath", 1)
  local sim = T.Simulate(bm, h)
  check(sim.ok, "Hunter: Bestial Wrath can be taken: " .. tostring(sim.firstError and sim.firstError.err))
  -- Paladin: Holy Shock's arrow across its own row to Boundless Light counts
  Install(dofile(root .. "/../tests/talent_fixtures/paladin.lua"))
  local pal = T.ReadTree()
  check(N(pal, "Boundless Light").from[1] == N(pal, "Holy Shock").id, "Paladin: Holy Shock > Boundless Light, same row")
  -- Druid: Moonkin Form has no arrow
  Install(dofile(root .. "/../tests/talent_fixtures/druid.lua"))
  local dr = T.ReadTree()
  check(#N(dr, "Moonkin Form").from == 0 and N(dr, "Moonkin Form").row == 7, "Druid: Moonkin Form, bottom row, no arrow")
  C_ClassTalents, C_Traits, UnitClass = realCT, realTraits, realClass
end


-- when Tactara updates a build you're following: you're asked, never switched
do
  local T, P = ns.Talents, ns.TalentPlanner
  local function Reg(order, notes)
    return ns.RegisterTalentBuild("name: Warrior - Update Test\nclass: WARRIOR\ntree: Arms\n"
      .. (notes and ("notes: " .. notes .. "\n") or "") .. "order:\n" .. order)
  end
  local function Count()
    local n = 0
    for _, b in ipairs(T.BuildsForClass("WARRIOR")) do if b.name == "Warrior - Update Test" then n = n + 1 end end
    return n
  end
  Reg("Improved Rend 3\nDeflection 5\nImproved Overpower 2")
  T.SetActive("Warrior - Update Test")
  check(TactaraCharDB.talentBuildText and not T.ActiveBuild().outdated, "picking a build remembers its version")
  TactaraCharDB.talentBuildText = nil
  check(not T.ActiveBuild().outdated and TactaraCharDB.talentBuildText, "picked before 0.14: remembered quietly, no question")
  Reg("Improved Rend 3\nDeflection 5\nImproved Overpower 2", "reworded")
  check(not T.ActiveBuild().outdated and Count() == 1, "a wording change isn't an update, and the build isn't listed twice")
  Reg("Improved Rend 3\nDeflection 4\nImproved Tactical Mastery 3")
  local a = T.ActiveBuild()
  check(a.outdated and a.picks[8] == "Deflection" and a.newer.picks[8] == "Improved Tactical Mastery" and Count() == 1,
    "after an update you keep following the version you picked")

  -- the question
  local shown
  StaticPopupDialogs = {}
  StaticPopup_Show = function(which, text) shown = { which = which, text = text } end
  inCombat = true
  T.PromptUpdate()
  check(shown == nil, "not asked in combat")
  inCombat = false
  chat = {}
  T.HandleEvent("PLAYER_REGEN_ENABLED")
  check(shown and shown.which == "TACTARA_BUILD_UPDATE", "asked once the fight is over")
  local text = shown and shown.text or ""
  check(text:find("From level 17 it takes Improved Tactical Mastery %(yours: Deflection%)"), "says where it changed: " .. text)
  check(text:find("would need a respec"), "and whether it fits your talents")
  check(table.concat(chat, " "):find("still following your version"), "and a line in chat")
  local dlg = StaticPopupDialogs.TACTARA_BUILD_UPDATE
  check(dlg and dlg.button1 == "Switch" and dlg.button2 == "Later" and dlg.button3 == "Keep mine" and not dlg.OnCancel,
    "Switch / Later / Keep mine, and Later (or Escape) changes nothing")

  -- the planner shows your version with the choice
  P.Select("Warrior - Update Test")
  check(P.Selected().outdated and P.debug.ui.use._text == "Switch to update" and P.debug.ui.keep:IsShown(),
    "planner: your version, with Switch to update and Keep mine")

  -- Switch
  dlg.OnAccept()
  a = T.ActiveBuild()
  check(not a.outdated and a.picks[8] == "Improved Tactical Mastery", "Switch follows the new version")

  -- Keep mine (after the next update)
  Reg("Improved Rend 3\nDeflection 3\nImproved Overpower 2")
  shown = nil
  T.PromptUpdate()
  check(shown ~= nil, "asked about the next update too")
  P.Select("Warrior - Update Test")
  P.debug.ui.keep:GetScript("OnClick")(P.debug.ui.keep)
  a = T.ActiveBuild()
  check(a and not a.builtin and a.name == "Warrior - Update Test (kept)" and a.picks[8] == "Improved Tactical Mastery",
    "Keep mine saves your version as your own build: " .. tostring(a and a.name))
  check(P.Selected().name == "Warrior - Update Test (kept)", "and the planner shows it")
  shown = nil
  T.PromptUpdate()
  check(shown == nil, "no more questions about that build")
  StaticPopupDialogs, StaticPopup_Show = nil, nil
  T.DeleteCustom("Warrior - Update Test (kept)")
end


-- first time on a character: one question about the talent planner
do
  local T, P = ns.Talents, ns.TalentPlanner
  local shown
  StaticPopupDialogs = {}
  StaticPopup_Show = function(which, text) shown = { which = which, text = text } end
  local realLevel, realShow = UnitLevel, P.Show
  local level, opened = 5, 0
  UnitLevel = function() return level end
  P.Show = function() opened = opened + 1 end
  TactaraCharDB.talentBuild, TactaraCharDB.talentBuildText = nil, nil
  TactaraCharDB.welcomeDone, TactaraCharDB.welcomeAt10, TactaraDB.welcomeOff = nil, nil, nil

  inCombat = true
  T.Welcome()
  check(shown == nil, "welcome waits for the fight to end")
  inCombat = false
  T.HandleEvent("PLAYER_REGEN_ENABLED")
  check(shown and shown.which == "TACTARA_WELCOME" and shown.text:find("first talent point comes at level 10"), "level 5: asked, mentions level 10")
  local d = StaticPopupDialogs.TACTARA_WELCOME
  check(d.button1 == "Open planner" and d.button2 == "At level 10" and d.button3 == "No thanks", "Open planner / At level 10 / No thanks")
  d.OnCancel()   -- At level 10 (Escape does the same)
  check(TactaraCharDB.welcomeDone and TactaraCharDB.welcomeAt10, "At level 10 is remembered")
  shown = nil
  T.Welcome()
  check(shown == nil, "asked only once per character")
  T.HandleEvent("PLAYER_LEVEL_UP", 9)
  check(shown == nil, "not at level 9")
  T.HandleEvent("PLAYER_LEVEL_UP", 10)
  runTimers()
  check(shown and shown.which == "TACTARA_WELCOME_10" and shown.text:find("first talent point"), "asked again at level 10")
  StaticPopupDialogs.TACTARA_WELCOME_10.OnAccept()
  check(opened == 1 and TactaraCharDB.welcomeAt10 == nil, "and it opens the planner")

  level, shown = 12, nil
  TactaraCharDB.welcomeDone = nil
  T.Welcome()
  d = StaticPopupDialogs.TACTARA_WELCOME
  check(shown and shown.text:find("Pick a talent build") and d.button2 == "Later" and d.OnCancel == nil, "level 12: Open planner / Later / No thanks")
  check(not TactaraCharDB.welcomeDone, "Later asks again next login")
  d.OnAlt()
  check(TactaraCharDB.welcomeDone, "No thanks: never again on this character")
  TactaraCharDB.welcomeDone = nil
  T.Welcome()
  StaticPopupDialogs.TACTARA_WELCOME.OnAccept()
  check(opened == 2 and TactaraCharDB.welcomeDone, "Open planner opens it and counts as answered")

  TactaraCharDB.welcomeDone, shown = nil, nil
  T.SetActive("Warrior - Arms")
  T.Welcome()
  check(shown == nil, "not asked when you already follow a build")
  TactaraCharDB.talentBuild, TactaraCharDB.talentBuildText = nil, nil
  TactaraDB.welcomeOff = true
  T.Welcome()
  check(shown == nil, "not asked when turned off for all characters")
  TactaraDB.welcomeOff, TactaraCharDB.welcomeDone = nil, true
  UnitLevel, P.Show = realLevel, realShow
  StaticPopupDialogs, StaticPopup_Show = nil, nil
end


-- level 60: Tactara's level 60 build for your spec, asked about once
do
  local T, P = ns.Talents, ns.TalentPlanner
  local shown
  StaticPopupDialogs = {}
  StaticPopup_Show = function(which, text) shown = { which = which, text = text } end
  local realLevel, realShow, realSelect, realClass, realActive = UnitLevel, P.Show, P.Select, ns.GetClassToken, ns.activeName
  local level, opened, picked = 59, 0, nil
  UnitLevel = function() return level end
  P.Show = function() opened = opened + 1 end
  P.Select = function(name) picked = name end
  TactaraCharDB.level60Asked = nil
  T.SetActive("Warrior - Arms")
  check(T.IsLevel60(T.GetBuild("Warrior - Arms (level 60)")) and not T.IsLevel60(T.GetBuild("Warrior - Arms")), "level 60 builds are marked")
  check(T.Level60For().name == "Warrior - Arms (level 60)", "Arms leveling -> Arms level 60")
  T.AskLevel60()
  check(shown == nil, "not before 60")
  level = 60
  inCombat = true
  T.AskLevel60()
  check(shown == nil and not TactaraCharDB.level60Asked, "waits for the fight to end")
  inCombat = false
  T.HandleEvent("PLAYER_REGEN_ENABLED")
  check(shown and shown.which == "TACTARA_LEVEL60" and shown.text:find("Warrior %- Arms %(level 60%)") and shown.text:find("class trainer"),
    "at 60: names the build and the respec")
  local d = StaticPopupDialogs.TACTARA_LEVEL60
  check(d.button1 == "Open planner" and d.button2 == "No thanks" and d.button3 == nil, "Open planner / No thanks")
  d.OnAccept()
  check(opened == 1 and picked == "Warrior - Arms (level 60)", "Open planner shows that build")
  check(TactaraCharDB.talentBuild == "Warrior - Arms", "nothing switched by itself")
  shown = nil
  T.AskLevel60()
  check(shown == nil, "asked once per character")
  TactaraCharDB.level60Asked = nil
  T.HandleEvent("PLAYER_LEVEL_UP", 60)
  runTimers()
  check(shown and shown.which == "TACTARA_LEVEL60", "asked when you reach 60")
  shown = nil
  TactaraCharDB.level60Asked = nil
  T.SetActive("Warrior - Fury (level 60)")
  T.AskLevel60()
  check(shown == nil, "not asked when you already follow a level 60 build")
  -- Feral: Cat or Bear by your rotation
  ns.GetClassToken = function() return "DRUID" end
  T.SetActive("Druid - Feral")
  ns.activeName = "Druid - Feral (Bear)"
  check(T.Level60For().name == "Druid - Feral Bear (level 60)", "bear rotation -> Bear build")
  ns.activeName = "Druid - Feral (Cat)"
  check(T.Level60For().name == "Druid - Feral Cat (level 60)", "cat rotation -> Cat build")
  ns.GetClassToken = realClass
  ns.activeName = realActive
  -- the planner groups the list
  P.Show, P.Select = realShow, realSelect
  T.SetActive("Warrior - Arms")
  P.Show()
  P.Select("Warrior - Arms (level 60)")
  local list = table.concat(P.listText, ",")
  check(list:find("^%[Leveling%],Arms,Fury,Protection,Update Test,%[Level 60%],Arms %(level 60%),Fury %(level 60%),Protection %(level 60%),%[Yours%]"),
    "planner list: leveling, then level 60: " .. list)
  local ui = P.debug.ui
  check(ui.orderTitle:GetText() == "Point by point (level 60)" and ui.info:GetText():find("For level 60%."), "level 60 build: numbered by point, says it's for 60: " .. tostring(ui.info:GetText()))
  ui.copy:GetScript("OnClick")(ui.copy)
  local copied = P.Selected()
  check(copied and not copied.builtin and T.IsLevel60(copied) and copied.name == "Warrior - Arms (level 60) 2", "a copy of a level 60 build stays level 60: " .. tostring(copied and copied.name))
  check(table.concat(P.listText, ","):find("%[Yours%].*Warrior %- Arms %(level 60%) 2"), "and is listed under Yours")
  T.DeleteCustom(copied.name)
  P.Select("Warrior - Arms")
  check(ui.orderTitle:GetText() == "Level by level", "leveling build: level by level")
  TactaraCharDB.level60Asked = true
  UnitLevel = realLevel
  StaticPopupDialogs, StaticPopup_Show = nil, nil
end


-- what's new after an update, and the key question on a character with no key
do
  local W, T = ns.Welcome, ns.Talents
  -- the in-game copy matches CHANGELOG.md (run tests/make_whats_new.py after editing it)
  local log = io.open(root .. "/../CHANGELOG.md"):read("a")
  local secs, cur = {}, nil
  for line in (log .. "\n"):gmatch("([^\n]*)\n") do
    local v = line:match("^## (%d+%.%d+%.%d+)%s*$")
    if v then cur = { version = v, lines = {} }; secs[#secs + 1] = cur
    elseif cur and line:match("%S") then cur.lines[#cur.lines + 1] = (line:gsub("%s+$", "")) end
  end
  local same = #ns.WHATS_NEW == 3
  for i, s in ipairs(ns.WHATS_NEW) do
    same = same and secs[i] and secs[i].version == s.version and table.concat(secs[i].lines, "\n") == table.concat(s.lines, "\n")
  end
  check(same, "WhatsNew.lua matches the newest CHANGELOG.md sections (run tests/make_whats_new.py)")
  check(ns.WHATS_NEW[1].version == ns.VERSION, "the changelog has a section for " .. ns.VERSION)

  check(W.Newer("0.16.0", "0.15.0") and W.Newer("0.16.1", "0.16.0") and W.Newer("1.0.0", "0.99.9")
    and not W.Newer("0.15.0", "0.15.0") and not W.Newer("0.9.0", "0.10.0"), "versions compare by number")
  check(W.Format("- **Learn all:** use `/tac new` now") == "• |cffffd100Learn all:|r use |cffffd100/tac new|r now"
    and W.Format("  - nested") == "      - nested", "changelog markdown as game text")

  -- once per update
  local realFresh, realPrev = ns.freshInstall, ns.previousVersion
  TactaraDB.whatsNewSeen, TactaraDB.whatsNewOff = nil, nil
  ns.freshInstall, ns.previousVersion = true, nil
  check(W.CheckWhatsNew() == false and TactaraDB.whatsNewSeen == ns.VERSION, "fresh install: nothing to show")
  TactaraDB.whatsNewSeen = nil
  ns.freshInstall, ns.previousVersion = false, ns.WHATS_NEW[3].version
  inCombat = true
  check(W.CheckWhatsNew() == false and TactaraDB.whatsNewSeen == nil, "waits for the fight to end")
  inCombat = false
  W.HandleEvent("PLAYER_REGEN_ENABLED")
  local body = W.frame and W.frame.body:GetText() or ""
  check(W.frame and W.frame:IsShown() and body:find("Tactara " .. ns.WHATS_NEW[1].version, 1, true)
    and body:find("Tactara " .. ns.WHATS_NEW[2].version, 1, true) and not body:find("Tactara " .. ns.WHATS_NEW[3].version, 1, true),
    "shows every version since the one you had: " .. body:sub(1, 80))
  check(TactaraDB.whatsNewSeen == ns.VERSION, "and remembers it")
  check(W.frame.title:GetText():find("^|cff4fc3f7Tactara|r ") and W.frame.tactaraLogo
    and W.frame.tactaraLogo._texture == ns.Style.ICON, "title: Tactara in cyan, the logo beside it")
  W.frame:Hide()
  check(W.CheckWhatsNew() == false and not W.frame:IsShown(), "only once")
  TactaraDB.whatsNewSeen, TactaraDB.whatsNewOff = nil, true
  check(W.CheckWhatsNew() == false and not W.frame:IsShown() and TactaraDB.whatsNewSeen == ns.VERSION, "turned off")
  TactaraDB.whatsNewOff = nil
  W.frame.show:SetChecked(false)
  W.frame.show:GetScript("OnClick")(W.frame.show)
  check(TactaraDB.whatsNewOff == true, "the checkbox in the window turns it off")
  W.frame.show:SetChecked(true)
  W.frame.show:GetScript("OnClick")(W.frame.show)
  check(TactaraDB.whatsNewOff == nil, "and back on")
  SlashCmdList.TACTARA("new")
  check(W.frame:IsShown() and W.frame.body:GetText():find("Tactara " .. ns.VERSION, 1, true), "/tac new shows it any time")
  W.frame:Hide()
  ns.freshInstall, ns.previousVersion = realFresh, realPrev

  -- the key window: one-button, AoE and interrupt keys, and Remove
  local shown = {}
  StaticPopupDialogs = {}
  StaticPopup_Show = function(which, text) shown[#shown + 1] = { which = which, text = text } end
  local realBinds, realSettingsKey, realCapture = TactaraCharDB.binds, ns.GetSettingsKey, ns.StartKeyCapture
  local captured
  ns.StartKeyCapture = function(which) captured = which end
  ns.GetSettingsKey = function() return nil end
  TactaraCharDB.binds = { main = "F" }
  TactaraCharDB.keyAsked, TactaraDB.welcomeOff = nil, nil
  check(W.AskKey() == false and not W.keyFrame, "not asked when you have a key")
  TactaraCharDB.binds = {}
  TactaraDB.welcomeOff = true
  check(W.AskKey() == false and not W.keyFrame, "not asked when first-time questions are off")
  TactaraDB.welcomeOff = nil
  inCombat = true
  check(W.AskKey() == false and not W.keyFrame, "never in combat")
  inCombat = false
  W.HandleEvent("PLAYER_REGEN_ENABLED")
  local kf = W.keyFrame
  check(kf and kf:IsShown() and kf.intro:GetText():find("one key"), "asked after the fight: the key window")
  check(kf.keys.main and kf.keys.aoe and kf.keys.interrupt and kf.remove, "three key buttons and Remove")
  check(kf.keys.main:GetText() == "Not set (click)" and kf.keys.aoe:GetText() == "Not set (click)"
    and kf.keys.interrupt:GetText() == "Not set (click)" and kf.remove:GetText() == "Remove", "the buttons say what they do")
  check(kf.done:GetText() == "Done" and kf.no:GetText() == "No thanks", "Done / No thanks")
  check(kf.title:GetText() == "|cff4fc3f7Tactara|r keys" and kf.tactaraLogo, "key window title: the logo and the cyan name")
  check(W.Busy(), "busy while the window is up")
  -- the planner question waits for it
  TactaraCharDB.welcomeDone, TactaraCharDB.talentBuild, TactaraCharDB.talentBuildText = nil, nil, nil
  T.Welcome()
  check(#shown == 0, "the planner question waits for the key window")
  -- pick each key from the window
  kf.keys.main:GetScript("OnClick")(kf.keys.main, "LeftButton")
  check(captured == "main", "One-button key starts picking that key")
  ns.SetTactaraKey("main", "1"); ns.afterKeyCapture()
  check(kf.keys.main:GetText() == "1", "the button shows the new key")
  kf.keys.aoe:GetScript("OnClick")(kf.keys.aoe, "LeftButton")
  check(captured == "aoe", "AoE key")
  ns.SetTactaraKey("aoe", "2"); ns.afterKeyCapture()
  kf.keys.interrupt:GetScript("OnClick")(kf.keys.interrupt, "LeftButton")
  check(captured == "interrupt", "Interrupt key")
  ns.SetTactaraKey("interrupt", "3"); ns.afterKeyCapture()
  check(kf.keys.aoe:GetText() == "2" and kf.keys.interrupt:GetText() == "3", "all three show their keys")
  kf.keys.aoe:GetScript("OnClick")(kf.keys.aoe, "RightButton")
  check(not TactaraCharDB.binds.aoe and kf.keys.aoe:GetText() == "Not set (click)", "right-click clears one key")
  kf.remove:GetScript("OnClick")(kf.remove)
  check(next(TactaraCharDB.binds) == nil and kf.keys.main:GetText() == "Not set (click)", "Remove gives every key back")
  SlashCmdList.TACTARA("bind")   -- keys set elsewhere show up too
  ns.SetTactaraKey("main", "F")
  check(kf.keys.main:GetText() == "F", "a key set with /tac bind shows in the window")
  check(#shown == 0 and W.Busy(), "the planner question still waits")
  kf.done:GetScript("OnClick")(kf.done)
  runTimers()
  check(not kf:IsShown() and TactaraCharDB.keyAsked, "Done with a key: closed, not asked again")
  check(#shown == 1 and shown[1].which == "TACTARA_WELCOME", "then the planner question")
  check(not W.Busy(), "not busy any more")
  kf:GetScript("OnHide")(kf)
  check(#shown == 1, "closing twice does nothing more")
  -- Done with no key, Escape, and No thanks
  shown = {}
  TactaraCharDB.binds, TactaraCharDB.keyAsked = {}, nil
  W.AskKey()
  kf.done:GetScript("OnClick")(kf.done)
  check(not TactaraCharDB.keyAsked and not W.Busy() and not kf:IsShown(), "Done with no key: asked again next time")
  W.AskKey()
  kf:Hide(); kf:GetScript("OnHide")(kf)   -- Escape
  check(not TactaraCharDB.keyAsked and not W.Busy(), "Escape: the same")
  TactaraCharDB.binds = { interrupt = "5" }
  W.AskKey()
  kf.done:GetScript("OnClick")(kf.done)
  check(TactaraCharDB.keyAsked, "any of the three keys counts")
  TactaraCharDB.binds, TactaraCharDB.keyAsked = {}, nil
  chat = {}
  W.AskKey()
  kf.no:GetScript("OnClick")(kf.no)
  check(TactaraCharDB.keyAsked and not kf:IsShown() and table.concat(chat, " "):find("reset keybinds"), "No thanks: not asked again")
  check(W.AskKey() == false and not kf:IsShown(), "and it isn't")
  -- /tac reset keybinds opens it again, whatever you answered, and keeps your keys
  TactaraCharDB.binds = { main = "F" }
  TactaraDB.welcomeOff = true
  SlashCmdList.TACTARA("reset keybinds")
  check(kf:IsShown() and not TactaraCharDB.keyAsked and TactaraCharDB.binds.main == "F" and kf.keys.main:GetText() == "F",
    "/tac reset keybinds: the window again, keys kept")
  kf.done:GetScript("OnClick")(kf.done)
  SlashCmdList.TACTARA("keys")
  check(kf:IsShown(), "/tac keys too")
  kf.done:GetScript("OnClick")(kf.done)
  SlashCmdList.TACTARA("reset keys")
  check(kf:IsShown(), "/tac reset keys too")
  kf.done:GetScript("OnClick")(kf.done)
  inCombat = true
  chat = {}
  SlashCmdList.TACTARA("reset keybinds")
  check(not kf:IsShown() and table.concat(chat, " "):find("out of combat"), "not in combat")
  inCombat = false
  ns.sequenceIndex = 3
  SlashCmdList.TACTARA("reset")
  check(not kf:IsShown(), "plain /tac reset still restarts the sequence, no window")
  runTimers()
  TactaraDB.welcomeOff = nil
  TactaraCharDB.binds, ns.GetSettingsKey, ns.StartKeyCapture = realBinds, realSettingsKey, realCapture
  ns.ApplyBindings()
  TactaraCharDB.welcomeDone, TactaraCharDB.keyAsked = true, true
  StaticPopupDialogs, StaticPopup_Show = nil, nil
end


-- dual spec: each spec keeps its own build and rotation choice
do
  local T = ns.Talents
  local group = 1
  C_SpecializationInfo = { GetActiveSpecGroup = function() return group end }
  TactaraCharDB.specGroup, TactaraCharDB.specs = nil, nil
  T.SetActive("Warrior - Arms")
  TactaraCharDB.active = "Warrior - Arms"
  T.HandleEvent("PLAYER_LOGIN")
  check(TactaraCharDB.specGroup == 1 and TactaraCharDB.talentBuild == "Warrior - Arms", "first time: your build stays with the spec you're in")
  group = 2
  chat = {}
  T.HandleEvent("ACTIVE_TALENT_GROUP_CHANGED")
  check(TactaraCharDB.talentBuild == nil and TactaraCharDB.active == "auto", "secondary spec starts with no build and auto rotation")
  check(table.concat(chat, " "):find("Switched to your secondary spec"), "and says so: " .. table.concat(chat, " | "))
  T.SetActive("Warrior - Protection")
  TactaraCharDB.active = "Warrior - Protection"
  group = 1
  T.HandleEvent("ACTIVE_TALENT_GROUP_CHANGED")
  check(TactaraCharDB.talentBuild == "Warrior - Arms" and TactaraCharDB.active == "Warrior - Arms", "back to primary: its build and rotation come back")
  group = 2
  T.HandleEvent("PLAYER_SPECIALIZATION_CHANGED")
  check(TactaraCharDB.talentBuild == "Warrior - Protection" and TactaraCharDB.active == "Warrior - Protection", "secondary remembered too")
  T.HandleEvent("TRAIT_CONFIG_UPDATED")
  check(TactaraCharDB.talentBuild == "Warrior - Protection", "nothing moves without a real switch")
  -- the glow only shows on your active spec's tab
  ns.TalentTest.setEarned(20)
  local glowed = 0
  local realShow, realHide = ns.ShowButtonGlow, ns.HideButtonGlow
  ns.ShowButtonGlow = function() glowed = glowed + 1 end
  ns.HideButtonGlow = function() end
  local shownConfig = 999
  PlayerSpellsFrame = { TalentsFrame = {
    IsVisible = function() return true end,
    GetConfigID = function() return shownConfig end,
    GetTalentButtonByNodeID = function(_, id) return { id = id } end,
  } }
  T.UpdateTalentWindowGlow()
  check(glowed == 0, "no glow while looking at your other spec's tab")
  shownConfig = 5914191
  T.UpdateTalentWindowGlow()
  check(glowed == 1, "glow on your active spec's tab")
  ns.ShowButtonGlow, ns.HideButtonGlow = realShow, realHide
  PlayerSpellsFrame = nil
  group = 1
  T.HandleEvent("ACTIVE_TALENT_GROUP_CHANGED")
  C_SpecializationInfo = nil
end

-- the same settings on all your characters
do
  local Pr = ns.Profiles
  UnitName = function() return "Zud" end
  GetRealmName = function() return "Forever" end
  TactaraCharDB.binds = { main = "1" }
  Pr.Save()
  local me = TactaraDB.characters["Zud - Forever"]
  check(me and me.class == "WARRIOR" and me.settings.binds.main == "1", "this character's settings are kept for your others")
  check(me.settings.talentBuild == nil and me.settings.active == nil and me.settings.specs == nil, "rotation and talent builds aren't part of them")
  TactaraDB.characters["Alt - Forever"] = { class = "MAGE", level = 30, saved = 999999, settings = {
    binds = { main = "F", aoe = "G" }, helperScale = 1.5, keyIcons = 0, minimapButton = false,
    helperPos = { point = "TOP", relPoint = "TOP", x = 10, y = -50 }, talentAutoLearn = true } }
  local keepBuild, keepActive = TactaraCharDB.talentBuild, TactaraCharDB.active
  local others = Pr.Others()
  check(#others == 1 and others[1].key == "Alt - Forever", "lists your other characters, not this one")
  local w = Pr.ShowCopy()
  check(w and w:IsShown() and w.buttons[1] and w.buttons[1]._text:find("Alt %- Forever") and w.buttons[1]._text:find("Mage"),
    "copy window: " .. tostring(w and w.buttons[1] and w.buttons[1]._text))
  chat = {}
  w.buttons[1]:GetScript("OnClick")(w.buttons[1])
  check(TactaraCharDB.binds.main == "F" and TactaraCharDB.binds.aoe == "G" and TactaraCharDB.helperScale == 1.5
    and TactaraCharDB.keyIcons == 0 and TactaraCharDB.minimapButton == false and TactaraCharDB.talentAutoLearn == true
    and TactaraCharDB.helperPos.point == "TOP", "settings copied")
  check(TactaraCharDB.talentBuild == keepBuild and TactaraCharDB.active == keepActive, "rotation and talent build untouched")
  check(table.concat(chat, " "):find("Copied Tactara settings from Alt %- Forever") and not w:IsShown(), "says so and closes")
  TactaraDB.characters["Alt - Forever"].settings.binds.main = "Z"
  check(TactaraCharDB.binds.main == "F", "a real copy, not linked to the other character")
  TactaraCharDB.keyIcons = 3
  SlashCmdList.TACTARA("copy alt")
  check(TactaraCharDB.keyIcons == 0, "/tac copy alt")
  chat = {}
  SlashCmdList.TACTARA("copy nobody")
  check(table.concat(chat, " "):find("No character called"), "/tac copy with an unknown name")
  -- default for new characters
  SlashCmdList.TACTARA("defaults")
  check(TactaraDB.defaultSettings and TactaraDB.defaultSettings.binds.main == "Z", "/tac defaults saves this character's settings")
  local saved = TactaraCharDB
  TactaraCharDB = nil
  fire("ADDON_LOADED", "Tactara")
  check(ns.startedFromDefault and TactaraCharDB.binds.main == "Z" and TactaraCharDB.keyIcons == 0 and TactaraCharDB.active == "auto"
    and TactaraCharDB.talentBuild == nil, "a new character starts from your defaults")
  TactaraCharDB = saved
  fire("ADDON_LOADED", "Tactara")
  check(ns.startedFromDefault == false, "an existing character isn't touched")
  SlashCmdList.TACTARA("defaults clear")
  check(TactaraDB.defaultSettings == nil, "/tac defaults clear")
  UnitName, GetRealmName = nil, nil
end

-- trainer reminder: spells you can learn now, the ones your rotation uses first
do
  local R = ns.Reminders
  local realSB, realRotSpells, realLevel = C_SpellBook, ns.RotationSpells, UnitLevel
  local LEVELS = { [6343] = 6, [1715] = 8, [72] = 10, [12294] = 40, [6552] = 4 }
  local ITEMS = {
    [1] = { itemType = 1, name = "Heroic Strike", spellID = 78 },
    [2] = { itemType = 2, name = "Thunder Clap", spellID = 6343 },
    [3] = { itemType = 2, name = "Hamstring", spellID = 1715 },
    [4] = { itemType = 2, name = "Mortal Strike", spellID = 12294 },
    [5] = { itemType = 2, name = "Shield Bash", spellID = 72 },
    [6] = { itemType = 2, name = "Pummel", spellID = 6552 },   -- other spec's line
  }
  Enum.SpellBookSpellBank = { Player = 0 }
  C_SpellBook = {
    FindSpellBookSlotForSpell = realSB.FindSpellBookSlotForSpell,
    GetNumSpellBookSkillLines = function() return 2 end,
    GetSpellBookSkillLineInfo = function(i)
      if i == 1 then return { name = "Warrior", itemIndexOffset = 0, numSpellBookItems = 5 } end
      return { name = "Fury", itemIndexOffset = 5, numSpellBookItems = 1, offSpecID = 72 }
    end,
    GetSpellBookItemInfo = function(slot) return ITEMS[slot] or { itemType = 1 } end,
  }
  C_Spell.GetSpellLevelLearned = function(id) return LEVELS[id] or 0 end
  ns.RotationSpells = function() return { "Heroic Strike" }, { "Thunder Clap", "Mortal Strike" } end
  UnitLevel = function() return 12 end
  ns.ClearKnownCache()

  local list = R.TrainerSpells(12)
  local names = {}
  for _, x in ipairs(list) do names[#names + 1] = x.name end
  check(table.concat(names, ",") == "Thunder Clap,Hamstring,Shield Bash", "waiting at level 12, rotation first: " .. table.concat(names, ","))
  local msg = R.TrainerMessage(list)
  check(msg:find("^3 spells are waiting at your class trainer") and msg:find("Thunder Clap|r %(in your rotation%); Hamstring, Shield Bash%.$"),
    "trainer message: " .. msg)
  check(#R.TrainerSpells(5) == 0 and #R.TrainerSpells(40) == 4, "learn levels decide what's waiting")
  check(R.FutureSpells()[1].line == "Warrior" and #R.FutureSpells() == 4, "other spec's spells left out")
  local okP, probe = pcall(ns.ProbeReminders)
  check(okP and probe:find("waiting at the trainer now %(3") and probe:find("Thunder Clap%*"), "/tac probe reminders: " .. tostring(probe))
  check(okP and probe:find("== Supplies ==") and probe:find("running low now %(both%): nothing"), "/tac probe reminders: supplies too")

  chat = {}
  TactaraCharDB.trainerReminder = true
  R.HandleEvent("PLAYER_LEVEL_UP", 12)
  runTimers()
  check(table.concat(chat, " "):find("3 spells are waiting at your class trainer"), "a line after a level-up")
  chat = {}
  TactaraCharDB.trainerReminder = false
  R.HandleEvent("PLAYER_LEVEL_UP", 12)
  runTimers()
  check(#chat == 0, "turned off: nothing")
  SlashCmdList.TACTARA("trainer")
  check(table.concat(chat, " "):find("waiting at your class trainer"), "/tac trainer lists them anyway")
  SlashCmdList.TACTARA("trainer on")
  check(TactaraCharDB.trainerReminder == true, "/tac trainer on")
  check(R.CheckTrainer(12, true) == true, "at login when your rotation is waiting on a spell")
  ns.RotationSpells = function() return {}, {} end
  check(R.CheckTrainer(12, true) == false and R.CheckTrainer(12) == true, "at login quiet when it's only other spells")
  LEVELS = {}
  chat = {}
  SlashCmdList.TACTARA("trainer")
  check(table.concat(chat, " "):find("Nothing new is waiting"), "nothing waiting")

  -- older spellbook functions
  C_SpellBook = { FindSpellBookSlotForSpell = realSB.FindSpellBookSlotForSpell, GetSpellBookItemInfo = realSB.GetSpellBookItemInfo }
  GetNumSpellTabs = function() return 1 end
  GetSpellTabInfo = function() return "Arms", "tex", 0, 3, false, 0 end
  GetSpellBookItemInfo = function(slot) if slot == 2 then return "FUTURESPELL", 6343 end return "SPELL", 78 end
  GetSpellBookItemName = function(slot) return slot == 2 and "Thunder Clap" or "Heroic Strike" end
  GetSpellAvailableLevel = function(slot) return slot == 2 and 6 or 1 end
  C_Spell.GetSpellLevelLearned = nil
  local old = R.TrainerSpells(12)
  check(#old == 1 and old[1].name == "Thunder Clap" and old[1].level == 6, "older spellbook functions work too")
  GetNumSpellTabs, GetSpellTabInfo, GetSpellBookItemInfo, GetSpellBookItemName, GetSpellAvailableLevel = nil, nil, nil, nil, nil

  C_SpellBook, ns.RotationSpells, UnitLevel = realSB, realRotSpells, realLevel
  Enum.SpellBookSpellBank = nil
  ns.ClearKnownCache()
end

-- before the pull: missing buffs, pet, poisons and imbues (Tactara only says so)
do
  local R = ns.Reminders
  local env = { isKnown = function() return true end, hasBuff = function() return nil end }
  local comp = ns.Compile(ns.Parse([[
name: prep test
[priority]
/cast Call Pet @nopet
/cast Demon Armor @missing Demon Armor
/cast Searing Totem @missing Searing Totem
/cast Slice and Dice @missing Slice and Dice @combo 1
/cast Battle Shout @missing Battle Shout
/cast Ice Barrier @missing Ice Barrier
/cast Shadow Bolt
]]), "main", env)
  local realMain = ns.compiled.main
  local realExists, realClass, realInv, realItem = UnitExists, UnitClass, GetInventoryItemID, C_Item
  local petUp = false
  UnitExists = function(u) if u == "pet" then return petUp end return realExists(u) end
  for k in pairs(playerAuras) do playerAuras[k] = nil end
  for k in pairs(usable) do usable[k] = nil end
  for k in pairs(cooldowns) do cooldowns[k] = nil end
  C_Spell.GetSpellPowerCost = function(name) if name == "Battle Shout" then return { { type = 1, name = "RAGE" } } end return { { type = 0 } } end
  usable["Battle Shout"] = { false, true }   -- no rage before a fight
  cooldowns["Ice Barrier"] = { isActive = true, isOnGCD = false, startTime = now - 1, duration = 1000 }

  local function texts(list) local t = {} for _, x in ipairs(list) do t[#t + 1] = x.text end return table.concat(t, ",") end
  check(texts(R.PrePullList(comp)) == "your pet,Demon Armor", "pet first, then buffs; no totems, combat lines, rage-less shouts or cooldowns: " .. texts(R.PrePullList(comp)))
  check(R.PrePullList(comp)[1].spell == "Call Pet", "the pet reminder has the spell's icon")
  usable["Battle Shout"] = nil
  check(texts(R.PrePullList(comp)) == "your pet,Demon Armor,Battle Shout", "a shout counts when you have the rage")
  usable["Battle Shout"] = { false, true }
  petUp = true
  playerAuras["Demon Armor"] = { expirationTime = now + 600, duration = 1800 }
  check(#R.PrePullList(comp) == 0, "all set: nothing")
  playerAuras["Demon Armor"] = "hidden"
  check(#R.PrePullList(comp) == 0, "hidden by the game: no guess")
  playerAuras["Demon Armor"] = nil

  -- under the helper popup and in chat
  ns.compiled.main = comp
  inCombat, hasTarget = false, true
  TactaraCharDB.prePull = "both"
  check(R.PrePullText() and R.PrePullText():find("Before the pull:|r Demon Armor$"), "popup line: " .. tostring(R.PrePullText()))
  TactaraCharDB.showHelper, TactaraCharDB.locked = true, true
  ns.UpdateHelperPopup()
  check(ns.helperPopup.label._text:find("Before the pull"), "shown under the helper popup")
  -- hide while mounted (off unless you turn it on)
  TactaraCharDB.showDisplay = true
  ns.compiled.main = realMain      -- a rotation with key steps, so the key bar has something to show
  local mounted, taxi = true, false
  IsMounted = function() return mounted end
  UnitOnTaxi = function() return taxi end
  ns.UpdateHelperPopup(); ns.UpdateDisplay()
  check(ns.helperPopup:IsShown() and ns.display:IsShown(), "mounted, setting off: both displays stay")
  SlashCmdList.TACTARA("mounted on")
  check(TactaraCharDB.hideMounted == true and not ns.helperPopup:IsShown() and not ns.display:IsShown(), "/tac mounted on: both hide on a mount")
  mounted = false
  ns.HelperRefresh()
  check(ns.helperPopup:IsShown() and ns.display:IsShown(), "off the mount: back")
  taxi = true
  ns.HelperRefresh()
  check(not ns.helperPopup:IsShown() and not ns.display:IsShown(), "on a flight path: hidden")
  taxi, mounted = false, true
  inCombat = true
  ns.HelperRefresh()
  check(ns.helperPopup:IsShown() and ns.display:IsShown(), "mounted in a fight: shown")
  inCombat = false
  TactaraCharDB.locked = false
  ns.HelperRefresh()
  check(ns.helperPopup:IsShown(), "unlocked to move them: shown")
  TactaraCharDB.locked = true
  SlashCmdList.TACTARA("mounted off")
  ns.HelperRefresh()
  check(TactaraCharDB.hideMounted == false and ns.helperPopup:IsShown(), "/tac mounted off")
  IsMounted, UnitOnTaxi = nil, nil
  ns.compiled.main = comp
  hasTarget = false
  check(R.PrePullText() == nil, "no enemy picked: nothing")
  ns.UpdateHelperPopup()
  hasTarget = true
  inCombat = true
  check(R.PrePullText() == nil, "in a fight: nothing")
  inCombat = false
  R.ResetChatThrottle()
  chat = {}
  R.HandleEvent("PLAYER_TARGET_CHANGED")
  check(table.concat(chat, " "):find("Before you pull: Demon Armor%."), "chat line when you pick an enemy: " .. table.concat(chat, " | "))
  check(R.ChatPrePull() == false, "not again right away")
  now = now + 61
  check(R.ChatPrePull() == false, "the same reminder waits five minutes")
  petUp = false
  check(R.ChatPrePull() == true, "something new after a minute")
  now = now + 301
  check(R.ChatPrePull() == true, "the same again after five minutes")
  IsMounted = function() return true end
  now = now + 301
  check(R.ChatPrePull() == false and R.PrePullText() ~= nil, "mounted: no chat, the popup line stays")
  IsMounted = nil
  SlashCmdList.TACTARA("prepull helper")
  check(TactaraCharDB.prePull == "helper" and R.ChatPrePull() == false and R.PrePullText() ~= nil, "helper only: no chat")
  SlashCmdList.TACTARA("prepull off")
  check(TactaraCharDB.prePull == "off" and R.PrePullText() == nil, "off")
  SlashCmdList.TACTARA("prepull")
  check(TactaraCharDB.prePull == "both", "/tac prepull turns it back on")
  petUp = true

  -- poisons and weapon imbues
  local inv = { [16] = 1002, [17] = 1002 }
  local LOC = { [1002] = "INVTYPE_WEAPON", [1003] = "INVTYPE_SHIELD" }
  GetInventoryItemID = function(_, slot) return inv[slot] end
  C_Item = { GetItemInfoInstant = function(id) return id, "Weapon", "x", LOC[id] end }
  local mh, oh = false, false
  GetWeaponEnchantInfo = function() return mh, 0, 0, 0, oh, 0, 0, 0 end
  UnitClass = function() return "Rogue", "ROGUE", 4 end
  known["Deadly Poison"] = true
  ns.ClearKnownCache()
  local function weapon() local l = R.PrePullList(comp); return l[#l] and l[#l].kind == "weapon" and l[#l] end
  check(weapon() and weapon().text == "a poison on your weapons" and weapon().spell == "Deadly Poison", "rogue: no poison on")
  mh = true
  check(weapon(), "off hand still bare")
  oh = true
  check(not weapon(), "both coated")
  mh, oh = false, false
  playerAuras["Deadly Poison"] = { expirationTime = now + 3000, duration = 3600 }
  check(not weapon(), "poison as a buff on you counts")
  playerAuras["Deadly Poison"] = nil
  UnitClass = function() return "Shaman", "SHAMAN", 7 end
  known["Rockbiter Weapon"] = true
  inv[17] = 1003
  mh = true
  ns.ClearKnownCache()
  check(not weapon(), "shaman with a shield: main hand is enough")
  mh = false
  check(weapon() and weapon().text == "a weapon imbue" and weapon().spell == "Rockbiter Weapon", "shaman: no imbue")
  GetWeaponEnchantInfo = function() error("secret value") end
  check(not weapon(), "hidden: no guess")
  known["Rockbiter Weapon"], known["Deadly Poison"] = nil, nil
  ns.ClearKnownCache()
  GetWeaponEnchantInfo = function() return false end
  check(not weapon(), "no imbue learned yet: nothing")

  UnitExists, UnitClass, GetInventoryItemID, C_Item = realExists, realClass, realInv, realItem
  GetWeaponEnchantInfo, C_Spell.GetSpellPowerCost = nil, nil
  ns.compiled.main = realMain
  for k in pairs(usable) do usable[k] = nil end
  for k in pairs(cooldowns) do cooldowns[k] = nil end
  hasTarget = false
  R.ResetChatThrottle()
end

-- buffs running low, and the check after a fight (every class)
do
  local R = ns.Reminders
  local env = { isKnown = function() return true end, hasBuff = function() return nil end }
  local function texts(list) local t = {} for _, x in ipairs(list or {}) do t[#t + 1] = x.text end return table.concat(t, ",") end
  local realExists, realClass, realInv, realItem, realMain = UnitExists, UnitClass, GetInventoryItemID, C_Item, ns.compiled.main
  local petUp = true
  UnitExists = function(u) if u == "pet" then return petUp end return realExists(u) end
  for k in pairs(playerAuras) do playerAuras[k] = nil end
  for k in pairs(usable) do usable[k] = nil end
  for k in pairs(cooldowns) do cooldowns[k] = nil end
  now = now + 10000      -- Tactara's own timers from earlier casts are long gone
  inCombat, hasTarget = false, false
  local comp = ns.Compile(ns.Parse([[
name: after test
[priority]
/cast Call Pet @nopet
/cast Seal of Righteousness @missing Seal of Righteousness
/cast Blessing of Might @missing Blessing of Might
/cast Battle Shout @missing Battle Shout
/cast Searing Totem @missing Searing Totem
/cast Shadow Bolt
]]), "main", env)

  check(ns.BuffLowAt(3600) == 300 and ns.BuffLowAt(1800) == 120 and ns.BuffLowAt(600) == 60
    and ns.BuffLowAt(120) == 30 and ns.BuffLowAt(30) == 3 and ns.BuffLowAt(math.huge) == 0, "when a buff counts as running low")
  -- everything up with plenty left
  playerAuras["Seal of Righteousness"] = { expirationTime = now + 25, duration = 30 }
  playerAuras["Blessing of Might"] = { expirationTime = now + 3000, duration = 3600 }
  playerAuras["Battle Shout"] = { expirationTime = now + 100, duration = 120 }
  check(texts(R.PrePullList(comp)) == "" and texts(R.AfterFightList(comp)) == "", "all up: nothing before or after")
  local left, full = ns.BuffTimeLeft("Blessing of Might")
  check(math.floor(left) == 3000 and full == 3600, "time left and full length from the game")
  -- running low
  playerAuras["Blessing of Might"] = { expirationTime = now + 200, duration = 3600 }
  playerAuras["Battle Shout"] = { expirationTime = now + 20, duration = 120 }
  playerAuras["Seal of Righteousness"] = { expirationTime = now + 20, duration = 30 }
  check(texts(R.PrePullList(comp)) == "Blessing of Might (4 min left),Battle Shout (20 sec left)",
    "before the pull: an hour-long Blessing under 5 minutes, a shout under 30 seconds: " .. texts(R.PrePullList(comp)))
  check(texts(R.AfterFightList(comp)) == "Blessing of Might (4 min left),Battle Shout (20 sec left)", "after the fight: the same")
  playerAuras["Blessing of Might"] = { expirationTime = now + 500, duration = 3600 }
  check(not texts(R.PrePullList(comp)):find("Blessing"), "8 minutes left: fine")
  SlashCmdList.TACTARA("buffs low early")
  check(TactaraCharDB.buffLow == "early" and ns.BuffLowAt(3600) == 600 and texts(R.PrePullList(comp)):find("Blessing of Might %(9 min left%)"),
    "/tac buffs low early: an hour-long buff under 10 minutes")
  SlashCmdList.TACTARA("buffs low late")
  check(ns.BuffLowAt(3600) == 150 and ns.BuffLowAt(120) == 15, "late: half")
  SlashCmdList.TACTARA("buffs low off")
  playerAuras["Blessing of Might"] = { expirationTime = now + 60, duration = 3600 }
  check(ns.BuffLowAt(3600) == 0 and not texts(R.PrePullList(comp)):find("Blessing"), "off: a minute left isn't a reminder")
  check(ns.BuffLowAt(30) == 3, "Seals: about to drop, whatever the setting")
  SlashCmdList.TACTARA("buffs low normal")
  check(TactaraCharDB.buffLow == "normal", "back to normal")
  playerAuras["Blessing of Might"] = { expirationTime = 0, duration = 0 }
  check(not texts(R.PrePullList(comp)):find("Blessing") and select(1, ns.BuffTimeLeft("Blessing of Might")) == math.huge,
    "no end time: it stays until you change it")
  -- missing
  for k in pairs(playerAuras) do playerAuras[k] = nil end
  petUp = false
  check(texts(R.PrePullList(comp)) == "your pet,Seal of Righteousness,Blessing of Might,Battle Shout", "before the pull: all of it")
  check(texts(R.AfterFightList(comp)) == "your pet,Blessing of Might,Battle Shout", "after the fight: no Seal (30 seconds), no totem")
  usable["Battle Shout"] = { false, true }
  check(not texts(R.AfterFightList(comp)):find("Battle Shout"), "no rage left over: no shout")
  usable["Battle Shout"] = nil
  playerAuras["Blessing of Might"] = "hidden"
  check(not texts(R.AfterFightList(comp)):find("Blessing"), "hidden by the game: no guess")
  playerAuras["Blessing of Might"] = nil

  -- the reminder itself: a couple of seconds after the fight
  ns.compiled.main = comp
  TactaraCharDB.prePull = "both"
  R.ResetChatThrottle()
  chat = {}
  R.HandleEvent("PLAYER_REGEN_ENABLED"); runTimers()
  check(table.concat(chat, " "):find("After the fight: your pet, Blessing of Might, Battle Shout%."), "chat after the fight: " .. table.concat(chat, " | "))
  check(R.PrePullText() and R.PrePullText():find("After the fight:|r your pet, Blessing of Might, Battle Shout"), "under the helper, no target needed")
  hasTarget = true
  check(R.PrePullText():find("Before the pull:|r your pet, Seal of Righteousness"), "pick an enemy: the before-the-pull line instead")
  check(R.ChatPrePull() == false, "no before-the-pull chat line right on top of it")
  hasTarget = false
  chat = {}
  check(R.AfterFight() == false and #chat == 0, "the same after the next fight: quiet")
  now = now + 31
  check(R.PrePullText() == nil, "the line goes after 30 seconds")
  now = now + 100
  check(R.AfterFight() == true and table.concat(chat, " "):find("After the fight"), "two minutes later: again")
  petUp = true
  chat = {}
  check(R.AfterFight() == true, "something changed: right away")
  playerAuras["Blessing of Might"] = { expirationTime = now + 3000, duration = 3600 }
  playerAuras["Battle Shout"] = { expirationTime = now + 100, duration = 120 }
  check(R.AfterFight() == false and R.PrePullText() == nil, "all set: nothing")
  playerAuras["Blessing of Might"], playerAuras["Battle Shout"] = nil, nil
  TactaraCharDB.prePull = "helper"
  R.ResetChatThrottle()
  chat = {}
  check(R.AfterFight() == false and #chat == 0 and R.PrePullText():find("After the fight"), "helper only: the line, no chat")
  TactaraCharDB.prePull = "off"
  R.ResetChatThrottle()
  check(R.AfterFight() == false and R.PrePullText() == nil, "off: nothing")
  TactaraCharDB.prePull = "both"
  inCombat = true
  R.ResetChatThrottle()
  check(R.AfterFight() == false, "a new fight already started: nothing")
  inCombat = false
  UnitIsDeadOrGhost = function() return true end
  check(R.AfterFight() == false, "dead: nothing")
  UnitIsDeadOrGhost = nil
  -- the optional sound
  local played = {}
  PlaySound = function(id) played[#played + 1] = id; return true end
  SlashCmdList.TACTARA("sound buffs ready")
  check(TactaraCharDB.buffSound == "ready" and #played == 1, "/tac sound buffs ready")
  played = {}
  R.ResetChatThrottle()
  R.AfterFight()
  check(#played == 1 and played[1] == 8960, "a sound with the after-the-fight reminder")
  played = {}
  R.AfterFight()
  check(#played == 0, "not again for the same reminder")
  R.ResetChatThrottle()
  hasTarget = true
  R.ChatPrePull()
  check(#played == 1, "and with the before-the-pull one")
  hasTarget = false
  SlashCmdList.TACTARA("sound buffs off")
  PlaySound = nil
  SlashCmdList.TACTARA("buffs helper")
  check(TactaraCharDB.prePull == "helper", "/tac buffs works like /tac prepull")
  SlashCmdList.TACTARA("buffs on")

  -- you click a buff off in a fight (or it's dispelled): Tactara's timer can't
  -- see that; the game can, once the fight is over and it's showing your buffs
  ns.SetTrackedSpells(ns.Parse("[priority]\n/cast Frost Armor @missing Frost Armor"))
  local frost = ns.Compile(ns.Parse("name: frost\n[priority]\n/cast Frost Armor @missing Frost Armor"), "main", env)
  for k in pairs(playerAuras) do playerAuras[k] = nil end
  ns.auraLookupsWork = nil
  inCombat = true
  ns.TrackCast("Frost Armor")
  check(ns.CheckLive({ kind = "missing", arg = "Frost Armor" }) == false, "in a fight: Tactara's timer says it's up")
  inCombat = false
  check(texts(R.AfterFightList(frost)) == "", "the game hasn't shown a buff this session: the timer still wins")
  playerAuras["Arcane Intellect"] = { name = "Arcane Intellect", expirationTime = now + 1700, duration = 1800 }
  ns.BuffTimeLeft("Arcane Intellect")
  check(ns.auraLookupsWork == true, "the game showed one of your buffs: lookups work")
  check(texts(R.AfterFightList(frost)) == "Frost Armor", "after the fight: Frost Armor, taken off")
  check(ns.TrackedRemaining("player", "Frost Armor") == nil, "and Tactara's timer for it is dropped")
  hasTarget = true
  check(texts(R.PrePullList(frost)) == "Frost Armor", "before the next pull too")
  check(ns.HasBuff("Frost Armor") == false, "and the opener puts it back up")
  hasTarget = false
  ns.TrackCast("Frost Armor")
  C_Secrets = { ShouldSpellAuraBeSecret = function() return true end }
  check(texts(R.AfterFightList(frost)) == "", "the game says it hides that buff: the timer")
  C_Secrets = { ShouldSpellAuraBeSecret = function() return false end }
  check(texts(R.AfterFightList(frost)) == "Frost Armor", "and when it doesn't: gone")
  C_Secrets = nil
  ns.auraLookupsWork = nil
  C_UnitAuras.GetAuraDataByIndex = function(_, i) if i == 1 then return { name = "Arcane Intellect" } end end
  check(ns.AuraReadable("Frost Armor") == true, "a buff the game lists right now: lookups work")
  C_UnitAuras.GetAuraDataByIndex = function() error("secret value") end
  ns.auraLookupsWork = nil
  check(ns.AuraReadable("Frost Armor") == nil, "the list is hidden: can't tell")
  C_UnitAuras.GetAuraDataByIndex = nil
  inCombat = true
  check(ns.AuraReadable("Frost Armor") == false, "in a fight: never")
  inCombat = false
  playerAuras["Arcane Intellect"] = nil
  ns.auraLookupsWork = nil

  -- buffs that replace each other: the old one's timer goes
  ns.SetTrackedSpells(ns.Parse("[priority]\n/cast Aspect of the Hawk @missing Aspect of the Hawk\n/cast Ice Armor @missing Ice Armor"))
  ns.TrackCast("Aspect of the Hawk")
  check((ns.TrackedRemaining("player", "Aspect of the Hawk") or 0) > 0, "Hawk timed from your cast")
  ns.TrackCast("Aspect of the Cheetah")
  check(ns.TrackedRemaining("player", "Aspect of the Hawk") == nil, "switch to Cheetah: Hawk is gone")
  ns.TrackCast("Ice Armor"); ns.TrackCast("Mage Armor")
  check(ns.TrackedRemaining("player", "Ice Armor") == nil, "Mage Armor ends Ice Armor")

  -- every class: what each built-in rotation keeps up is checked before and after
  GetInventoryItemID = function(_, slot) if slot == 16 then return 1002 end end
  C_Item = { GetItemInfoInstant = function(id) return id, "Weapon", "x", "INVTYPE_WEAPON" end }
  GetWeaponEnchantInfo = function() return false, 0, 0, 0, false, 0, 0, 0 end
  known["Instant Poison"], known["Rockbiter Weapon"] = true, true
  ns.ClearKnownCache()
  petUp = false
  for k in pairs(playerAuras) do playerAuras[k] = nil end
  now = now + 10000
  local classes = 0
  for _, class in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }) do
    UnitClass = function() return class, class, 1 end
    local rotations = 0
    for _, r in ipairs(ns.ListRotations(class)) do
      if r.builtin then
        rotations = rotations + 1
        local c = ns.Compile(ns.Parse(ns.GetRotationText(r.name)), "main", env)
        local wantBefore, wantAfter = {}, {}
        for _, e in ipairs(c.priority or {}) do
          local only, pet, buff = #e.live > 0, false, nil
          for _, cond in ipairs(e.live) do
            if cond.kind ~= "missing" and cond.kind ~= "nopet" then only = false end
            if cond.kind == "nopet" then pet = true end
            if cond.kind == "missing" then buff = cond.arg end
          end
          if only and not e.spell:find("Totem$") then
            local key = pet and "your pet" or e.spell
            wantBefore[key] = true
            if pet or ns.BuffDuration(buff) >= 60 then wantAfter[key] = true end
          end
        end
        local function keyed(list)
          local t = {}
          for _, x in ipairs(list) do t[x.kind == "pet" and "your pet" or (x.kind == "weapon" and "weapon") or x.spell] = x end
          return t
        end
        local okB, before = pcall(R.PrePullList, c)
        local okA, after = pcall(R.AfterFightList, c)
        check(okB and okA, r.name .. ": the checks run")
        before, after = keyed(okB and before or {}), keyed(okA and after or {})
        local missed = {}
        for k in pairs(wantBefore) do if not before[k] then missed[#missed + 1] = "before:" .. k end end
        for k in pairs(wantAfter) do if not after[k] then missed[#missed + 1] = "after:" .. k end end
        for k, x in pairs(after) do if x.kind == "buff" and not wantAfter[k] then missed[#missed + 1] = "extra after:" .. k end end
        check(#missed == 0, r.name .. ": every buff it keeps up is checked (" .. table.concat(missed, ", ") .. ")")
        check(next(after) ~= nil, r.name .. ": something to check after a fight")
      end
    end
    check(rotations >= 3, class .. ": all its rotations (" .. rotations .. ")")
    classes = classes + 1
  end
  check(classes == 9, "all nine classes")

  known["Instant Poison"], known["Rockbiter Weapon"] = nil, nil
  UnitExists, UnitClass, GetInventoryItemID, C_Item = realExists, realClass, realInv, realItem
  GetWeaponEnchantInfo = nil
  ns.compiled.main = realMain
  ns.ClearKnownCache()
  R.ResetChatThrottle()
  for k in pairs(usable) do usable[k] = nil end
  inCombat = false
  ns.Rebuild("test")
  hasTarget = false
end

-- supplies: ammo, Soul Shards, reagents and totems (Tactara only says so)
do
  local R = ns.Reminders
  local realClass, realInv, realItem, realRotSpells = UnitClass, GetInventoryItemID, C_Item, ns.RotationSpells
  local inv, counts, bags = {}, {}, {}
  -- class/subclass: 3001 bow, 3002 gun, 3003 thrown, 2512 Rough Arrow, 2516 Light Shot, 2519 Heavy Shot
  local INFO = { [3001] = { 2, 2 }, [3002] = { 2, 3 }, [3003] = { 2, 16 }, [2512] = { 6, 2 }, [2516] = { 6, 3 }, [2519] = { 6, 3 } }
  GetInventoryItemID = function(_, slot) return inv[slot] end
  C_Item = {
    GetItemInfoInstant = function(id)
      local i = INFO[id]
      if i then return id, "x", "y", "INVTYPE_RANGED", 1, i[1], i[2] end
      return id, "x", "y", "", 1, 15, 0
    end,
    GetItemCount = function(id) return counts[id] or 0 end,
  }
  C_Container = {
    GetContainerNumSlots = function(bag) return bags[bag] and 16 or 0 end,
    GetContainerItemInfo = function(bag, slot) return bags[bag] and bags[bag][slot] end,
  }
  local rotUses = {}
  ns.RotationSpells = function() return rotUses, {} end
  local function texts() R.MarkSupplies(); local t = {} for _, x in ipairs(R.Supplies()) do t[#t + 1] = x.text end return table.concat(t, ",") end
  local function said() local s = table.concat(chat, " | "); chat = {}; return s end

  -- Hunter: arrows for a bow, bullets for a gun
  UnitClass = function() return "Hunter", "HUNTER", 3 end
  check(TactaraCharDB.supplies == "both", "supply reminders start on")
  inv[18], inv[0], counts[2512] = 3001, 2512, 1000
  check(R.AmmoKind() == 2 and texts() == "", "a quiver full of arrows: nothing")
  counts[2512] = 150
  check(texts() == "150 arrows left", "low on arrows: " .. texts())
  counts[2512] = 1
  check(texts() == "1 arrow left", "one arrow")
  counts[2512] = 0
  check(texts() == "no arrows left", "out of arrows")
  -- your own limit
  counts[2512] = 250
  check(texts() == "", "250 arrows: fine at the normal 200")
  SlashCmdList.TACTARA("supplies ammo 300")
  check(TactaraCharDB.ammoLow == 300 and texts() == "250 arrows left", "/tac supplies ammo 300: 250 is low now")
  SlashCmdList.TACTARA("supplies ammo 0")
  counts[2512] = 5
  check(texts() == "", "limit 0: 5 arrows isn't a warning")
  counts[2512] = 0
  check(texts() == "no arrows left", "limit 0: out still is")
  SlashCmdList.TACTARA("supplies ammo 5000")
  check(TactaraCharDB.ammoLow == 2000, "the limit has a top")
  TactaraCharDB.ammoLow = 200
  inv[0] = nil
  bags[0] = { { itemID = 2512, stackCount = 120 }, { itemID = 2516, stackCount = 400 }, nil, { itemID = 99, stackCount = 5 } }
  check(R.AmmoCount(2) == 120 and texts() == "120 arrows left", "no ammo slot: arrows in your bags (bullets don't count): " .. texts())
  inv[18] = 3002
  check(R.AmmoKind() == 3 and texts() == "", "a gun: 400 bullets is plenty")
  bags[0][2] = { itemID = 2519, stackCount = 30 }
  check(texts() == "30 bullets left", "low on bullets")
  inv[18] = 3003
  check(R.AmmoKind() == false and texts() == "", "thrown weapons need no ammo")
  inv[18] = nil
  check(texts() == "", "no ranged weapon: nothing")
  inv[18] = 3001
  C_Item.GetItemInfoInstant = function() error("secret value") end
  check(R.AmmoKind() == nil and texts() == "", "hidden: no guess")
  C_Item.GetItemInfoInstant = function(id) local i = INFO[id]; if i then return id, "x", "y", "", 1, i[1], i[2] end return id end
  bags = {}
  check(texts() == "", "bags can't be read: no guess")
  bags[0] = {}
  check(texts() == "no arrows left", "empty bags: out")

  -- under the helper popup, with the before-the-pull line
  inCombat, hasTarget = false, true
  check(R.PrePullText() and R.PrePullText():find("Supplies:|r no arrows left$"), "popup line: " .. tostring(R.PrePullText()))
  TactaraCharDB.supplies = "off"
  check(R.PrePullText() == nil or not R.PrePullText():find("Supplies"), "off: no supply line")
  TactaraCharDB.supplies = "both"
  inCombat = true
  check(R.PrePullText() == nil, "in a fight: nothing under the popup")
  inCombat = false

  -- chat: when it runs low or out, not every arrow, and not again for ten minutes
  R.ResetSupplyChat()
  bags[0] = { { itemID = 2512, stackCount = 150 } }
  chat = {}
  check(R.CheckSupplyChat() and said():find("Low on arrows: 150 left%."), "chat when it runs low")
  bags[0][1].stackCount = 149
  check(not R.CheckSupplyChat() and said() == "", "one arrow less: quiet")
  bags[0][1].stackCount = 0
  check(R.CheckSupplyChat() and said():find("You're out of arrows"), "chat when it runs out")
  bags[0][1].stackCount = 1000
  check(not R.CheckSupplyChat(), "restocked: quiet")
  bags[0][1].stackCount = 150
  check(not R.CheckSupplyChat() and said() == "", "low again within ten minutes: quiet")
  bags[0][1].stackCount = 1000; R.CheckSupplyChat()
  now = now + 601
  bags[0][1].stackCount = 150
  check(R.CheckSupplyChat() and said():find("Low on arrows"), "low again later: chat")
  TactaraCharDB.supplies = "helper"
  R.ResetSupplyChat()
  check(not R.CheckSupplyChat() and said() == "", "helper only: no chat")
  TactaraCharDB.supplies = "both"

  -- the bag events wait for login, then look once things settle
  R.ResetSupplyChat()
  R.HandleEvent("BAG_UPDATE_DELAYED"); runTimers()
  check(said() == "", "before login: quiet")
  R.HandleEvent("PLAYER_LOGIN"); runTimers()
  check(said():find("Low on arrows"), "after login: one look")
  bags[0][1].stackCount = 0
  R.HandleEvent("BAG_UPDATE_DELAYED"); R.HandleEvent("BAG_UPDATE_DELAYED"); runTimers()
  local s = said()
  check(select(2, s:gsub("out of arrows", "")) == 1, "bag updates come together into one look: " .. s)

  -- at a vendor that sells what you're low on
  local stock = { 2512, 159, 2516 }
  GetMerchantNumItems = function() return #stock end
  GetMerchantItemID = function(i) return stock[i] end
  local SOLD = { [2512] = "Rough Arrow", [159] = "Refreshing Spring Water", [2516] = "Light Shot", [6265] = "Soul Shard" }
  C_MerchantFrame = { GetItemInfo = function(i) return { name = SOLD[stock[i]] } end }
  R.HandleEvent("MERCHANT_SHOW")
  check(said():find("This vendor sells what you're low on: Rough Arrow%."), "vendor sells arrows (not bullets, not water)")
  stock = { 159 }
  R.HandleEvent("MERCHANT_SHOW")
  check(said() == "", "vendor with nothing you need: quiet")
  TactaraCharDB.supplies = "helper"
  stock = { 2512 }
  R.HandleEvent("MERCHANT_SHOW")
  check(said() == "", "helper only: quiet at vendors too")
  TactaraCharDB.supplies = "both"
  inv[18] = nil

  -- Warlock: Soul Shards once you have Drain Soul
  UnitClass = function() return "Warlock", "WARLOCK", 9 end
  counts[6265] = 1
  check(texts() == "", "no Drain Soul yet: nothing")
  known["Drain Soul"] = true; ns.ClearKnownCache()
  check(texts() == "1 Soul Shard left", "one shard: " .. texts())
  counts[6265] = 0
  check(texts() == "no Soul Shards", "no shards")
  counts[6265] = 4
  check(texts() == "", "four shards: fine")
  SlashCmdList.TACTARA("supplies shards 5")
  check(TactaraCharDB.shardLow == 5 and texts() == "4 Soul Shards left", "/tac supplies shards 5: four is low now")
  SlashCmdList.TACTARA("supplies shards 0")
  counts[6265] = 1
  check(texts() == "", "limit 0: one shard isn't a warning")
  counts[6265] = 0
  check(texts() == "no Soul Shards", "limit 0: none still is")
  TactaraCharDB.shardLow = 2
  counts[6265] = 4
  stock = { 6265 }
  counts[6265] = 0
  R.HandleEvent("MERCHANT_SHOW")
  check(said():find("Soul Shard"), "a vendor with the item you're out of")
  counts[6265] = 4
  known["Drain Soul"] = nil

  -- reagents: only for spells your rotation casts (an Ankh always)
  UnitClass = function() return "Rogue", "ROGUE", 4 end
  known["Vanish"], known["Blind"] = true, true; ns.ClearKnownCache()
  check(texts() == "", "rotation doesn't cast Vanish: nothing")
  rotUses = { "Vanish" }
  check(texts() == "no Flash Powder (Vanish)", "Vanish in the rotation, no Flash Powder: " .. texts())
  counts[5140] = 3
  check(texts() == "", "Flash Powder in your bags")
  rotUses = { "Vanish", "Blind" }
  check(texts() == "no Blinding Powder (Blind)", "Blind too")
  counts[5530] = 1
  known["Vanish"], known["Blind"] = nil, nil
  rotUses = {}

  UnitClass = function() return "Shaman", "SHAMAN", 7 end
  known["Reincarnation"], known["Searing Totem"] = true, true; ns.ClearKnownCache()
  check(texts() == "no Ankh (Reincarnation),no Fire Totem", "shaman: Ankh and the Fire Totem: " .. texts())
  counts[17030], counts[5176] = 2, 1
  check(texts() == "", "both in your bags")
  C_Item.GetItemCount = function() error("secret value") end
  check(texts() == "", "counts hidden: no guess")
  C_Item.GetItemCount = function(id) return counts[id] or 0 end
  known["Reincarnation"], known["Searing Totem"] = nil, nil

  -- ranks: Rebirth's seed for the highest rank you have
  UnitClass = function() return "Druid", "DRUID", 11 end
  known["Rebirth"] = true; ns.ClearKnownCache()
  rotUses = { "Rebirth" }
  local ranks = { [20484] = true, [20739] = true }
  IsPlayerSpell = function(id) return ranks[id] or false end
  counts[17034] = 5
  check(texts() == "no Stranglethorn Seed (Rebirth)", "rank 2 needs a Stranglethorn Seed: " .. texts())
  counts[17035] = 1
  check(texts() == "", "and has one")
  counts[17035] = nil
  IsPlayerSpell = nil
  check(texts() == "", "ranks hidden: any seed counts")
  known["Rebirth"] = nil
  rotUses = {}

  -- /tac supplies
  UnitClass = function() return "Hunter", "HUNTER", 3 end
  inv[18] = 3001
  SlashCmdList.TACTARA("supplies")
  check(said():find("Supplies: no arrows left%."), "/tac supplies lists them")
  SlashCmdList.TACTARA("supplies off")
  check(TactaraCharDB.supplies == "off" and said():find("Supply reminders off"), "/tac supplies off")
  SlashCmdList.TACTARA("supplies helper")
  check(TactaraCharDB.supplies == "helper", "/tac supplies helper")
  SlashCmdList.TACTARA("supplies on")
  check(TactaraCharDB.supplies == "both", "/tac supplies on")
  inv[18] = nil
  SlashCmdList.TACTARA("supplies")
  check(said():find("nothing is running low"), "/tac supplies: all stocked up")

  UnitClass, GetInventoryItemID, C_Item, ns.RotationSpells = realClass, realInv, realItem, realRotSpells
  C_Container, GetMerchantNumItems, GetMerchantItemID, C_MerchantFrame = nil, nil, nil, nil
  ns.ClearKnownCache()
  R.MarkSupplies()
  R.ResetSupplyChat()
  hasTarget = false
end

-- a game in another language: rotations and builds are written in English,
-- Tactara uses the spell IDs to find each name in the game's language
do
  local L, T = ns.Locale, ns.Talents
  local realGetName, realSB, realCT, realTraits, realClass, realCreature = C_Spell.GetSpellName, C_SpellBook, C_ClassTalents, C_Traits, UnitClass, C_CreatureInfo
  local EN = {}
  for _, tbl in pairs({ ns.SPELL_IDS.WARRIOR, ns.TALENT_IDS.WARRIOR }) do
    for name, id in pairs(tbl) do EN[id] = EN[id] or name end
  end
  C_Spell.GetSpellName = function(id) local n = EN[id]; return n and ("DE " .. n) or nil end
  -- the spellbook only knows the German names
  C_SpellBook = setmetatable({
    FindSpellBookSlotForSpell = function(name, ...)
      if type(name) == "string" and name:find("^DE ") then return realSB.FindSpellBookSlotForSpell(name:sub(4), ...) end
      return nil
    end,
  }, { __index = realSB })
  C_CreatureInfo = { GetCreatureTypeInfo = function(id) return { name = ({ [3] = "Dämon", [6] = "Untoter" })[id] } end }
  L.force = true
  ns.ClearKnownCache()

  check(L.Spell("Heroic Strike") == "DE Heroic Strike" and L.Spell("Not A Spell") == "Not A Spell", "English name -> the game's name, unknown ones unchanged")
  check(L.English("DE Rend") == "Rend", "and back")
  check(L.Command("/cast [@focus,exists] Pummel; Shield Bash") == "/cast [@focus,exists] DE Pummel; DE Shield Bash", "conditions kept: " .. L.Command("/cast [@focus,exists] Pummel; Shield Bash"))
  check(L.Command("/cast !Battle Stance") == "/cast !DE Battle Stance" and L.Command("/startattack") == "/startattack", "! kept, other commands untouched")
  check(L.Creature("Undead") == "Untoter", "creature types in the game's language")

  local rot = ns.Parse("name: t\nclass: WARRIOR\n[priority]\n/cast Battle Shout @missing Battle Shout\n/cast Execute @creature Undead, Demon\n[loop]\n/cast Heroic Strike\n")
  local p1, p2 = rot.sections.priority[1], rot.sections.priority[2]
  check(p1.spells[1] == "DE Battle Shout" and p1.conds[1].arg == "DE Battle Shout" and p2.conds[1].arg == "Untoter, Dämon",
    "rotation lines read in the game's language")
  check(ns.IsKnown("DE Heroic Strike") and not ns.IsKnown("Heroic Strike"), "the spellbook answers to the German name")
  local comp = ns.Compile(ns.Parse(ns.GetRotationText("Warrior - Arms")), "main", ns.MakeEnv())
  local text = {}
  for _, st in ipairs(comp.steps) do text[#text + 1] = st.text end
  text = table.concat(text, "\n")
  check(#comp.steps > 0 and text:find("/cast DE Heroic Strike", 1, true) and not text:find("/cast Heroic Strike", 1, true),
    "Arms compiles to German macros: " .. text:sub(1, 80))

  -- talent builds by spell ID, trees named by their place
  local FIX = dofile(root .. "/../tests/talent_fixtures/warrior.lua")
  local byId, order = {}, {}
  for _, n in ipairs(FIX) do byId[n.id] = n; order[#order + 1] = n.id end
  UnitClass = function() return "Krieger", "WARRIOR", 1 end
  C_ClassTalents = { GetActiveConfigID = function() return 1 end, CanChangeTalents = function() return true, true end }
  C_Traits = {
    GetConfigInfo = function() return { treeIDs = { 1 } } end,
    GetTreeNodes = function() return order end,
    GetNodeInfo = function(_, id)
      local n = byId[id]
      local edges = {}
      for _, t in ipairs(n.to) do edges[#edges + 1] = { targetNode = t } end
      return { ID = id, posX = n.x, posY = n.y, maxRanks = n.max, ranksPurchased = 0, entryIDs = { id }, visibleEdges = edges, subTreeID = 0 }
    end,
    GetEntryInfo = function(_, id) return { definitionID = id, maxRanks = byId[id].max } end,
    GetDefinitionInfo = function(id) return { spellID = byId[id].spell, overrideName = "DE " .. byId[id].name } end,
    GetTreeCurrencyInfo = function() return { { maxQuantity = 0 } } end,
  }
  local tree = T.ReadTree()
  local names = {}
  for i, tr in ipairs(tree.trees) do names[i] = tr.name end
  check(table.concat(names, "/") == "Arms/Fury/Protection", "German talents: trees named by their place: " .. table.concat(names, "/"))
  check(T.FindNode(tree, "Mortal Strike") and T.FindNode(tree, "Mortal Strike").name == "DE Mortal Strike", "a build's English talent finds the German one")
  local all = true
  for _, b in ipairs(T.BuildsForClass("WARRIOR")) do
    if T.IsBuiltin(b.name) and b.source then
      local sim = T.Simulate(b.picks, tree)
      if not (sim.ok and sim.total == 51) then all = false; print("  " .. b.name .. ": " .. tostring(sim.firstError and sim.firstError.err)) end
    end
  end
  check(all, "every Warrior build works on the German trees")
  local talents = ns.ReadTalents("WARRIOR")
  local tn = {}
  for i, t in ipairs(talents.trees) do tn[i] = t.name end
  check(table.concat(tn, "/") == "Arms/Fury/Protection", "rotation pick sees the trees by their place too: " .. table.concat(tn, "/"))

  L.force = nil
  C_Spell.GetSpellName, C_SpellBook, C_ClassTalents, C_Traits, UnitClass, C_CreatureInfo = realGetName, realSB, realCT, realTraits, realClass, realCreature
  ns.ClearKnownCache()
  check(L.Spell("Heroic Strike") == "Heroic Strike" and L.Command("/cast Rend") == "/cast Rend", "English game: nothing changes")
end

-- settings as text: export, import, keys only when asked
do
  local S = ns.Share
  local shown
  StaticPopupDialogs = {}
  StaticPopup_Show = function(which, text) shown = { which = which, text = text } end
  local saved = {}
  for _, k in ipairs(ns.Profiles.KEYS) do saved[k] = TactaraCharDB[k] end
  TactaraCharDB.binds = { main = "F", aoe = "SHIFT-F" }
  TactaraCharDB.helperPos = { point = "CENTER", x = 12.5, y = -40 }
  TactaraCharDB.helperScale, TactaraCharDB.showHelper, TactaraCharDB.prePull = 1.25, true, "helper"
  local text = S.Export()
  check(text:find("^Tactara settings 1") and text:find("\nend$") and text:find("helperPos.x=n:12.5", 1, true)
    and text:find("binds.main=s:F", 1, true) and text:find("prePull=s:helper", 1, true), "export as plain lines: " .. text:sub(1, 60))
  local parsed, n = S.Parse(text)
  check(parsed and n > 5 and parsed.helperPos.y == -40 and parsed.helperScale == 1.25 and parsed.showHelper == true and parsed.binds.aoe == "SHIFT-F",
    "the text reads back the same")
  check(S.Parse("hello") == nil and S.Parse(text:gsub("\nend$", "")) == nil, "not Tactara text, or cut off: refused")
  local evil = "Tactara settings 1\nactive=s:Warrior - Fury\nloadstring=s:os.exit()\nhelperScale=n:2\nend"
  local p2 = S.Parse(evil)
  check(p2 and p2.helperScale == 2 and p2.active == nil and p2.loadstring == nil, "only Tactara's own settings are taken (not rotation or anything else)")

  -- import onto another setup: asked first, keys only with "With keys"
  TactaraCharDB.binds = { main = "Q" }
  TactaraCharDB.helperScale, TactaraCharDB.prePull = 1, "both"
  S.Confirm(parsed)
  local d = StaticPopupDialogs.TACTARA_IMPORT
  check(shown and shown.which == "TACTARA_IMPORT" and shown.text:find("F, SHIFT%-F") and d.button1 == "Import" and d.button3 == "With keys", "asked first, with the keys named")
  check(TactaraCharDB.helperScale == 1, "nothing changes before you answer")
  d.OnAccept()
  check(TactaraCharDB.helperScale == 1.25 and TactaraCharDB.prePull == "helper" and TactaraCharDB.binds.main == "Q", "Import: settings, but your keys stay")
  S.Confirm(parsed)
  StaticPopupDialogs.TACTARA_IMPORT.OnAlt()
  check(TactaraCharDB.binds.main == "F" and TactaraCharDB.binds.aoe == "SHIFT-F", "With keys: keys too")
  TactaraCharDB.showHelper = true
  S.Apply(S.Parse("Tactara settings 1\nshowHelper=n:5\nend"), false)
  check(TactaraCharDB.showHelper == true, "a setting of the wrong kind is left out")
  -- the paste window: wrong text keeps the window open
  S.ShowImport()
  local f = _G.TactaraCopyFrame
  check(f and f.onAccept and f.onAccept("nope") == false, "wrong text: the window stays open")
  check(f.onAccept(text) == true and shown.which == "TACTARA_IMPORT", "right text: asked to import")
  SlashCmdList.TACTARA("export")
  check(_G.TactaraCopyFrame.text:find("^Tactara settings 1"), "/tac export shows the text")
  for _, k in ipairs(ns.Profiles.KEYS) do TactaraCharDB[k] = saved[k] end
  StaticPopupDialogs, StaticPopup_Show = nil, nil
  local okP, probe = pcall(ns.ProbeLocale)
  check(okP and probe:find("IDs checked"), "/tac probe locale runs: " .. tostring(probe):sub(1, 60))
end

-- every spell the built-in rotations use has an ID (for games in other languages)
do
  local L = ns.Locale
  -- corrections from a live /tac probe locale (tests/make_spell_ids.py)
  check(ns.SPELL_IDS.DRUID["Feral Charge"] == 1238122, "Feral Charge is the talent's own charge (Cat and Bear)")
  check(not ns.SPELL_IDS.ROGUE["Improved Sinister Strike"] and not ns.SPELL_IDS.WARRIOR["Raging Blows"]
    and not ns.SPELL_IDS.PALADIN["Blessing of Salvation"] and not ns.SPELL_IDS.MAGE["Polymorph: Pig"], "old names and IDs dropped")
  check(ns.TALENT_IDS.ROGUE["Efficient Strikes"] == 13732 and ns.TALENT_IDS.WARRIOR["Improved Whirlwind"] == 1310315, "the talents keep their IDs")
  local GAPS = {}   -- spells with no ID found yet (none now)
  local NAMES = { ["if"] = true, ["unless"] = true, ["ifmissing"] = true, ["missing"] = true, ["nodebuff"] = true }
  local missing = {}
  for _, class in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }) do
    for _, r in ipairs(ns.ListRotations(class)) do
      local rot = ns.Parse(ns.GetRotationText(r.name))
      local function want(n)
        if n and n ~= "" and not GAPS[n] and not L.IdFor(n, class) then missing[#missing + 1] = class .. ": " .. n end
      end
      want(rot.meta.detect)
      for t in (rot.meta.prefer or ""):gmatch("[^,]+") do want(ns.trim(t)) end
      local function line(l)
        for _, sp in ipairs(l.spells or {}) do want(sp) end
        for _, c in ipairs(l.conds or {}) do if NAMES[c.kind] then want(c.arg) end end
      end
      for _, list in pairs(rot.sections) do
        for _, item in ipairs(list) do
          if item.lines then for _, l in ipairs(item.lines) do line(l) end else line(item) end
        end
      end
    end
  end
  check(#missing == 0, "rotation spells without an ID (add them to tests/spell_ids/icy_veins.json, run tests/make_spell_ids.py): "
    .. table.concat(missing, ", "))
end

print(fails == 0 and "\nHELPER TEST PASSED" or ("\n" .. fails .. " FAILURE(S)"))
os.exit(fails == 0 and 0 or 1)
