-- Cadence: buff/debuff timers from your own casts.
--
-- WoW Forever often won't tell addons which buffs and debuffs are up
-- (the lookup just comes back empty, in combat or even out of it). So when
-- you cast a spell the rotation checks with @missing / @nodebuff / @ifmissing
-- (Battle Shout, Rend, Thunder Clap, ...), Cadence starts its own countdown.
-- If the game does answer, its answer wins and teaches Cadence the real
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

-- Called for every successful cast of yours.
function ns.TrackCast(spellName)
  if not spellName then return end
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
f:SetScript("OnEvent", function()
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
