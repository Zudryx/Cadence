-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: talent builds (the engine behind the talent planner).
--
-- A build is the order you spend your talent points in, level 10 to 60,
-- written as text like a rotation:
--
--   name: Warrior - Arms
--   class: WARRIOR
--   tree: Arms
--   source: where it comes from
--   notes: one line about it
--   order:
--   Improved Rend 3
--   Deflection 2
--
-- Each line after "order:" is a talent and how many points go into it at
-- that spot (1 if there's no number).
--
-- The trees are read from the game, so the planner stays right when
-- Blizzard changes talents. The rules are Classic's: each row needs 5 more
-- points in that tree, a talent with an arrow into it needs the talent
-- before it maxed, and you get 51 points (the first at level 10).
--
-- Learning happens only when you click Learn, or when you level up with
-- "learn automatically" turned on; never in combat, and only the next
-- points of the build you picked.

local ADDON, ns = ...
local T = {}
ns.Talents = T

T.FIRST_LEVEL = 10
T.MAX_POINTS = 51
T.PER_ROW = 5

local builtin, builtinByName = {}, {}

local function Trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

---------------------------------------------------------------------------
-- Build text
---------------------------------------------------------------------------

local META = { name = true, class = true, tree = true, source = true, notes = true }

function T.Parse(text)
  local b = { order = {}, picks = {} }
  local inOrder = false
  for raw in (text or ""):gmatch("[^\r\n]+") do
    local line = Trim((raw:gsub("#.*$", "")))
    if line ~= "" then
      local key, val = line:match("^(%a+):%s*(.-)$")
      key = key and key:lower()
      if key == "order" then
        inOrder = true
      elseif key and META[key] then
        b[key] = val ~= "" and val or nil
      elseif inOrder then
        local name, n = line:match("^(.-)%s+[xX]?(%d+)$")
        if not name or name == "" then name, n = line, 1 end
        n = math.max(1, math.min(tonumber(n) or 1, 5))
        b.order[#b.order + 1] = { name = name, count = n }
        for _ = 1, n do b.picks[#b.picks + 1] = name end
      end
    end
  end
  if b.class then b.class = b.class:upper() end
  return b
end

function T.Export(b)
  local L = { "name: " .. (b.name or "My build") }
  if b.class then L[#L + 1] = "class: " .. b.class end
  if b.tree then L[#L + 1] = "tree: " .. b.tree end
  if b.source then L[#L + 1] = "source: " .. b.source end
  if b.notes then L[#L + 1] = "notes: " .. b.notes end
  L[#L + 1] = "order:"
  local i = 1
  while i <= #b.picks do
    local name, n = b.picks[i], 1
    while b.picks[i + n] == name and n < 5 do n = n + 1 end
    L[#L + 1] = n > 1 and (name .. " " .. n) or name
    i = i + n
  end
  return table.concat(L, "\n")
end

---------------------------------------------------------------------------
-- Built-in and your own builds
---------------------------------------------------------------------------

function ns.RegisterTalentBuild(text)
  local b = T.Parse(text)
  b.builtin = true
  local class = b.class or "?"
  builtin[class] = builtin[class] or {}
  local list, replaced = builtin[class], false
  for i, old in ipairs(list) do
    if old.name == b.name then list[i] = b; replaced = true end
  end
  if not replaced then table.insert(list, b) end
  builtinByName[b.name] = b
  return b
end

local function Custom()
  TactaraDB.talentBuilds = TactaraDB.talentBuilds or {}
  return TactaraDB.talentBuilds
end

function T.GetBuild(name)
  if not name then return nil end
  if builtinByName[name] then return builtinByName[name] end
  local text = Custom()[name]
  if text then
    local b = T.Parse(text)
    b.name = name
    return b
  end
end

-- Built-in builds for your class first, then yours (sorted by name).
function T.BuildsForClass(class)
  local list = {}
  for _, b in ipairs(builtin[class or ""] or {}) do list[#list + 1] = b end
  local mine = {}
  for name in pairs(Custom()) do
    local b = T.GetBuild(name)
    if b and (not b.class or b.class == class) then mine[#mine + 1] = b end
  end
  table.sort(mine, function(a, b) return a.name:lower() < b.name:lower() end)
  for _, b in ipairs(mine) do list[#list + 1] = b end
  return list
end

function T.IsBuiltin(name) return builtinByName[name] ~= nil end

function T.UniqueName(base)
  base = base or "My build"
  if not builtinByName[base] and not Custom()[base] then return base end
  for i = 2, 99 do
    local n = base .. " " .. i
    if not builtinByName[n] and not Custom()[n] then return n end
  end
  return base .. " " .. tostring(time and time() or math.random(1000))
end

function T.SaveCustom(b)
  if not b.name or builtinByName[b.name] then b.name = T.UniqueName(b.name) end
  b.builtin = nil
  Custom()[b.name] = T.Export(b)
  return b
end

function T.DeleteCustom(name)
  Custom()[name] = nil
  if TactaraCharDB.talentBuild == name then TactaraCharDB.talentBuild = nil end
end

function T.RenameCustom(old, new)
  new = Trim(new or "")
  if new == "" or new == old or builtinByName[new] or Custom()[new] then return false end
  local b = T.GetBuild(old)
  if not b then return false end
  Custom()[old] = nil
  b.name = new
  Custom()[new] = T.Export(b)
  if TactaraCharDB.talentBuild == old then TactaraCharDB.talentBuild = new end
  return true
end

local function PicksKey(b) return table.concat(b.picks, "|") end

-- The build you're following. For one of Tactara's builds this is the
-- version you picked: if an update changes Tactara's build, you keep
-- following yours (marked outdated, with the new one in .newer) until you
-- choose to switch or keep it.
local snapshotText, snapshotBuild
function T.ActiveBuild()
  local name = TactaraCharDB.talentBuild
  local b = T.GetBuild(name)
  if not b then return nil end
  if b.class and b.class ~= ns.GetClassToken() then return nil end
  if not b.builtin then return b end
  local saved = TactaraCharDB.talentBuildText
  if not saved then
    TactaraCharDB.talentBuildText = T.Export(b)   -- picked before versions were kept
    return b
  end
  if saved ~= snapshotText then snapshotText, snapshotBuild = saved, T.Parse(saved) end
  if PicksKey(snapshotBuild) == PicksKey(b) then return b end
  local old = {}
  for k, v in pairs(snapshotBuild) do old[k] = v end
  old.name, old.class, old.builtin, old.outdated, old.newer = b.name, old.class or b.class, true, true, b
  return old
end

function T.SetActive(name)
  TactaraCharDB.talentBuild = name
  local b = T.GetBuild(name)
  TactaraCharDB.talentBuildText = (b and b.builtin) and T.Export(b) or nil
  T.Refresh()
end

---------------------------------------------------------------------------
-- Dual spec: each spec keeps its own talent build and rotation choice
---------------------------------------------------------------------------

function T.SpecGroup()
  local g
  if C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup then
    local ok, v = pcall(C_SpecializationInfo.GetActiveSpecGroup)
    if ok then g = v end
  end
  if not g and GetActiveTalentGroup then
    local ok, v = pcall(GetActiveTalentGroup)
    if ok then g = v end
  end
  g = tonumber(g)
  return (g and g >= 1) and math.floor(g) or 1
end

-- When you switch specs, put this spec's choices away and bring the other
-- spec's back. The first time, it just notes which spec you're in, so the
-- build you already follow stays with that spec.
function T.SyncSpec(quiet)
  local g = T.SpecGroup()
  local cur = TactaraCharDB.specGroup
  if cur == g then return false end
  TactaraCharDB.specs = TactaraCharDB.specs or {}
  TactaraCharDB.specGroup = g
  if not cur then return false end
  TactaraCharDB.specs[cur] = { build = TactaraCharDB.talentBuild, text = TactaraCharDB.talentBuildText, rotation = TactaraCharDB.active }
  local s = TactaraCharDB.specs[g] or {}
  TactaraCharDB.talentBuild, TactaraCharDB.talentBuildText = s.build, s.text
  TactaraCharDB.active = s.rotation or "auto"
  if not quiet then
    local b = T.ActiveBuild()
    ns.Print(("Switched to your %s spec. Talents: %s. Rotation: %s."):format(
      g == 2 and "secondary" or "primary",
      b and ("following " .. b.name) or "no build picked for this spec yet (|cffffd100/tac talents|r)",
      TactaraCharDB.active == "auto" and "picked from your talents" or TactaraCharDB.active))
  end
  if ns.RequestRebuild then ns.RequestRebuild("spec switch", 0.2) end
  T.Refresh()
  return true
end

---------------------------------------------------------------------------
-- When Tactara updates a build you're following: ask, never switch for you
---------------------------------------------------------------------------

-- What changed, in a line or two, and whether the new version fits your talents.
function T.UpdateSummary(old, new, tree)
  local lines = {}
  for i = 1, math.max(#old.picks, #new.picks) do
    if old.picks[i] ~= new.picks[i] then
      lines[#lines + 1] = ("From level %d it takes %s (yours: %s)."):format(T.FIRST_LEVEL + i - 1,
        new.picks[i] or "nothing", old.picks[i] or "nothing")
      break
    end
  end
  if tree then
    local off = T.Progress(new, tree).offPlan
    if #off > 0 then
      lines[#lines + 1] = "Your points in " .. table.concat(off, ", ") .. " aren't in the new version, so following it fully would need a respec."
    else
      lines[#lines + 1] = "It fits the talents you have now, so you can switch without a respec."
    end
  end
  return table.concat(lines, "\n")
end

function T.AcceptUpdate()
  local b = T.GetBuild(TactaraCharDB.talentBuild)
  if not (b and b.builtin) then return end
  TactaraCharDB.talentBuildText = T.Export(b)
  ns.Print(("Now following the updated %s."):format(b.name))
  T.Refresh()
end

-- Keep the version you picked as a build of your own (it never changes).
function T.KeepMine()
  local old = T.ActiveBuild()
  if not (old and old.outdated) then return end
  local copy = { name = T.UniqueName(old.name .. " (kept)"), class = old.class, tree = old.tree, notes = old.notes,
    source = "Tactara's " .. old.name .. " as it was when you picked it", picks = {} }
  for i, p in ipairs(old.picks) do copy.picks[i] = p end
  T.SaveCustom(copy)
  TactaraCharDB.talentBuild, TactaraCharDB.talentBuildText = copy.name, nil
  ns.Print(("Kept your version as \"%s\" (with your builds in /tac talents). You won't be asked about this update again."):format(copy.name))
  T.Refresh()
  return copy.name
end

local promptWaiting = false
---------------------------------------------------------------------------
-- First time on a character: one question about the talent planner
---------------------------------------------------------------------------

local welcomeWaiting = false

local function Popup(key, text, b1, b2, b3, onAccept, onCancel, onAlt)
  if not (StaticPopupDialogs and StaticPopup_Show) then return false end
  StaticPopupDialogs[key] = {
    text = "%s", button1 = b1, button2 = b2, button3 = b3,
    OnAccept = onAccept, OnCancel = onCancel, OnAlt = onAlt,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
  StaticPopup_Show(key, text)
  return true
end

local function OpenPlanner()
  TactaraCharDB.welcomeDone = true
  ns.TalentPlanner.Show()
end

-- Asked once per character (new character, first install, reset, or a
-- character that hasn't picked a build yet), unless turned off for all.
function T.Welcome()
  if TactaraCharDB.welcomeDone or TactaraDB.welcomeOff or T.ActiveBuild() then return end
  if InCombatLockdown() then welcomeWaiting = true return end
  welcomeWaiting = false
  local level = UnitLevel and UnitLevel("player") or 1
  local intro = "|cffffd100Tactara|r can plan your talents from level 10 to 60, from its own builds or your own, and learn them with a click as you level."
  if level < T.FIRST_LEVEL then
    Popup("TACTARA_WELCOME", intro .. "\n\nYour first talent point comes at level 10. Look at the talent planner now, or be reminded at level 10?",
      "Open planner", "At level 10", "No thanks",
      OpenPlanner,
      function() TactaraCharDB.welcomeDone, TactaraCharDB.welcomeAt10 = true, true end,
      function() TactaraCharDB.welcomeDone = true end)
  else
    Popup("TACTARA_WELCOME", intro .. "\n\nPick a talent build to follow, or plan your own?",
      "Open planner", "Later", "No thanks",
      OpenPlanner,
      nil,
      function() TactaraCharDB.welcomeDone = true end)
  end
end

local function WelcomeAt10(level)
  if not TactaraCharDB.welcomeAt10 or (tonumber(level) or 0) < T.FIRST_LEVEL then return end
  TactaraCharDB.welcomeAt10 = nil
  if T.ActiveBuild() then return end
  Popup("TACTARA_WELCOME_10", "Level 10: your first talent point!\n\nOpen the |cffffd100Tactara|r talent planner to pick a build or plan your own?",
    "Open planner", "Not now", nil, function() ns.TalentPlanner.Show() end)
end

function T.PromptUpdate()
  local old = T.ActiveBuild()
  if not (old and old.outdated) then return end
  if InCombatLockdown() then promptWaiting = true return end
  promptWaiting = false
  local tree = T.ReadTree()
  local text = ("Tactara's |cffffd100%s|r talent build has been updated.\n\n%s\n\nSwitch to the new version, or keep following the one you picked? Until you choose, Tactara keeps following yours.")
    :format(old.name, T.UpdateSummary(old, old.newer, tree))
  ns.Print(("Tactara's %s talent build has been updated. You're still following your version: choose in the popup or in /tac talents."):format(old.name))
  if StaticPopupDialogs and StaticPopup_Show then
    StaticPopupDialogs.TACTARA_BUILD_UPDATE = StaticPopupDialogs.TACTARA_BUILD_UPDATE or {
      text = "%s", button1 = "Switch", button2 = "Later", button3 = "Keep mine",
      OnAccept = function() T.AcceptUpdate() end,
      OnAlt = function() T.KeepMine() end,
      timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopup_Show("TACTARA_BUILD_UPDATE", text)
  end
end

---------------------------------------------------------------------------
-- Reading your talent trees from the game
---------------------------------------------------------------------------

local function SpellName(id)
  if not id then return nil end
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  return GetSpellInfo and (GetSpellInfo(id))
end

-- Positions that are within GRID_TOL of each other are the same row or
-- column: the game puts a few talents slightly off the grid (a Warlock's
-- Improved Life Tap sits at 2120 next to the rest of the row at 2130).
local GRID_TOL = 150

-- Groups the values of field `key` among `nodes`.
-- Returns { [value] = group number (1 = smallest) }, number of groups, groups ({min, max}).
local function Cluster(nodes, key)
  local seen, sorted = {}, {}
  for _, n in ipairs(nodes) do
    local v = n[key]
    if not seen[v] then seen[v] = true; sorted[#sorted + 1] = v end
  end
  table.sort(sorted)
  local index, groups, last = {}, {}, nil
  for _, v in ipairs(sorted) do
    if not last or v - last > GRID_TOL then groups[#groups + 1] = { min = v, max = v } end
    groups[#groups].max = v
    index[v] = #groups
    last = v
  end
  return index, #groups, groups
end

-- Talents far below the rest of the trees aren't part of them (the Priest
-- data has a stray second Holy Specialization way off the bottom). Keep
-- rows from the top down until there's a gap much wider than the usual
-- space between rows.
local function DropStrays(nodes)
  local index, count, groups = Cluster(nodes, "y")
  if count < 3 then return nodes end
  local gaps = {}
  for i = 2, count do gaps[#gaps + 1] = groups[i].min - groups[i - 1].max end
  local sortedGaps = {}
  for i, g in ipairs(gaps) do sortedGaps[i] = g end
  table.sort(sortedGaps)
  local usual = sortedGaps[math.ceil(#sortedGaps / 2)]
  local lastRow = count
  for i, g in ipairs(gaps) do
    if g > math.max(1000, usual * 3) then lastRow = i break end
  end
  if lastRow == count then return nodes end
  local kept = {}
  for _, n in ipairs(nodes) do
    if index[n.y] <= lastRow then kept[#kept + 1] = n end
  end
  return kept
end

-- Returns a tree table or nil, reason:
-- { configID, treeID, list, nodes = {[id]=node}, byName, trees = { {name, nodes, points} },
--   earned, spent, unspent }
-- node = { id, entryID, name, spellID, x, y, row, col, tree, max, rank, to = {ids}, from = {ids} }
function T.ReadTree()
  if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits and C_Traits.GetConfigInfo) then
    return nil, "this game doesn't show talents to addons"
  end
  local tree
  local ok, err = pcall(function()
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then error("no talents yet", 0) end
    local cfg = C_Traits.GetConfigInfo(configID) or {}
    local treeIDs = cfg.treeIDs or {}
    if not treeIDs[1] then error("no talent tree", 0) end
    tree = { configID = configID, treeID = treeIDs[1], list = {}, nodes = {}, byName = {}, trees = {} }
    local raw = {}
    for _, tid in ipairs(treeIDs) do
      for _, nodeID in ipairs(C_Traits.GetTreeNodes(tid) or {}) do
        local n = C_Traits.GetNodeInfo(configID, nodeID)
        if n and n.ID and n.ID ~= 0 and n.isVisible ~= false then
          local entryID = (n.activeEntry and n.activeEntry.entryID) or (n.entryIDs and n.entryIDs[1])
          local entry = entryID and C_Traits.GetEntryInfo(configID, entryID) or {}
          local def = entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID) or {}
          local spellID = def.spellID or def.overriddenSpellID
          local name = (def.overrideName and def.overrideName ~= "" and def.overrideName) or SpellName(spellID)
          if name then
            local node = {
              id = nodeID, entryID = entryID, name = name, spellID = spellID,
              x = n.posX or 0, y = n.posY or 0, sub = n.subTreeID or 0,
              max = n.maxRanks or entry.maxRanks or 1,
              rank = n.ranksPurchased or n.currentRank or 0,
              to = {}, from = {},
            }
            for _, e in ipairs(n.visibleEdges or {}) do node.to[#node.to + 1] = e.targetNode end
            raw[#raw + 1] = node
          end
        end
      end
    end
    for _, node in ipairs(DropStrays(raw)) do
      tree.nodes[node.id] = node
      tree.list[#tree.list + 1] = node
      local key = node.name:lower()
      if not tree.byName[key] then tree.byName[key] = node end
    end
    if #tree.list == 0 then error("no talents found", 0) end
    for _, node in ipairs(tree.list) do
      for _, to in ipairs(node.to) do
        if tree.nodes[to] then table.insert(tree.nodes[to].from, node.id) end
      end
    end

    -- Which tree each talent is in: the game's sub-trees if it has them,
    -- otherwise three columns split at the two widest gaps.
    local subIndex, subCount = {}, 0
    for _, node in ipairs(tree.list) do
      if node.sub ~= 0 and not subIndex[node.sub] then subCount = subCount + 1; subIndex[node.sub] = true end
    end
    local count
    if subCount >= 2 then
      local idx = Cluster(tree.list, "sub")
      for _, node in ipairs(tree.list) do node.tree = idx[node.sub] end
      count = subCount
    else
      local seenX, xs = {}, {}
      for _, node in ipairs(tree.list) do
        if not seenX[node.x] then seenX[node.x] = true; xs[#xs + 1] = node.x end
      end
      table.sort(xs)
      local gaps = {}
      for i = 2, #xs do gaps[#gaps + 1] = { at = xs[i], size = xs[i] - xs[i - 1] } end
      table.sort(gaps, function(a, b) return a.size > b.size end)
      local cuts = {}
      for i = 1, math.min(2, #gaps) do cuts[#cuts + 1] = gaps[i].at end
      for _, node in ipairs(tree.list) do
        local t = 1
        for _, c in ipairs(cuts) do if node.x >= c then t = t + 1 end end
        node.tree = t
      end
      count = #cuts + 1
    end
    for t = 1, count do tree.trees[t] = { index = t, nodes = {}, points = 0, names = {} } end
    for _, node in ipairs(tree.list) do
      local tr = tree.trees[node.tree]
      tr.nodes[#tr.nodes + 1] = node
      tr.points = tr.points + node.rank
      tr.names[node.name] = true
    end
    for t, tr in ipairs(tree.trees) do
      local rowIndex = Cluster(tr.nodes, "y")
      local colIndex = Cluster(tr.nodes, "x")
      for _, node in ipairs(tr.nodes) do node.row, node.col = rowIndex[node.y], colIndex[node.x] end
      tr.name = ns.NameTalentTree(ns.GetClassToken(), tr.names) or ("Tree " .. t)
      tr.rows, tr.cols = 0, 0
      for _, node in ipairs(tr.nodes) do
        tr.rows = math.max(tr.rows, node.row)
        tr.cols = math.max(tr.cols, node.col)
      end
    end

    -- points: from the game if it says, otherwise from your level
    local spent = 0
    for _, node in ipairs(tree.list) do spent = spent + node.rank end
    local earned
    if C_Traits.GetTreeCurrencyInfo then
      local c = (C_Traits.GetTreeCurrencyInfo(configID, tree.treeID, false) or {})[1]
      if c and c.maxQuantity then earned = c.maxQuantity end
    end
    if not earned then
      local level = UnitLevel and UnitLevel("player") or 1
      earned = math.max(0, math.min(T.MAX_POINTS, level - T.FIRST_LEVEL + 1))
    end
    tree.spent, tree.earned = spent, earned
    tree.unspent = math.max(0, earned - spent)
  end)
  if not ok then return nil, tostring(err):gsub("^.-:%d+: ", "") end
  return tree
end

---------------------------------------------------------------------------
-- Checking a build against the rules
---------------------------------------------------------------------------

-- Plays the picks in order. Each step: { index, name, level, node, rank, err }.
-- A step with an error isn't counted, so later steps are checked as if it
-- were left out.
function T.Simulate(picks, tree)
  local ranks, perTree, total = {}, {}, 0
  local steps, firstError = {}, nil
  for i, name in ipairs(picks) do
    local step = { index = i, name = name, level = T.FIRST_LEVEL + i - 1 }
    local node = tree.byName[name:lower()]
    if not node then
      step.err = "there's no talent called " .. name
    else
      step.node = node
      local have = ranks[node.id] or 0
      local inTree = perTree[node.tree] or 0
      local needTree = (node.row - 1) * T.PER_ROW
      if total >= T.MAX_POINTS then
        step.err = "that's more than " .. T.MAX_POINTS .. " points"
      elseif have >= node.max then
        step.err = ("%s is already %d/%d"):format(node.name, node.max, node.max)
      elseif inTree < needTree then
        step.err = ("needs %d points in %s first (%d so far)"):format(needTree, tree.trees[node.tree].name, inTree)
      else
        for _, fromID in ipairs(node.from) do
          local f = tree.nodes[fromID]
          if f and (ranks[f.id] or 0) < f.max then
            step.err = ("needs %s %d/%d first"):format(f.name, f.max, f.max)
            break
          end
        end
      end
      if not step.err then
        ranks[node.id] = have + 1
        perTree[node.tree] = inTree + 1
        total = total + 1
        step.rank = have + 1
      end
    end
    if step.err and not firstError then firstError = step end
    steps[i] = step
  end
  return { steps = steps, ranks = ranks, perTree = perTree, total = total, firstError = firstError, ok = firstError == nil }
end

-- Where you are in a build compared with your talents now.
-- pending: the build's steps you haven't learned yet, in order.
-- offPlan: talents you have more points in than the build ever takes.
function T.Progress(build, tree)
  local sim = T.Simulate(build.picks, tree)
  local planned, pending = {}, {}
  for _, step in ipairs(sim.steps) do
    if step.node and not step.err then
      planned[step.node.id] = (planned[step.node.id] or 0) + 1
      if planned[step.node.id] > step.node.rank then pending[#pending + 1] = step end
    elseif step.err then
      pending[#pending + 1] = step
    end
  end
  local offPlan = {}
  for _, node in ipairs(tree.list) do
    if node.rank > (sim.ranks[node.id] or 0) then offPlan[#offPlan + 1] = node.name end
  end
  return { sim = sim, pending = pending, offPlan = offPlan, next = pending[1] }
end

-- A build made from the talents you have now, in an order the game would
-- take (top rows first), so you can keep your points and plan the rest.
function T.FromCurrent(tree)
  local nodes = {}
  for _, node in ipairs(tree.list) do if node.rank > 0 then nodes[#nodes + 1] = node end end
  table.sort(nodes, function(a, b)
    if a.row ~= b.row then return a.row < b.row end
    if a.tree ~= b.tree then return a.tree < b.tree end
    return a.col < b.col
  end)
  local picks = {}
  for _, node in ipairs(nodes) do
    for _ = 1, node.rank do picks[#picks + 1] = node.name end
  end
  return picks
end

-- Points per tree for a build, like "34/15/2".
function T.Split(build, tree)
  local sim = T.Simulate(build.picks, tree)
  local parts = {}
  for t = 1, #tree.trees do parts[#parts + 1] = tostring(sim.perTree[t] or 0) end
  return table.concat(parts, "/"), sim
end

---------------------------------------------------------------------------
-- Learning talents
---------------------------------------------------------------------------

T.blocked = false

local function GameBuild()
  local _, build = GetBuildInfo()
  return tostring(build)
end

local function Say(msg) ns.Print(msg) end

-- Learn up to `count` points of your build ("all" = every unspent point).
-- Returns the steps learned, or nil and the reason.
function T.Learn(count)
  if T.blocked or (TactaraDB.talentLearnBlocked and TactaraDB.talentLearnBlocked == GameBuild()) then
    T.blocked = true
    return nil, "WoW doesn't let addons learn talents, so click the glowing talent in your talent window instead."
  end
  if InCombatLockdown() then return nil, "you can't change talents in combat" end
  local build = T.ActiveBuild()
  if not build then return nil, "pick a build first (/tac talents)" end
  local tree, why = T.ReadTree()
  if not tree then return nil, why end
  if tree.unspent <= 0 then return nil, "you have no talent points to spend" end
  if C_ClassTalents.CanChangeTalents then
    local okC, canChange, canAdd, reason = pcall(C_ClassTalents.CanChangeTalents)
    if okC and (canAdd == false or (canChange == false and canAdd == nil)) then
      return nil, reason or "the game won't let you add talents right now"
    end
  end
  if C_Traits.ConfigHasStagedChanges and C_Traits.ConfigHasStagedChanges(tree.configID) then
    return nil, "your talent window has changes that aren't applied yet: apply or undo them first"
  end
  if not (C_Traits.PurchaseRank and ((C_ClassTalents and C_ClassTalents.CommitConfig) or C_Traits.CommitConfig)) then
    return nil, "this game doesn't let addons learn talents"
  end
  local todo = count == "all" and tree.unspent or math.min(tonumber(count) or 1, tree.unspent)
  local prog = T.Progress(build, tree)
  local learned, stop = {}, nil
  T.learning = true
  for _, step in ipairs(prog.pending) do
    if #learned >= todo then break end
    if step.err then stop = "the build has a problem at level " .. step.level .. ": " .. step.err break end
    local node = step.node
    if C_Traits.CanPurchaseRank then
      local okP, can = pcall(C_Traits.CanPurchaseRank, tree.configID, node.id, node.entryID)
      if okP and can == false then
        stop = ("the game won't take %s yet (do your talents match the build?)"):format(node.name)
        break
      end
    end
    local okB, bought = pcall(C_Traits.PurchaseRank, tree.configID, node.id)
    if T.blocked then break end
    if not okB or bought == false then
      stop = ("couldn't learn %s"):format(node.name)
      break
    end
    learned[#learned + 1] = step
  end
  local commit = (C_ClassTalents and C_ClassTalents.CommitConfig) or C_Traits.CommitConfig
  local committed = false
  if #learned > 0 and not T.blocked then
    local okC, result = pcall(commit, tree.configID)
    committed = okC and result ~= false
  end
  T.learning = false
  if not committed then
    if C_Traits.RollbackConfig then pcall(C_Traits.RollbackConfig, tree.configID) end
    if T.blocked then
      return nil, "WoW doesn't let addons learn talents, so click the glowing talent in your talent window instead."
    end
    if #learned > 0 then return nil, "the game didn't accept the change" end
    return nil, stop or "nothing to learn"
  end
  -- say what took once the game confirms the change (or after a few seconds)
  local function Report()
    if T.pendingReport ~= Report then return end
    T.pendingReport = nil
    local after = T.ReadTree()
    local names = {}
    for _, s in ipairs(learned) do
      local n = after and after.nodes[s.node.id]
      local took = n and n.rank >= s.rank
      names[#names + 1] = (took and "" or "|cffff5555not |r") .. ("%s %d/%d"):format(s.node.name, s.rank, s.node.max)
    end
    Say("Learned: " .. table.concat(names, ", ") .. (stop and (" |cffaaaaaa(stopped: " .. stop .. ")|r") or ""))
    T.Refresh()
  end
  T.pendingReport = Report
  if C_Timer and C_Timer.After then C_Timer.After(6, Report) else Report() end
  return learned, stop
end

-- If the game blocks the learn calls, remember it (for this game build) and
-- fall back to the glow.
local function OnBlocked(addon)
  if addon ~= ADDON or not T.learning then return end
  T.blocked = true
  TactaraDB.talentLearnBlocked = GameBuild()
  Say("WoW doesn't let addons learn talents. Tactara will glow the next talent in your talent window instead, for you to click.")
end

---------------------------------------------------------------------------
-- Reminders, learning on level up, and the glow in the talent window
---------------------------------------------------------------------------

local glowed

function T.UpdateTalentWindowGlow()
  if glowed then ns.HideButtonGlow(glowed); glowed = nil end
  local f = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
  if not (f and f.IsVisible and f:IsVisible() and f.GetTalentButtonByNodeID) then return end
  if TactaraCharDB.talentGlow == false then return end
  -- looking at your other spec's tab: nothing to glow there
  if f.GetConfigID and C_ClassTalents and C_ClassTalents.GetActiveConfigID then
    local ok, shownID = pcall(f.GetConfigID, f)
    if ok and shownID and shownID ~= C_ClassTalents.GetActiveConfigID() then return end
  end
  local build = T.ActiveBuild()
  if not build then return end
  local tree = T.ReadTree()
  if not tree or tree.unspent <= 0 then return end
  local step = T.Progress(build, tree).next
  if not step or step.err then return end
  local ok, btn = pcall(f.GetTalentButtonByNodeID, f, step.node.id)
  if ok and btn then
    ns.ShowButtonGlow(btn, "next")
    glowed = btn
  end
end

function T.NextText(build, tree)
  local prog = T.Progress(build, tree)
  local step = prog.next
  if not step then return "you've learned the whole build" end
  if step.err then return "the build has a problem at level " .. step.level .. ": " .. step.err end
  return ("%s %d/%d"):format(step.node.name, step.rank, step.node.max)
end

function T.Remind()
  if TactaraCharDB.talentReminders == false then return end
  local build = T.ActiveBuild()
  if not build then return end
  local tree = T.ReadTree()
  if not tree or tree.unspent <= 0 then return end
  Say(("%d talent point%s to spend. Next in %s: %s. Click Learn in |cffffd100/tac talents|r, or the glowing talent in your talent window.")
    :format(tree.unspent, tree.unspent == 1 and "" or "s", build.name, T.NextText(build, tree)))
end

local autoWaiting = false

function T.TryAutoLearn()
  if not TactaraCharDB.talentAutoLearn or T.blocked then T.Remind() return end
  if InCombatLockdown() then autoWaiting = true return end
  autoWaiting = false
  local tree = T.ReadTree()
  if not tree or tree.unspent <= 0 or not T.ActiveBuild() then return end
  local learned, why = T.Learn("all")
  if not learned then Say("Couldn't learn talents automatically: " .. tostring(why)) end
end

local watchers = {}

function T.Refresh()
  T.UpdateTalentWindowGlow()
  for _, fn in ipairs(watchers) do pcall(fn) end
end

function T.OnChange(fn) watchers[#watchers + 1] = fn end

-- A "Tactara planner" button in the bottom bar of the game's talent window,
-- left of Apply Changes. It's Tactara's own button; Blizzard's window is
-- left exactly as it is.
local windowButton

local function PlaceWindowButton(f)
  local b = windowButton
  if not b then return end
  if TactaraCharDB.talentButton == false then b:Hide() return end
  b:ClearAllPoints()
  local ab = f.ApplyButton
  local ok, y = pcall(function()
    if ab and ab:GetBottom() and f:GetBottom() then return ab:GetBottom() - f:GetBottom() end
  end)
  b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, (ok and y) or 8)
  b:Show()
end

local function MakeWindowButton(f)
  local b = CreateFrame("Button", "TactaraTalentWindowButton", f, "UIPanelButtonTemplate")
  b:SetSize(140, 22)
  b:SetText("Tactara planner")
  b:SetFrameLevel((f:GetFrameLevel() or 1) + 20)
  b:SetScript("OnClick", function() ns.TalentPlanner.Toggle() end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Tactara talent planner")
    local build = T.ActiveBuild()
    local tree = build and T.ReadTree()
    if build then
      GameTooltip:AddLine("Following: " .. build.name, 1, 1, 1)
      if tree then GameTooltip:AddLine("Next: " .. T.NextText(build, tree), 0.3, 0.75, 1) end
    else
      GameTooltip:AddLine("Pick a build to follow, or plan your own.", 1, 1, 1, true)
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return b
end

function T.UpdateWindowButton()
  local f = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
  if f and windowButton then PlaceWindowButton(f) end
end

local hooked = false
local function HookTalentWindow()
  local f = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
  if hooked or not (f and f.HookScript) then return end
  hooked = true
  local okB, b = pcall(MakeWindowButton, f)
  if okB then windowButton = b; T.windowButton = b end
  f:HookScript("OnShow", function() PlaceWindowButton(f); T.UpdateTalentWindowGlow() end)
  f:HookScript("OnHide", function() T.UpdateTalentWindowGlow() end)
  if f.IsShown and f:IsShown() then PlaceWindowButton(f) end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "ADDON_LOADED", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED",
  "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
  "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED",
  "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
function T.HandleEvent(event, arg1)
  if event == "ADDON_ACTION_FORBIDDEN" or event == "ADDON_ACTION_BLOCKED" then
    OnBlocked(arg1)
  elseif event == "ADDON_LOADED" then
    if arg1 == "Blizzard_PlayerSpells" then HookTalentWindow() end
  elseif event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED"
      or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" then
    if not T.SyncSpec() then T.Refresh() end
  elseif event == "PLAYER_LOGIN" then
    T.SyncSpec(true)
    HookTalentWindow()
    if C_Timer and C_Timer.After then
      C_Timer.After(8, T.Remind)
      C_Timer.After(10, T.PromptUpdate)
      C_Timer.After(12, T.Welcome)
    end
  elseif event == "PLAYER_LEVEL_UP" then
    WelcomeAt10(arg1)
    -- the new point shows up a moment after the level
    if C_Timer and C_Timer.After then C_Timer.After(1.5, T.TryAutoLearn) else T.TryAutoLearn() end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if autoWaiting then T.TryAutoLearn() end
    if promptWaiting then T.PromptUpdate() end
    if welcomeWaiting then T.Welcome() end
  else
    if event == "TRAIT_CONFIG_UPDATED" and T.pendingReport then T.pendingReport() end
    if event == "TRAIT_CONFIG_UPDATED" and T.SyncSpec() then return end
    if not T.learning then T.Refresh() end
  end
end
ev:SetScript("OnEvent", function(_, event, arg1) T.HandleEvent(event, arg1) end)
