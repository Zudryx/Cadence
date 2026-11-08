-- Tactara: reading your build (talents + weapons) and nearby enemies.
--
-- WoW Forever uses the modern talent system (C_ClassTalents / C_Traits), even
-- though the trees look classic. This reader walks the active talent config,
-- adds up your points per tree and names each tree by its signature talents
-- (Mortal Strike = Arms, and so on). Everything is wrapped so that if the game
-- hides or lacks something, Tactara just falls back to weapons and spells.

local ADDON, ns = ...

-- Signature talents used to name talent trees (extend for other classes).
local TREE_SIGNATURES = {
  WARRIOR = {
    Arms = { "Mortal Strike", "Sweeping Strikes", "Deep Wounds", "Tactical Mastery", "Improved Overpower" },
    Fury = { "Bloodthirst", "Death Wish", "Flurry", "Cruelty", "Improved Slam" },
    Protection = { "Shield Slam", "Last Stand", "Concussion Blow", "Shield Specialization", "Defiance" },
  },
}

local function SpellName(id)
  local ok, name = pcall(function()
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
  end)
  if ok and type(name) == "string" then return name end
  return nil
end

---------------------------------------------------------------------------
-- Weapons
---------------------------------------------------------------------------

local function EquipLoc(slot)
  local ok, loc = pcall(function()
    local id = GetInventoryItemID("player", slot)
    if not id then return nil end
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local _, _, _, equipLoc = f(id)
    return equipLoc
  end)
  if ok and type(loc) == "string" then return loc end
  return nil
end

local OFFHAND_WEAPONS = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true }

function ns.ReadWeapon()
  local mh, oh = EquipLoc(16), EquipLoc(17)
  if oh == "INVTYPE_SHIELD" then return "shield" end
  local dual = false
  if IsDualWielding then
    local ok, r = pcall(IsDualWielding)
    dual = ok and r == true
  end
  if dual or (oh and OFFHAND_WEAPONS[oh]) then return "dual" end
  if mh == "INVTYPE_2HWEAPON" then return "two-hand" end
  if mh then return "one-hand" end
  return nil
end

---------------------------------------------------------------------------
-- Talents
---------------------------------------------------------------------------

local function NodeName(configID, node)
  local entryID = (node.activeEntry and node.activeEntry.entryID) or (node.entryIDs and node.entryIDs[1])
  if not entryID then return nil end
  local entry = C_Traits.GetEntryInfo(configID, entryID)
  local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
  if not def then return nil end
  if def.overrideName and def.overrideName ~= "" then return def.overrideName end
  local spellID = def.spellID or def.overriddenSpellID
  return spellID and SpellName(spellID) or nil
end

-- Returns { ok, trees = { {name, points, nodes = {name=rank}} }, top, talents = {name=rank}, info }
function ns.ReadTalents(classToken)
  local result = { ok = false, trees = {}, talents = {}, info = "" }
  local ok, err = pcall(function()
    if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits) then
      result.info = "no talent API"
      return
    end
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then result.info = "no active talent config" return end
    local cfg = C_Traits.GetConfigInfo(configID)
    local treeIDs = cfg and cfg.treeIDs or {}
    local groups, order = {}, {}
    local nodeCount = 0
    for _, treeID in ipairs(treeIDs) do
      for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
        local node = C_Traits.GetNodeInfo(configID, nodeID)
        if node and node.ID and node.ID ~= 0 then
          nodeCount = nodeCount + 1
          local rank = node.ranksPurchased or node.activeRank or node.currentRank or 0
          local name = NodeName(configID, node)
          local key = (node.subTreeID and node.subTreeID ~= 0) and ("sub" .. node.subTreeID) or ("tree" .. treeID)
          if not groups[key] then
            groups[key] = { points = 0, nodes = {}, xs = {} }
            order[#order + 1] = key
          end
          local g = groups[key]
          g.points = g.points + rank
          if name then
            g.nodes[name] = rank
            result.talents[name] = (result.talents[name] or 0) + rank
          end
          g.xs[#g.xs + 1] = { x = node.posX or 0, name = name, rank = rank }
        end
      end
    end

    -- If all tabs share one tree with no sub-trees, split it into 3 columns by x position.
    if #order == 1 then
      local g = groups[order[1]]
      local minX, maxX
      for _, n in ipairs(g.xs) do
        minX = minX and math.min(minX, n.x) or n.x
        maxX = maxX and math.max(maxX, n.x) or n.x
      end
      if minX and maxX and maxX > minX then
        local width = (maxX - minX) / 3
        local split, splitOrder = {}, {}
        for _, n in ipairs(g.xs) do
          local band = math.min(3, math.floor((n.x - minX) / width) + 1)
          local key = "band" .. band
          if not split[key] then split[key] = { points = 0, nodes = {} }; splitOrder[#splitOrder + 1] = key end
          split[key].points = split[key].points + n.rank
          if n.name then split[key].nodes[n.name] = n.rank end
        end
        table.sort(splitOrder)
        groups, order = split, splitOrder
      end
    end

    -- Name the groups by signature talents.
    local sigs = TREE_SIGNATURES[classToken or ""] or {}
    for i, key in ipairs(order) do
      local g = groups[key]
      local bestName, bestHits = nil, 0
      for treeName, list in pairs(sigs) do
        local hits = 0
        for _, t in ipairs(list) do if g.nodes[t] ~= nil then hits = hits + 1 end end
        if hits > bestHits then bestName, bestHits = treeName, hits end
      end
      result.trees[#result.trees + 1] = { name = bestName or ("Tree " .. i), points = g.points, nodes = g.nodes }
    end
    local top
    for _, t in ipairs(result.trees) do
      if t.points > 0 and (not top or t.points > top.points) then top = t end
    end
    result.top = top and top.name or nil
    result.ok = true
    result.info = ("%d trees, %d talents"):format(#result.trees, nodeCount)
  end)
  if not ok then result.info = "error: " .. tostring(err):gsub("^.-:%d+: ", "") end
  return result
end

---------------------------------------------------------------------------
-- Cached build (talents + weapon), refreshed out of combat
---------------------------------------------------------------------------

local cache

function ns.InvalidateBuild() cache = nil end

function ns.ReadBuild()
  if cache then return cache end
  local class = ns.GetClassToken()
  local t = ns.ReadTalents(class)
  cache = { weapon = ns.ReadWeapon(), talents = t, top = t.top }
  return cache
end

function ns.BuildSummary()
  local b = ns.ReadBuild()
  local parts = {}
  for _, tr in ipairs(b.talents.trees or {}) do
    parts[#parts + 1] = ("%s %d"):format(tr.name, tr.points)
  end
  local trees = #parts > 0 and table.concat(parts, " / ") or ("unknown (" .. tostring(b.talents.info) .. ")")
  return ("weapon: %s | talents: %s"):format(b.weapon or "unknown", trees)
end

---------------------------------------------------------------------------
-- Enemies nearby (enemy nameplates must be turned on)
---------------------------------------------------------------------------

function ns.CountEnemies()
  local n = 0
  local ok = pcall(function()
    for i = 1, 40 do
      local u = "nameplate" .. i
      if UnitExists(u) and UnitCanAttack("player", u) and not UnitIsDead(u) then n = n + 1 end
    end
  end)
  if not ok then n = 0 end
  local okT, hostileTarget = pcall(function()
    return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
  end)
  if okT and hostileTarget and n == 0 then n = 1 end
  return n
end
