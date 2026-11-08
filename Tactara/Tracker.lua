-- Tactara: buff/debuff timers from your own casts.
--
-- WoW Forever often won't tell addons which buffs and debuffs are up
-- (the lookup just comes back empty, in combat or even out of it). So when
-- you cast a spell the rotation checks with @missing / @nodebuff / @ifmissing
-- (Battle Shout, Rend, Thunder Clap, ...), Tactara starts its own countdown.
-- If the game does answer, its answer wins and teaches Tactara the real
-- duration for next time.

local ADDON, ns = ...

-- Durations by level, from the Classic ranks. Learned from the game when it shows them.
local function ByLevel(steps)
  return function(level)
    local d = steps[1][2]
    for _, s in ipairs(steps) do
      if level >= s[1] then d = s[2] end
    end
    return d
  end
end

local DEFAULT_DURATIONS = {
  ["Battle Shout"] = 120,
  ["Commanding Shout"] = 120,
  ["Demoralizing Shout"] = 30,
  ["Sunder Armor"] = 30,
  ["Rend"] = ByLevel({ { 1, 9 }, { 10, 12 }, { 20, 15 }, { 30, 18 }, { 40, 21 } }),
  ["Thunder Clap"] = ByLevel({ { 1, 10 }, { 18, 14 }, { 28, 18 }, { 38, 22 }, { 48, 26 }, { 58, 30 } }),
  ["Hamstring"] = 15,
  -- Paladin (Seals last 30 sec; Judgement no longer ends them in Forever)
  ["Seal of Righteousness"] = 30, ["Seal of Command"] = 30, ["Seal of Fury"] = 30,
  ["Seal of the Crusader"] = 30, ["Seal of Light"] = 30, ["Seal of Wisdom"] = 30, ["Seal of Justice"] = 30,
  ["Blessing of Kings"] = 3600, ["Blessing of Might"] = 3600, ["Blessing of Wisdom"] = 3600,
  ["Blessing of Light"] = 3600, ["Blessing of Sanctuary"] = 3600,
  ["Righteous Fury"] = 1800,
  ["Devotion Aura"] = 7200, ["Retribution Aura"] = 7200, ["Concentration Aura"] = 7200,
  -- Hunter (aspects and Trueshot Aura stay until you change them)
  ["Aspect of the Hawk"] = 7200, ["Aspect of the Monkey"] = 7200, ["Aspect of the Beast"] = 7200,
  ["Aspect of the Wild"] = 7200, ["Trueshot Aura"] = 7200,
  ["Hunter's Mark"] = 120, ["Serpent Sting"] = 15, ["Scorpid Sting"] = 20, ["Viper Sting"] = 8,
  -- Rogue (finishers: average length, since combo points are hidden)
  ["Slice and Dice"] = 15, ["Rupture"] = 12, ["Venom"] = 15, ["Expose Armor"] = 30,
  -- Priest
  ["Power Word: Fortitude"] = 1800, ["Inner Fire"] = 600, ["Divine Spirit"] = 1800, ["Shadowform"] = 7200,
  ["Shadow Word: Pain"] = 18, ["Devouring Plague"] = 24, ["Holy Fire"] = 10, ["Vampiric Embrace"] = 30,
  -- Shaman (shields lose charges as you're hit, so these are rough; totems
  -- are timed from when you drop them)
  ["Lightning Shield"] = 90, ["Water Shield"] = 90, ["Flame Shock"] = 12,
  ["Searing Totem"] = 30, ["Magma Totem"] = 20, ["Strength of Earth Totem"] = 300, ["Stoneskin Totem"] = 300,
  ["Windfury Totem"] = 300, ["Grace of Air Totem"] = 300, ["Mana Spring Totem"] = 300, ["Healing Stream Totem"] = 300,
  -- Mage
  ["Arcane Intellect"] = 1800, ["Frost Armor"] = 1800, ["Ice Armor"] = 1800, ["Mage Armor"] = 1800,
  ["Ice Barrier"] = 60, ["Mana Shield"] = 60,
  -- Warlock
  ["Demon Armor"] = 1800, ["Demon Skin"] = 1800, ["Corruption"] = 18, ["Bane of Agony"] = 24,
  ["Immolate"] = 15, ["Siphon Life"] = 30, ["Searing Pain"] = 8,
  -- Druid
  ["Mark of the Wild"] = 1800, ["Thorns"] = 600, ["Omen of Clarity"] = 600, ["Moonkin Form"] = 7200,
  ["Moonfire"] = 12, ["Insect Swarm"] = 12, ["Faerie Fire"] = 40, ["Faerie Fire (Feral)"] = 40,
  ["Rake"] = 9, ["Rip"] = 12, ["Demoralizing Roar"] = 30,
}
local FALLBACK = { player = 60, target = 15 }

local tracked = { player = {}, target = {} }   -- [key][spell] = expires (GetTime)
local learned = {}                              -- [spell] = seconds
local watch = {}                                -- [spell] = "player" / "target"

