-- Tactara: /tac probe
-- Reports which game information WoW Forever lets addons read, so the
-- build-aware "best next skill" feature can use whatever is available.
-- Run it once out of combat and once in combat (on a mob in the open world).

local ADDON, ns = ...
local unpack = unpack or table.unpack

local function IsHidden(v)
  if issecretvalue then
    local ok, secret = pcall(issecretvalue, v)
    if ok and secret then return true end
  end
  if v == nil then return false end
  local ok = pcall(function() local _ = (v == v) and tostring(v) end)
  return not ok
end

local function Fmt(...)
  local n = select("#", ...)
  if n == 0 then return "nil" end
  local parts = {}
  for i = 1, math.min(n, 8) do
    local v = select(i, ...)
    if IsHidden(v) then
      parts[#parts + 1] = "|cffff5555HIDDEN|r"
    elseif type(v) == "table" then
      local keys = {}
      for k, val in pairs(v) do
        if #keys < 6 then
          keys[#keys + 1] = tostring(k) .. "=" .. (IsHidden(val) and "HIDDEN" or tostring(val))
        end
      end
      parts[#parts + 1] = "{" .. table.concat(keys, " ") .. "}"
    else
      parts[#parts + 1] = tostring(v)
    end
  end
  return table.concat(parts, ", ")
end

local function Check(label, fn)
  local results = { pcall(fn) }
  local ok = table.remove(results, 1)
  local text
  if not ok then
    local err = tostring(results[1] or "?")
    if err:find("MISSING") then
      text = "|cffaaaaaano such API|r"
    else
      text = "|cffff5555error|r " .. err:gsub("^.-:%d+: ", ""):sub(1, 80)
    end
  else
    text = Fmt(unpack(results, 1, math.max(1, #results)))
  end
  ns.Print(("  %s: %s"):format(label, text))
end

local function need(f, name)
  if not f then error("MISSING " .. name) end
  return f
end

function ns.Probe()
  local inCombat = InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player"))
  ns.Print(("probe - %s, target: %s. Please screenshot this and send it over.")
    :format(inCombat and "|cffff5555IN COMBAT|r" or "|cff00ff00out of combat|r",
      tostring(UnitName and UnitName("target") or "none")))

  -- talents / build
  Check("talents (Tactara reader)", function()
    local t = ns.ReadTalents(ns.GetClassToken())
    local parts = {}
    for _, tr in ipairs(t.trees) do parts[#parts + 1] = tr.name .. " " .. tr.points end
    return t.info, table.concat(parts, " / ")
  end)
  Check("talent layout", function()
    local configID = need(C_ClassTalents and C_ClassTalents.GetActiveConfigID, "GetActiveConfigID")()
    local cfg = C_Traits.GetConfigInfo(configID)
    local trees, nodes, subs, minX, maxX, named = 0, 0, {}, nil, nil, 0
    for _, treeID in ipairs(cfg.treeIDs or {}) do
      trees = trees + 1
      for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
        local n = C_Traits.GetNodeInfo(configID, nodeID)
        if n and n.ID and n.ID ~= 0 then
          nodes = nodes + 1
          if n.subTreeID and n.subTreeID ~= 0 then subs[n.subTreeID] = true end
          if n.posX then
            minX = minX and math.min(minX, n.posX) or n.posX
            maxX = maxX and math.max(maxX, n.posX) or n.posX
          end
        end
      end
    end
    local subCount = 0
    for _ in pairs(subs) do subCount = subCount + 1 end
    return ("config %s, %d trees, %d nodes, %d sub-trees, x %s-%s"):format(
      tostring(configID), trees, nodes, subCount, tostring(minX), tostring(maxX))
  end)
  Check("weapon (Tactara reader)", function() return ns.ReadWeapon() end)
  Check("main hand / off hand", function()
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local function loc(slot)
      local id = GetInventoryItemID("player", slot)
      if not id then return "empty" end
      local _, _, _, l = f(id)
      return l
    end
    return loc(16), loc(17)
  end)
  Check("dual wielding", function() return need(IsDualWielding, "IsDualWielding")() end)
  Check("enemies near (Tactara)", function() return ns.CountEnemies() end)

  -- what can be read during a fight
  Check("your power (rage, energy or mana)", function() return need(UnitPower, "UnitPower")("player") end)
  Check("combo points (game / Tactara count)", function()
    local game = GetComboPoints and GetComboPoints("player", "target")
    return game, ns.ComboPoints()
  end)
  Check("pet", function()
    if not UnitExists("pet") then return "none" end
    return UnitName("pet"), UnitIsDead("pet") and "dead" or "alive"
  end)
  Check("target creature type", function() return UnitCreatureType("target") end)
  Check("target health / max", function() return UnitHealth("target"), UnitHealthMax("target") end)
  Check("YOUR health / max", function() return UnitHealth("player"), UnitHealthMax("player") end)
  Check("target casting (name, interruptible?)", function()
    local name, _, _, _, _, _, _, notInt = UnitCastingInfo("target")
    if not name then
      local cname, _, _, _, _, _, cnot = UnitChannelInfo("target")
      if not cname then return "not casting" end
      return cname, cnot
    end
    return name, notInt
  end)
  Check("Tactara reads target cast as", function() return ns.TargetCastState() end)
  -- a buff and a debuff your rotation checks, and two of its spells
  local comp = ns.compiled and ns.compiled.main
  local buff, debuff
  for _, e in ipairs(comp and comp.priority or {}) do
    for _, c in ipairs(e.live or {}) do
      if c.kind == "missing" and not buff then buff = c.arg end
      if c.kind == "nodebuff" and not debuff then debuff = c.arg end
    end
  end
  if buff then
    Check(buff .. " on you", function()
      local a = need(C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName, "GetAuraDataBySpellName")("player", buff, "HELPFUL")
      if a == nil then return "not up" end
      return a.expirationTime, a.duration
    end)
  end
  if debuff then
    Check(debuff .. " on target", function()
      local a = need(C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName, "GetAuraDataBySpellName")("target", debuff, "HARMFUL")
      if a == nil then return "not up" end
      return a.expirationTime, a.duration
    end)
  end
  local knownSpells = {}
  for _, s in ipairs(comp and comp.spells or {}) do
    if ns.IsKnown(s) and #knownSpells < 2 then knownSpells[#knownSpells + 1] = s end
  end
  for _, sp in ipairs(knownSpells) do
    Check(sp .. " cooldown", function() return need(C_Spell and C_Spell.GetSpellCooldown, "GetSpellCooldown")(sp) end)
    Check(sp .. " usable / no power", function() return need(C_Spell and C_Spell.IsSpellUsable, "IsSpellUsable")(sp) end)
  end
end
