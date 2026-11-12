-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: reading your build (talents + weapons) and nearby enemies.
--
-- WoW Forever uses the modern talent system (C_ClassTalents / C_Traits), even
-- though the trees look classic. This reader walks the active talent config,
-- adds up your points per tree and names each tree by its signature talents
-- (Mortal Strike = Arms, and so on). Everything is wrapped so that if the game
-- hides or lacks something, Tactara just falls back to weapons and spells.

local ADDON, ns = ...

-- Signature talents used to name talent trees. A tree gets the name whose
-- list matches the most of its talents, so a few renamed or removed talents
-- don't matter. Classic names plus the new WoW Forever ones.
local TREE_SIGNATURES = {
  WARRIOR = {
    Arms = { "Mortal Strike", "Sweeping Strikes", "Deep Wounds", "Tactical Mastery", "Improved Overpower",
      "Anger Management", "Impale", "Two-Handed Weapon Specialization", "Improved Rend" },
    Fury = { "Bloodthirst", "Death Wish", "Flurry", "Cruelty", "Improved Slam", "Enrage",
      "Unbridled Wrath", "Dual Wield Specialization", "Improved Berserker Rage" },
    Protection = { "Shield Slam", "Last Stand", "Concussion Blow", "Shield Specialization", "Defiance",
      "Improved Shield Block", "Toughness", "Improved Revenge", "One-Handed Weapon Specialization" },
  },
  PALADIN = {
    Holy = { "Holy Shock", "Divine Favor", "Light's Vigil", "Illumination", "Infusion of Light", "Voice of Truth",
      "Spiritual Focus", "Healing Light", "Divine Intellect", "Holy Power", "Improved Holy Strike", "Consecrated Ground" },
    Protection = { "Templar's Bulwark", "Holy Shield", "Swift Judgement", "Improved Seal of Fury", "Iron Creed",
      "Redoubt", "Reckoning", "Sacred Duty", "Shield Specialization", "Blessing of Sanctuary", "Improved Righteous Fury" },
    Retribution = { "Seal of Command", "Sacred Arbiter", "Twist of Light", "Repentance", "Vengeance",
      "Sanctified Judgement", "Holy Conduit", "Champion of the Light", "Vindication", "Conviction", "Benediction" },
  },
  HUNTER = {
    ["Beast Mastery"] = { "Bestial Wrath", "Intimidation", "Frenzy", "Ferocity", "Unleashed Fury", "Spirit Bond",
      "Endurance Training", "Bestial Discipline", "Improved Mend Pet", "Thick Hide", "Improved Aspect of the Hawk" },
    Marksmanship = { "Trueshot Aura", "Aimed Shot", "Scatter Shot", "Mortal Shots", "Lethal Shots", "Efficiency",
      "Barrage", "Hawk Eye", "Improved Serpent Sting", "Ranged Weapon Specialization", "Improved Arcane Shot" },
    Survival = { "Wyvern Sting", "Counterattack", "Deterrence", "Lightning Reflexes", "Killer Instinct",
      "Surefooted", "Savage Strikes", "Entrapment", "Monster Slaying", "Humanoid Slaying", "Trap Mastery" },
  },
  ROGUE = {
    Assassination = { "Mutilate", "Venom", "Cold Blood", "Seal Fate", "Vigor", "Lethality", "Malice",
      "Ruthlessness", "Relentless Strikes", "Blood Splatter", "Vile Poisons", "Improved Poisons", "Improved Slice and Dice" },
    Combat = { "Adrenaline Rush", "Blade Flurry", "Riposte", "Aggression", "Weapon Expertise", "Hack and Slash",
      "Flawless Execution", "Flash of Steel", "Coup de Grace", "Puncturing Wounds", "Composure", "Precision" },
    Subtlety = { "Hemorrhage", "Premeditation", "Preparation", "Ghostly Strike", "Opportunity", "Initiative",
      "Death Mark", "Boot Knife", "Dirty Tricks", "Quick Getaway", "Setup", "Serrated Blades", "Dirty Deeds" },
  },
  PRIEST = {
    Discipline = { "Penance", "Power Infusion", "Inner Focus", "Mental Agility", "Soul Warding", "Renewed Hope",
      "Divine Aegis", "Power in Light", "Twin Disciplines", "Meditation", "Martyrdom", "Improved Power Word: Shield",
      "Wand Specialization", "Silent Resolve", "Mental Strength" },
    Holy = { "Prayer of Mending", "Binding Heal", "Litany of Light", "Spirit of Redemption", "Holy Nova",
      "Spiritual Guidance", "Spiritual Healing", "Inspiration", "Divine Fury", "Searing Light", "Twilight Focus",
      "Improved Renew", "Blessed Recovery", "Holy Precision" },
    Shadow = { "Shadowform", "Vampiric Embrace", "Mind Flay", "Improved Mind Flay", "Silence", "Shadow Weaving",
      "Spirit Tap", "Blackout", "Darkness", "Devouring Contagion", "Early Demise", "Shadow Focus", "Shadow Reach" },
  },
  SHAMAN = {
    Elemental = { "Lava Burst", "Lightning Overload", "Earthbound", "Elemental Alacrity", "Elemental Fury",
      "Call of Thunder", "Concussion", "Convection", "Elemental Focus", "Reverberation", "Eye of the Storm",
      "Elemental Reach", "Call of Flame", "Improved Fire Nova", "Elemental Devastation" },
    Enhancement = { "Stormstrike", "Rage of the Farseer", "Maelstrom Weapon", "Improved Stormstrike",
      "Mental Quickness", "Mental Dexterity", "Spirit Weapons", "Shamanistic Focus", "Flurry", "Elemental Weapons",
      "Thundering Strikes", "Ancestral Knowledge", "Improved Ghost Wolf", "Anticipation" },
    Restoration = { "Riptide", "Water Shield", "Mana Tide Totem", "Nature's Swiftness", "Purification", "Healing Way",
      "Tidal Mastery", "Totemic Focus", "Mindfulness", "Natural Grace", "Ancestral Healing", "Restorative Totems",
      "Healing Focus", "Tidal Focus" },
  },
  MAGE = {
    Arcane = { "Arcane Power", "Presence of Mind", "Arcane Blast", "Arcane Wrath", "Missile Barrage",
      "Arcane Instability", "Arcane Mind", "Arcane Concentration", "Arcane Focus", "Arcane Subtlety",
      "Arcane Geometry", "Arcane Impact", "Arcane Shielding", "Magic Absorption", "Arcane Meditation" },
    Fire = { "Combustion", "Blast Wave", "Pyroblast", "Heating Up", "Ignite", "Impact", "Critical Mass", "Fire Power",
      "Wake of Fire", "Incineration", "Accelerant", "Improved Fireball", "Improved Scorch", "Master of Elements",
      "Burning Soul" },
    Frost = { "Ice Barrier", "Ice Lance", "Fingers of Frost", "Ice Block", "Cold Snap", "Shatter", "Winter's Chill",
      "Frostbite", "Ice Shards", "Improved Frostbolt", "Permafrost", "Frost Channeling", "Improved Blizzard" },
  },
  WARLOCK = {
    Affliction = { "Wrack", "Siphon Life", "Dark Pact", "Nightfall", "Shadow Mastery", "Malediction",
      "Improved Drains", "Pandemic", "Malevolence", "Soul Siphon", "Amplify Curse", "Grim Reach",
      "Improved Corruption", "Improved Life Tap", "Suppression" },
    Demonology = { "Demonic Pact", "Demonic Sacrifice", "Soul Link", "Master Demonologist", "Fel Domination",
      "Demonic Aegis", "Fel Vitality", "Demonic Energies", "Decimation", "Demonic Brand", "Demonic Knowledge",
      "Unholy Power", "Demonic Embrace", "Master Summoner" },
    Destruction = { "Incinerate", "Conflagrate", "Bane of Havoc", "Shadowburn", "Shadow and Flame", "Molten Skin",
      "Ruin", "Emberstorm", "Devastation", "Bane", "Cataclysm", "Improved Shadow Bolt", "Aftermath", "Pyroclasm" },
  },
  DRUID = {
    Balance = { "Moonkin Form", "Eclipse", "Insect Swarm", "Nature's Grace", "Moonfury", "Moonglow", "Vengeance",
      "Genesis", "Nature's Majesty", "Nature's Splendor", "Overgrowth", "Improved Wrath", "Improved Moonfire",
      "Nature's Reach", "Improved Entangling Roots" },
    Feral = { "Berserk", "Primal Bite", "Shifting Power", "Leader of the Pack", "Heart of the Wild", "Feral Charge",
      "Feral Swiftness", "Savage Fury", "Shredding Attacks", "Natural Reaction", "Rend and Tear", "Blood Frenzy",
      "Predatory Strikes", "Sharpened Claws", "Thick Hide", "Ferocity", "Brutal Impact" },
    Restoration = { "Wild Growth", "Swiftmend", "Gift of the Earthmother", "Living Spirit", "Naturalist",
      "Nature's Swiftness", "Gift of Nature", "Improved Regrowth", "Improved Rejuvenation", "Furor", "Reflection",
      "Nature's Focus", "Subtlety", "Natural Shapeshifter", "Improved Tranquility" },
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

-- Which tree (Arms, Fury...) a set of talents belongs to: the name whose
-- signature list matches the most of them. `nodes` is { [talent name] = anything }.
function ns.NameTalentTree(classToken, nodes)
  local bestName, bestHits = nil, 0
  for treeName, list in pairs(TREE_SIGNATURES[classToken or ""] or {}) do
    local hits = 0
    for _, t in ipairs(list) do if nodes[t] ~= nil then hits = hits + 1 end end
    if hits > bestHits then bestName, bestHits = treeName, hits end
  end
  return bestName
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
    for i, key in ipairs(order) do
      local g = groups[key]
      result.trees[#result.trees + 1] = { name = ns.NameTalentTree(classToken, g.nodes) or ("Tree " .. i), points = g.points, nodes = g.nodes }
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