-- Which spells to time: anything the rotation checks as a buff or debuff.
function ns.SetTrackedSpells(rot)
  for k in pairs(watch) do watch[k] = nil end
  if not rot then return end
  for _, list in pairs(rot.sections) do
    for _, item in ipairs(list) do
      local lines = item.lines or { item }
      for _, line in ipairs(lines) do
        for _, c in ipairs(line.conds or {}) do
          if c.kind == "missing" or c.kind == "ifmissing" then watch[c.arg] = "player" end
          if c.kind == "nodebuff" then watch[c.arg] = "target" end
        end
      end
    end
  end
end

local function TargetKey()
  local ok, key = pcall(function()
    local guid = UnitGUID("target")
    if guid == nil then return nil end
    return tostring(guid) .. ""          -- errors if the GUID is hidden
  end)
  if ok and key then return key end
  return "current target"
end

local function Duration(spell, unitKind)
  if learned[spell] then return learned[spell] end
  local d = DEFAULT_DURATIONS[spell]
  if type(d) == "function" then
    local okL, level = pcall(UnitLevel, "player")
    d = d(okL and tonumber(level) or 60)
  end
  return d or FALLBACK[unitKind] or 15
end

function ns.LearnDuration(spell, seconds)
  local ok, valid = pcall(function() return type(seconds) == "number" and seconds > 1 and seconds < 3600 end)
  if ok and valid then learned[spell] = seconds end
end

---------------------------------------------------------------------------
-- Combo points (Rogue, Druid in Cat Form). If the game shows them, that
-- number is used; otherwise Tactara counts your builders since the last
-- finisher (an estimate: extra points from crits and procs aren't seen).
---------------------------------------------------------------------------

local BUILDERS = {
  ["Sinister Strike"] = 1, ["Backstab"] = 1, ["Hemorrhage"] = 1, ["Ghostly Strike"] = 1, ["Gouge"] = 1,
  ["Garrote"] = 1, ["Ambush"] = 1, ["Shank"] = 1, ["Mutilate"] = 2, ["Cheap Shot"] = 2,
  ["Claw"] = 1, ["Shred"] = 1, ["Rake"] = 1, ["Pounce"] = 1, ["Ravage"] = 1, ["Mangle"] = 1,
}
local FINISHERS = {
  ["Eviscerate"] = true, ["Slice and Dice"] = true, ["Rupture"] = true, ["Kidney Shot"] = true,
  ["Expose Armor"] = true, ["Venom"] = true, ["Ferocious Bite"] = true, ["Rip"] = true,
}
local counted = 0

function ns.ComboPoints()
  local ok, n = pcall(function()
    local v
    if GetComboPoints then v = GetComboPoints("player", "target") end
    if v == nil and UnitPower then v = UnitPower("player", 4) end   -- Enum.PowerType.ComboPoints
    if v == nil then return nil end
    return tonumber(tostring(v) .. "")      -- errors if the game hides it
  end)
  if ok and n then return n end
  return counted
end

local function CountCombo(spellName)
  if BUILDERS[spellName] then
    counted = math.min(5, counted + BUILDERS[spellName])
  elseif FINISHERS[spellName] then
    counted = 0
  end
end

-- Called for every successful cast of yours.
function ns.TrackCast(spellName)
  if not spellName then return end
  CountCombo(spellName)
  local ok, kind = pcall(function() return watch[spellName] end)
  if not ok or not kind then return end
  local bucket
  if kind == "player" then
    tracked.player.me = tracked.player.me or {}
    bucket = tracked.player.me
  else
    local key = TargetKey()
    tracked.target[key] = tracked.target[key] or {}
    bucket = tracked.target[key]
  end
  local d = Duration(spellName, kind)
  bucket[spellName] = GetTime() + d
  ns.Debug(("tracking %s for %ds"):format(spellName, d))
end

-- Seconds left on our own timer, or nil if we haven't seen it cast.
function ns.TrackedRemaining(unit, spell)
  local bucket
  if unit == "player" then
    bucket = tracked.player.me
  else
    bucket = tracked.target[TargetKey()]
  end
  local exp = bucket and bucket[spell]
  if not exp then return nil end
  local left = exp - GetTime()
  if left <= 0 then
    bucket[spell] = nil
    return nil
  end
  return left
end

-- If we can't tell targets apart, a new target means unknown debuffs.
local f = CreateFrame("Frame")
ns.trackerFrame = f
pcall(f.RegisterEvent, f, "PLAYER_TARGET_CHANGED")
pcall(f.RegisterEvent, f, "PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" then counted = 0 return end   -- points fade after the fight
  tracked.target["current target"] = nil
end)

function ns.TrackerSummary()
  local parts = {}
  for spell, exp in pairs(tracked.player.me or {}) do
    local left = exp - GetTime()
    if left > 0 then parts[#parts + 1] = ("%s %ds"):format(spell, left) end
  end
  for spell in pairs(watch) do
    local left = ns.TrackedRemaining("target", spell)
    if left and watch[spell] == "target" then parts[#parts + 1] = ("%s on target %ds"):format(spell, left) end
  end
  table.sort(parts)
  return #parts > 0 and table.concat(parts, ", ") or "none"
end
