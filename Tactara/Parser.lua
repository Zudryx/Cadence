-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: rotation text parser + compiler.
-- Pure Lua (no WoW API calls) so it can be tested outside the game.
--
-- Rotation text format (see README.md for the full reference):
--
--   name: Warrior - Arms
--   class: WARRIOR
--   detect: Mortal Strike        (auto-pick this rotation once this spell is known)
--   default: yes                 (auto-pick this one when nothing is detected)
--   prefer: Primal Bite, ...     (when two rotations share a tree, the one whose
--                                 talents you took more of wins)
--
--   [keypress]                   lines added to EVERY press (stance, /startattack, ...)
--   [opener]                     steps played once at the start of each fight
--   [loop]                       weighted steps, repeated for the rest of the fight
--   [aoe]                        steps for the AoE button (falls back to [loop])
--   [aoe-opener]                 opener for the AoE button (falls back to [opener])
--   [priority]                   for the rotation helper: best ready spell, top first
--   [interrupt]                  interrupts, tried in order (helper + Tactara Interrupt key)
--   [defensive]                  defensive cooldowns the helper suggests in combat
--
--   3x /cast Mortal Strike       "3x" = this step appears 3 times per loop cycle
--        /cast Overpower         indented line = fallthrough inside the same step
--   /cast Battle Shout @ifmissing Battle Shout
--   /cast Rend @unless Berserker Stance
--   /cast Hamstring @if Improved Hamstring
--
-- Live checks (used by the helper's [priority] list; the key ignores them):
--   @missing Battle Shout        only when that buff isn't on you
--   @nodebuff Rend               only when your debuff isn't on the target
--   @enemies 3                   only with at least 3 enemies nearby (nameplates)
--   @health 35                   only when your health is below 35%
--   @creature Undead, Demon      only when the target is one of these creature types
--   @nopet                       only when your pet is missing or dead
--   @combo 4                     only with at least 4 combo points

local ADDON, ns = ...
ns = ns or {}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
ns.trim = trim

local SECTION_ALIASES = {
  ["keypress"] = "keypress", ["key press"] = "keypress", ["every press"] = "keypress",
  ["opener"] = "opener",
  ["loop"] = "loop", ["rotation"] = "loop", ["main"] = "loop",
  ["aoe"] = "aoe",
  ["aoe-opener"] = "aoeopener", ["aoe opener"] = "aoeopener", ["aoeopener"] = "aoeopener",
  ["priority"] = "priority", ["helper"] = "priority",
  ["interrupt"] = "interrupt", ["interrupts"] = "interrupt",
  ["defensive"] = "defensive", ["defensives"] = "defensive",
}

local KNOWN_ANN = { ["if"] = true, ["unless"] = true, ["ifmissing"] = true,
  ["missing"] = true, ["nodebuff"] = true, ["enemies"] = true, ["health"] = true,
  ["creature"] = true, ["nopet"] = true, ["combo"] = true }
local LIVE_ANN = { ["missing"] = true, ["nodebuff"] = true, ["enemies"] = true, ["health"] = true,
  ["creature"] = true, ["nopet"] = true, ["combo"] = true }
local NO_ARG_ANN = { ["nopet"] = true }   -- written without a value: "@nopet"
ns.LIVE_ANN = LIVE_ANN

local MAX_WEIGHT = 20
ns.MACRO_SOFT_LIMIT = 255

-- Split "/cast X @unless Y" into "/cast X" and "@unless Y".
-- Only the keywords above count, so macro targets like [@focus] are left alone.
local function SplitAnnotations(line)
  local from = 1
  while true do
    local s, e, word = line:find("%s@(%a+)", from)
    if not s then return trim(line), nil end
    local after = line:sub(e + 1, e + 1)
    if (after == "" or after:match("%s")) and KNOWN_ANN[word:lower()] then
      return trim(line:sub(1, s - 1)), line:sub(s + 1)
    end
    from = e
  end
end

local function ParseAnnotationTail(tail, warnings, lineNo)
  local conds = {}
  if not tail then return conds end
  for chunk in tail:gmatch("@([^@]+)") do
    local word, arg = chunk:match("^(%a+)%s+(.-)%s*$")
    if not word then word, arg = chunk:match("^(%a+)%s*$"), "" end
    local kind = word and word:lower()
    if kind and KNOWN_ANN[kind] and ((arg and arg ~= "") or NO_ARG_ANN[kind]) then
      conds[#conds + 1] = { kind = kind, arg = arg or "" }
    else
      warnings[#warnings + 1] = ("line %d: couldn't read '@%s'"):format(lineNo, trim(chunk))
    end
  end
  return conds
end

-- Returns the list of spell names a /cast line refers to, or nil if the
-- line isn't a /cast line (e.g. /startattack), which is always kept.
local function SpellsInCommand(cmd)
  local verb, args = cmd:match("^/(%a+)%s*(.*)$")
  if not verb then return nil end
  verb = verb:lower()
  if verb ~= "cast" then return nil end
  local spells = {}
  for clause in (args .. ";"):gmatch("([^;]*);") do
    local name = clause:gsub("%b[]", "")
    name = trim(name)
    name = name:gsub("^!", "")
    name = trim(name)
    if name ~= "" then spells[#spells + 1] = name end
  end
  return spells
end
ns.SpellsInCommand = SpellsInCommand

function ns.Parse(text)
  if type(text) ~= "string" then return nil, "no rotation text" end
  local rot = {
    meta = {},
    sections = { keypress = {}, opener = {}, loop = {}, aoe = {}, aoeopener = {}, priority = {},
      interrupt = {}, defensive = {} },
    warnings = {},
    usesBuffChecks = false,
  }
  local warnings = rot.warnings
  local section, lastStep
  local lineNo = 0

  text = text:gsub("\r\n", "\n")
  text = text:gsub("\r", "\n")

  for raw in (text .. "\n"):gmatch("(.-)\n") do
    lineNo = lineNo + 1
    local indented = raw:match("^[ \t]+%S") ~= nil
    local s = trim(raw)

    if s == "" or s:sub(1, 1) == "#" or s:sub(1, 2) == "--" then
      -- blank line or comment
    elseif s:match("^%[.*%]$") then
      local key = s:match("^%[%s*(.-)%s*%]$"):lower()
      section = SECTION_ALIASES[key]
      lastStep = nil
      if not section then
        warnings[#warnings + 1] = ("line %d: unknown section [%s] (use keypress, opener, loop, aoe, aoe-opener, priority, interrupt, defensive)"):format(lineNo, key)
      end
    elseif not s:find("^/") and not s:find("^%d+%s*[xX]%s") and s:find("^%a[%w_%- ]*:") then
      local k, v = s:match("^(%a[%w_%- ]*):%s*(.-)$")
      rot.meta[trim(k):lower()] = v
    else
      if not section then
        warnings[#warnings + 1] = ("line %d: command outside a [section], ignored"):format(lineNo)
      else
        local weight
        local w, rest = s:match("^(%d+)%s*[xX]%s+(.+)$")
        if w then
          weight = tonumber(w)
          s = rest
        end
        if not s:find("^/") then
          warnings[#warnings + 1] = ("line %d: expected a /command, got '%s'"):format(lineNo, s)
        else
          local cmd, tail = SplitAnnotations(s)
          local line = {
            cmd = cmd,
            conds = ParseAnnotationTail(tail, warnings, lineNo),
            spells = SpellsInCommand(cmd),
            lineNo = lineNo,
          }
          for _, c in ipairs(line.conds) do
            if c.kind == "ifmissing" then rot.usesBuffChecks = true end
          end
          if section == "keypress" or section == "priority" or section == "interrupt" or section == "defensive" then
            if weight then
              warnings[#warnings + 1] = ("line %d: weights don't apply in [%s]"):format(lineNo, section)
            end
            table.insert(rot.sections[section], line)
          elseif indented and lastStep then
            if weight then
              warnings[#warnings + 1] = ("line %d: weight on an indented (fallthrough) line is ignored"):format(lineNo)
            end
            table.insert(lastStep.lines, line)
          else
            if weight and (section == "opener" or section == "aoeopener") and weight ~= 1 then
              warnings[#warnings + 1] = ("line %d: weights are ignored in the opener"):format(lineNo)
            end
            weight = weight or 1
            if weight < 1 then weight = 1 end
            if weight > MAX_WEIGHT then
              warnings[#warnings + 1] = ("line %d: weight capped at %d"):format(lineNo, MAX_WEIGHT)
              weight = MAX_WEIGHT
            end
            lastStep = { weight = weight, lines = { line }, lineNo = lineNo }
            table.insert(rot.sections[section], lastStep)
          end
        end
      end
    end
  end

  local name = rot.meta.name and trim(rot.meta.name) or ""
  rot.name = name ~= "" and name or nil
  if rot.meta.class then rot.meta.class = trim(rot.meta.class):upper() end
  if rot.meta.detect then rot.meta.detect = trim(rot.meta.detect) end
  if rot.meta.tree then rot.meta.tree = trim(rot.meta.tree) end
  if rot.meta.weapon then rot.meta.weapon = trim(rot.meta.weapon):lower() end
  local d = rot.meta.default and rot.meta.default:lower() or ""
  rot.isDefault = (d == "yes" or d == "true" or d == "1")

  if #rot.sections.loop == 0 and #rot.sections.opener == 0 and #rot.sections.priority == 0 then
    warnings[#warnings + 1] = "no [opener], [loop] or [priority] lines yet"
  end
  return rot
end

-- Is this line usable right now? (spell known, @if/@unless/@ifmissing)
local function LineAllowed(line, env, ignoreBuffs)
  if line.spells and #line.spells > 0 then
    local any = false
    for _, s in ipairs(line.spells) do
      if env.isKnown(s) then any = true break end
    end
    if not any then return false end
  end
  for _, c in ipairs(line.conds) do
    if c.kind == "if" and not env.isKnown(c.arg) then return false end
    if c.kind == "unless" and env.isKnown(c.arg) then return false end
    if c.kind == "ifmissing" and not ignoreBuffs and env.hasBuff then
      if env.hasBuff(c.arg) == true then return false end
    end
    -- @missing / @nodebuff / @enemies are checked live by the helper, not here
  end
  return true
end
ns.LineAllowed = LineAllowed

-- Smooth weighted round-robin: spreads heavy steps evenly through the cycle.
-- Weights {A=3, B=1, C=1} -> A B A C A (instead of A A A B C).
local function WeightedOrder(steps)
  local out, current, total = {}, {}, 0
  for i, st in ipairs(steps) do
    current[i] = 0
    total = total + st.weight
  end
  for _ = 1, total do
    local best
    for i, st in ipairs(steps) do
      current[i] = current[i] + st.weight
      if not best or current[i] > current[best] then best = i end
    end
    current[best] = current[best] - total
    out[#out + 1] = steps[best]
  end
  return out
end
ns.WeightedOrder = WeightedOrder

-- Compile a parsed rotation into the macro text for each button step.
-- which: "main" or "aoe"
-- env: { isKnown = function(spellName) -> bool, hasBuff = function(buffName) -> true/false/nil }
function ns.Compile(rot, which, env)
  local out = {
    steps = {}, loopStart = 1, openerCount = 0, loopCount = 0,
    spells = {}, warnings = {}, aoeFallback = false,
  }
  if not rot then return out end

  local seen = {}
  local function noteSpells(line)
    if not line.spells then return end
    for _, s in ipairs(line.spells) do
      if not seen[s] and env.isKnown(s) then
        seen[s] = true
        out.spells[#out.spells + 1] = s
      end
    end
  end

  -- [keypress] lines go on every step. A line like "/cast [nocombat,harm] Charge"
  -- is the pull: it's what fires first when you start a fight, so the display
  -- and /tac steps show it as the opening move.
  local prefix = {}
  for _, line in ipairs(rot.sections.keypress) do
    if LineAllowed(line, env) then
      prefix[#prefix + 1] = line.cmd
      noteSpells(line)
      if not out.pull and line.spells then
        local conds = line.cmd:match("^/%a+%s*(%b[])")
        conds = conds and conds:lower()
        if conds and conds:find("[%[,]%s*nocombat%s*[%],]") and conds:find("[%[,]%s*harm%s*[%],]") then
          for _, s in ipairs(line.spells) do
            if env.isKnown(s) then out.pull = s break end
          end
        end
      end
    end
  end

  local function buildSteps(list)
    local result = {}
    for _, step in ipairs(list) do
      local cmds, labels, spells, icon = {}, {}, {}, nil
      for _, line in ipairs(step.lines) do
        if LineAllowed(line, env, true) then noteSpells(line) end
        if LineAllowed(line, env) then
          cmds[#cmds + 1] = line.cmd
          local first
          if line.spells then
            for _, s in ipairs(line.spells) do
              if env.isKnown(s) then first = s break end
            end
          end
          if first then
            if not icon then icon = first end
            spells[#spells + 1] = first
          end
          labels[#labels + 1] = first or line.cmd
        end
      end
      if #cmds > 0 then
        result[#result + 1] = {
          weight = step.weight, cmds = cmds, icon = icon, spells = spells,
          label = table.concat(labels, " > "), lineNo = step.lineNo,
        }
      end
    end
    return result
  end

  local loopSrc, openerSrc = rot.sections.loop, rot.sections.opener
  if which == "aoe" then
    if #rot.sections.aoe > 0 then loopSrc = rot.sections.aoe else out.aoeFallback = true end
    if #rot.sections.aoeopener > 0 then openerSrc = rot.sections.aoeopener end
  end

  local opener = buildSteps(openerSrc)
  local loop = WeightedOrder(buildSteps(loopSrc))
  local prefixText = table.concat(prefix, "\n")

  local function finish(step, kind)
    local body = table.concat(step.cmds, "\n")
    local text = prefixText ~= "" and (prefixText .. "\n" .. body) or body
    if #text > ns.MACRO_SOFT_LIMIT then
      out.warnings[#out.warnings + 1] = ("step from line %d is %d characters (over %d) and may be cut off by the game")
        :format(step.lineNo or 0, #text, ns.MACRO_SOFT_LIMIT)
    end
    out.steps[#out.steps + 1] = {
      text = text, icon = step.icon, spells = step.spells, label = step.label, kind = kind,
    }
  end
  for _, st in ipairs(opener) do finish(st, "opener") end
  for _, st in ipairs(loop) do finish(st, "loop") end

  out.openerCount = #opener
  out.loopCount = #loop

  -- single-line lists for the helper: first known spell of each line + its live checks
  local function compileList(lines)
    local list, cmds = {}, {}
    for _, line in ipairs(lines) do
      if LineAllowed(line, env) then
        noteSpells(line)
        local spell
        for _, sp in ipairs(line.spells or {}) do
          if env.isKnown(sp) then spell = sp break end
        end
        if spell then
          local live = {}
          for _, c in ipairs(line.conds) do
            if LIVE_ANN[c.kind] then live[#live + 1] = c end
          end
          list[#list + 1] = { spell = spell, live = live, lineNo = line.lineNo }
          cmds[#cmds + 1] = line.cmd
        end
      end
    end
    return list, cmds
  end
  out.priority = compileList(rot.sections.priority)
  out.defensives = compileList(rot.sections.defensive)
  local interruptCmds
  out.interrupts, interruptCmds = compileList(rot.sections.interrupt)
  -- Tactara Interrupt key: every known interrupt as a fallback chain
  out.interruptMacro = table.concat(interruptCmds, "\n")
  out.prefix = prefix
  out.loopStart = (#loop > 0) and (#opener + 1) or 1
  return out
end
