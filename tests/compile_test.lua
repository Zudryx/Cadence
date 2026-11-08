-- Unit tests for Parser.lua + the built-in Warrior rotations.
local root = arg[1]
local ns = {}
local function loadAddonFile(f)
  local fn = assert(loadfile(root .. "/" .. f))
  fn("Tactara", ns)
end
-- minimal RegisterBuiltin (Core.lua's version needs saved vars)
ns.builtin, ns.builtinOrder = {}, {}
loadAddonFile("Parser.lua")
function ns.RegisterBuiltin(text)
  local rot = ns.Parse(text)
  assert(rot and rot.name, "builtin without name")
  table.insert(ns.builtinOrder, rot.name)
  ns.builtin[rot.name] = text
end
loadAddonFile("Rotations/Warrior.lua")

local fails = 0
local function check(cond, msg) if not cond then fails = fails + 1; print("  FAIL: " .. msg) end end

-- Warrior spells by level (Warcraft Tavern WoW Forever milestones)
local BY_LEVEL = {
  {1, "Battle Stance"}, {1, "Battle Shout"}, {1, "Heroic Strike"},
  {4, "Rend"}, {4, "Charge"}, {6, "Thunder Clap"}, {8, "Hamstring"},
  {10, "Defensive Stance"}, {10, "Bloodrage"}, {10, "Taunt"}, {10, "Sunder Armor"},
  {12, "Overpower"}, {12, "Shield Bash"}, {14, "Revenge"}, {14, "Demoralizing Shout"},
  {16, "Shield Block"}, {20, "Victory Rush"}, {20, "Cleave"}, {20, "Slam"}, {20, "Retaliation"},
  {24, "Execute"}, {30, "Berserker Stance"}, {30, "Intercept"}, {36, "Whirlwind"},
}
local TALENTS = {
  arms = { {30, "Sweeping Strikes"}, {40, "Mortal Strike"} },
  fury = { {40, "Bloodthirst"} },
  prot = { {40, "Shield Slam"} },
}
local function knownSet(level, spec)
  local s = {}
  for _, e in ipairs(BY_LEVEL) do if e[1] <= level then s[e[2]] = true end end
  for _, e in ipairs(TALENTS[spec] or {}) do if e[1] <= level then s[e[2]] = true end end
  return s
end
local function env(level, spec, buffs)
  local k = knownSet(level, spec)
  return {
    isKnown = function(n) return k[n] == true end,
    hasBuff = function(n) if buffs then return buffs[n] == true end return nil end,
  }
end

-- 1) built-ins parse without warnings
for _, name in ipairs(ns.builtinOrder) do
  local rot = ns.Parse(ns.builtin[name])
  check(#rot.warnings == 0, name .. " has parse warnings: " .. table.concat(rot.warnings, "; "))
  check(rot.meta.class == "WARRIOR", name .. " class")
end
check(#ns.builtinOrder == 3, "three warrior rotations registered")

-- 2) print compiled sequences per level
local SPEC_OF = { ["Warrior - Arms"] = "arms", ["Warrior - Fury"] = "fury", ["Warrior - Protection"] = "prot" }
for _, name in ipairs(ns.builtinOrder) do
  local rot = ns.Parse(ns.builtin[name])
  print("\n=== " .. name .. " ===")
  for _, lvl in ipairs({3, 4, 12, 20, 30, 40, 60}) do
    local c = ns.Compile(rot, "main", env(lvl, SPEC_OF[name]))
    local labels = {}
    for i, st in ipairs(c.steps) do labels[#labels + 1] = (st.kind == "opener" and "*" or "") .. st.label end
    print(("L%-2d prefix[%s]"):format(lvl, table.concat(c.prefix, " ; ")))
    print(("     %d+%d: %s"):format(c.openerCount, c.loopCount, table.concat(labels, " | ")))
    check(#c.steps > 0, name .. " L" .. lvl .. " has steps")
    for _, st in ipairs(c.steps) do
      check(#st.text <= 255, ("%s L%d step '%s' is %d chars"):format(name, lvl, st.label, #st.text))
    end
    for _, w in ipairs(c.warnings) do print("     warn: " .. w) end
  end
  local a = ns.Compile(rot, "aoe", env(60, SPEC_OF[name]))
  local labels = {}
  for _, st in ipairs(a.steps) do labels[#labels + 1] = (st.kind == "opener" and "*" or "") .. st.label end
  print(("AoE L60 %d+%d: %s"):format(a.openerCount, a.loopCount, table.concat(labels, " | ")))
end

-- 3) specific behaviours
do
  local rot = ns.Parse(ns.builtin["Warrior - Arms"])
  local c3 = ns.Compile(rot, "main", env(3, "arms"))
  -- level 3: keypress has startattack + battle stance; Charge not yet known
  check(table.concat(c3.prefix, "|"):find("Charge") == nil, "Charge filtered at L3")
  check(table.concat(c3.prefix, "|"):find("Battle Stance") ~= nil, "Battle Stance kept at L3")
  -- spells list at L3
  check(table.concat(c3.spells, ","):find("Heroic Strike") ~= nil, "HS in spell list L3")
  -- @ifmissing: buff present -> Battle Shout dropped from opener step 1, Bloodrage remains
  local c20has = ns.Compile(rot, "main", env(20, "arms", { ["Battle Shout"] = true }))
  check(c20has.steps[1].text:find("Battle Shout") == nil, "Battle Shout dropped when buff present")
  check(c20has.steps[1].text:find("Bloodrage") ~= nil, "Bloodrage kept")
  local c20miss = ns.Compile(rot, "main", env(20, "arms", { ["Battle Shout"] = false }))
  check(c20miss.steps[1].text:find("Battle Shout") ~= nil, "Battle Shout kept when buff missing")
  -- spells list shouldn't depend on buff state (avoids 'added' spam)
  check(#c20has.spells == #c20miss.spells, "spell list independent of buffs")
  -- loopStart
  check(c20has.loopStart == c20has.openerCount + 1, "loopStart after opener")
end

do -- Fury stance handling
  local rot = ns.Parse(ns.builtin["Warrior - Fury"])
  local c20 = ns.Compile(rot, "main", env(20, "fury"))
  local p20 = table.concat(c20.prefix, "\n")
  check(p20:find("%[combat,nostance:1%] Battle Stance") ~= nil, "Fury <30 stays in Battle in combat")
  check(p20:find("Berserker") == nil, "no Berserker line before 30")
  local c30 = ns.Compile(rot, "main", env(30, "fury"))
  local p30 = table.concat(c30.prefix, "\n")
  check(p30:find("Berserker") == nil, "Fury 30-35 (no Whirlwind) still fights in Battle Stance")
  local c36 = ns.Compile(rot, "main", env(36, "fury"))
  local p36 = table.concat(c36.prefix, "\n")
  check(p36:find("%[combat,nostance:3%] Berserker Stance") ~= nil, "Fury 36+ swaps to Berserker in combat")
  check(p36:find("%[combat,nostance:1%] Battle Stance") == nil, "Battle-in-combat line removed at 36")
  local all36 = {}
  for _, st in ipairs(c36.steps) do all36[#all36 + 1] = st.text end
  check(table.concat(all36, "\n"):find("Overpower") == nil, "Overpower removed in Berserker phase")
  -- no step should be "Execute" alone (it only works below 20% health)
  for _, lvl in ipairs({24, 30, 36, 40, 60}) do
    for _, st in ipairs(ns.Compile(rot, "main", env(lvl, "fury")).steps) do
      check(st.label ~= "Execute", "Fury L" .. lvl .. " has an Execute-only step")
    end
  end
end

do -- pull spell (Charge) is surfaced for the display and /tac steps
  for name, spec in pairs({ ["Warrior - Arms"] = "arms", ["Warrior - Fury"] = "fury", ["Warrior - Protection"] = "prot" }) do
    local rot = ns.Parse(ns.builtin[name])
    check(ns.Compile(rot, "main", env(3, spec)).pull == nil, name .. " no pull before Charge is learned")
    check(ns.Compile(rot, "main", env(4, spec)).pull == "Charge", name .. " pull = Charge at L4")
    check(ns.Compile(rot, "aoe", env(60, spec)).pull == "Charge", name .. " AoE pull = Charge")
  end
  local r = ns.Parse("name: x\n[keypress]\n/cast [nocombat,noharm] Battle Stance\n/cast [nocombat] Rend\n[loop]\n/cast Rend")
  check(ns.Compile(r, "main", env(60, "arms")).pull == nil, "noharm / no-harm lines are not a pull")
end

do -- priority lists compile with live checks; unknown spells drop out by level
  for name, spec in pairs({ ["Warrior - Arms"] = "arms", ["Warrior - Fury"] = "fury", ["Warrior - Protection"] = "prot" }) do
    local rot = ns.Parse(ns.builtin[name])
    check(rot.meta.tree ~= nil and rot.meta.weapon ~= nil, name .. " has tree + weapon")
    local p3 = ns.Compile(rot, "main", env(3, spec)).priority
    local p60 = ns.Compile(rot, "main", env(60, spec)).priority
    check(#p3 >= 2 and #p60 > #p3, name .. " priority grows with level (" .. #p3 .. " -> " .. #p60 .. ")")
    local labels = {}
    for _, e in ipairs(p60) do
      local live = {}
      for _, c in ipairs(e.live) do live[#live + 1] = "@" .. c.kind .. " " .. c.arg end
      labels[#labels + 1] = e.spell .. (#live > 0 and (" [" .. table.concat(live, ",") .. "]") or "")
    end
    print(name .. " priority L60: " .. table.concat(labels, " > "))
    -- live checks never filter at compile time (button sequences unaffected)
    local c = ns.Compile(rot, "main", env(60, spec))
    check(#c.steps > 0, name .. " still has key steps")
  end
  local r = ns.Parse("name: t\n[priority]\n/cast Rend @nodebuff Rend @enemies 2\n3x /cast X")
  check(#r.sections.priority == 2 and #r.sections.priority[1].conds == 2, "two live checks on one line")
  check(table.concat(r.warnings, " "):find("weights don't apply in %[priority%]"), "weights warned in priority")
end

-- 4) weighted order spreads steps
do
  local order = ns.WeightedOrder({ { weight = 3, id = "A" }, { weight = 1, id = "B" }, { weight = 1, id = "C" } })
  local s = ""
  for _, st in ipairs(order) do s = s .. st.id end
  print("\nweighted A3 B1 C1 -> " .. s)
  check(#s == 5 and s:sub(1, 1) == "A" and not s:find("AAA"), "weighted order interleaves")
end

-- 5) parser edge cases
do
  local rot = ns.Parse([[
name: Test
class: ANY
[keypress]
/cast [@focus,harm] Polymorph
[loop]
2X /cast [mod:shift, @player] Flash Heal; Smite @if Smite
  /cast !Auto Shot
/castsequence A, B
5x Not a command
[bogus]
/cast Ignored
]])
  check(rot.sections.keypress[1].cmd == "/cast [@focus,harm] Polymorph", "[@focus] not treated as annotation")
  local l = rot.sections.loop[1].lines[1]
  check(l.cmd == "/cast [mod:shift, @player] Flash Heal; Smite", "comma-space @player kept: " .. l.cmd)
  check(#l.conds == 1 and l.conds[1].kind == "if" and l.conds[1].arg == "Smite", "@if parsed")
  check(l.spells[1] == "Flash Heal" and l.spells[2] == "Smite", "spells from ; clauses")
  check(rot.sections.loop[1].weight == 2, "2X weight")
  check(rot.sections.loop[1].lines[2].spells[1] == "Auto Shot", "! stripped")
  check(rot.sections.loop[2].lines[1].spells == nil, "/castsequence not filtered as /cast")
  local warnText = table.concat(rot.warnings, "\n")
  check(warnText:find("unknown section") ~= nil, "unknown section warned")
  check(warnText:find("expected a /command") ~= nil, "bad line warned")
end

-- 6) empty/garbage input
do
  local rot = ns.Parse("")
  local c = ns.Compile(rot, "main", env(10))
  check(#c.steps == 0, "empty rotation compiles to no steps")
  check(ns.Compile(nil, "main", env(10)).loopStart == 1, "nil rotation safe")
end

print(fails == 0 and "\nALL TESTS PASSED" or ("\n" .. fails .. " FAILURE(S)"))
os.exit(fails == 0 and 0 or 1)
