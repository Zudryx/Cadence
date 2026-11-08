-- Unit tests for Parser.lua + every built-in rotation.
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
-- load every rotation file listed in Tactara.toc
for line in io.open(root .. "/Tactara.toc"):read("a"):gmatch("[^\r\n]+") do
  if line:find("^Rotations") then loadAddonFile((line:gsub("\\", "/"))) end
end

local fails = 0
local function check(cond, msg) if not cond then fails = fails + 1; print("  FAIL: " .. msg) end end

local D = dofile("tests/class_data.lua")
local SPEC_CLASS = {}
for name, spec in pairs(D.SPEC_OF) do
  SPEC_CLASS[spec] = ns.Parse(ns.builtin[name] or "").meta.class
end
local function knownSet(level, spec, class)
  class = class or SPEC_CLASS[spec] or "WARRIOR"
  local s = {}
  for _, e in ipairs(D.BY_LEVEL[class] or {}) do if e[1] <= level then s[e[2]] = true end end
  for _, e in ipairs(D.TALENTS[spec] or {}) do if e[1] <= level then s[e[2]] = true end end
  return s
end
local function env(level, spec, buffs, class)
  local k = knownSet(level, spec, class)
  return {
    isKnown = function(n) return k[n] == true end,
    hasBuff = function(n) if buffs then return buffs[n] == true end return nil end,
  }
end

-- 1) built-ins parse without warnings
for _, name in ipairs(ns.builtinOrder) do
  local rot = ns.Parse(ns.builtin[name])
  check(#rot.warnings == 0, name .. " has parse warnings: " .. table.concat(rot.warnings, "; "))
  check(D.SPEC_OF[name] ~= nil, name .. " has test data (SPEC_OF)")
end
local warriors = 0
for _, name in ipairs(ns.builtinOrder) do if name:find("^Warrior") then warriors = warriors + 1 end end
check(warriors == 3, "three warrior rotations registered")

-- 2) print compiled sequences per level (Warrior; other classes in section 7)
local SPEC_OF = D.SPEC_OF
for _, name in ipairs(ns.builtinOrder) do if name:find("^Warrior") then
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
end end

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


-- 7) every class: each rotation from level 1 to 60
do
  local LEVELS = { 1, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 28, 30, 36, 40, 44, 50, 60 }
  local verbose = os.getenv("TACTARA_VERBOSE") ~= nil
  local function onlyConditional(step, class)
    local cond = D.CONDITIONAL[class] or {}
    if not step.spells or #step.spells == 0 then return false end
    for _, sp in ipairs(step.spells) do if not cond[sp] then return false end end
    return true
  end
  local perClass = {}
  for _, name in ipairs(ns.builtinOrder) do
    local rot = ns.Parse(ns.builtin[name])
    local class, spec = rot.meta.class, D.SPEC_OF[name]
    perClass[class] = (perClass[class] or 0) + 1
    check(D.BY_LEVEL[class] ~= nil, name .. ": no test spell list for " .. tostring(class))
    -- every spell the rotation names must be a real spell for the class (catches typos)
    local all = {}
    for _, e in ipairs(D.BY_LEVEL[class] or {}) do all[e[2]] = true end
    for s2, list in pairs(D.TALENTS) do
      if SPEC_CLASS[s2] == class then for _, e in ipairs(list) do all[e[2]] = true end end
    end
    for _, list in pairs(rot.sections) do
      for _, item in ipairs(list) do
        for _, line in ipairs(item.lines or { item }) do
          for _, sp in ipairs(line.spells or {}) do
            check(all[sp] or D.ANY_CLASS[sp] or (D.PET[class] or {})[sp], name .. ": unknown spell '" .. sp .. "'")
          end
          for _, c in ipairs(line.conds or {}) do
            if c.kind == "if" or c.kind == "unless" or c.kind == "missing" or c.kind == "ifmissing" or c.kind == "nodebuff" then
              check(all[c.arg] or (D.BUFFS[class] or {})[c.arg] or (D.PET[class] or {})[c.arg],
                name .. ": unknown spell/buff '" .. c.arg .. "' in @" .. c.kind)
            end
          end
        end
      end
    end
    local firstLevel, lowPrio
    for _, lvl in ipairs(LEVELS) do
      local e = env(lvl, spec, nil, class)
      for _, which in ipairs({ "main", "aoe" }) do
        local c = ns.Compile(rot, which, e)
        if #c.steps > 0 and not firstLevel then firstLevel = lvl end
        if lvl >= 6 then check(#c.steps > 0, ("%s %s L%d has no steps"):format(name, which, lvl)) end
        for _, st in ipairs(c.steps) do
          check(#st.text <= 255, ("%s %s L%d step '%s' is %d chars"):format(name, which, lvl, st.label, #st.text))
          check(not onlyConditional(st, class),
            ("%s %s L%d step '%s' only has situational spells"):format(name, which, lvl, st.label))
        end
        if which == "main" then
          if lvl <= 10 and #c.priority > 0 then lowPrio = lowPrio or #c.priority end
          if verbose and (lvl == 10 or lvl == 30 or lvl == 60) then
            local labels = {}
            for _, st in ipairs(c.steps) do labels[#labels + 1] = (st.kind == "opener" and "*" or "") .. st.label end
            print(("%s L%d pull=%s %d+%d: %s"):format(name, lvl, tostring(c.pull), c.openerCount, c.loopCount, table.concat(labels, " | ")))
          end
        end
      end
    end
    local c60 = ns.Compile(rot, "main", env(60, spec, nil, class))
    check(#c60.priority >= 4, name .. " has a helper priority list at 60")
    check(not lowPrio or #c60.priority > lowPrio, name .. " priority grows with level")
    check(#c60.defensives > 0, name .. " suggests defensives at 60")
    check(firstLevel ~= nil and firstLevel <= 6, name .. " has key steps by level 6 (first at " .. tostring(firstLevel) .. ")")
    if verbose then
      local labels = {}
      for _, en in ipairs(c60.priority) do labels[#labels + 1] = en.spell end
      print(name .. " priority L60: " .. table.concat(labels, " > "))
    end
  end
  for class in pairs(D.BY_LEVEL) do
    check((perClass[class] or 0) >= 3, class .. " has at least 3 built-in rotations (" .. tostring(perClass[class]) .. ")")
  end
end

print(fails == 0 and "\nALL TESTS PASSED" or ("\n" .. fails .. " FAILURE(S)"))
os.exit(fails == 0 and 0 or 1)
