-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: reminders. Both only tell you; nothing here casts, buys or
-- changes anything.
--
--   * Trainer: when you level up, which spells are waiting at your class
--     trainer, the ones your rotation uses first. Read from the spellbook's
--     "not learned yet" spells, so it covers new spells (not new ranks).
--   * Before the pull: when you target an enemy out of combat, a buff your
--     rotation keeps up, your pet, or a poison / weapon imbue that isn't
--     there or is running low. Shown under the helper popup, and in chat now
--     and then.
--   * After the fight: the same for buffs of a minute or more (no Seals), a
--     couple of seconds after combat ends, without a target.
--   * Supplies: a Hunter's ammo, a Warlock's Soul Shards, and the reagents
--     and totems your spells need. Under the helper popup with the line
--     above, in chat when one runs low, and at a vendor that sells it.

local ADDON, ns = ...

local R = {}
ns.Reminders = R

local CHAT_GAP = 60      -- seconds between before-the-pull chat lines
local CHAT_SAME = 300    -- the same reminder again in chat after this long
local MAX_NAMES = 8      -- names listed in one chat line

local function InCombat()
  return InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player")) or false
end

local function HostileTarget()
  local ok, result = pcall(function()
    return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
  end)
  return ok and result and true or false
end

local function PlayerLevel()
  local ok, lvl = pcall(UnitLevel, "player")
  return ok and tonumber(lvl) or nil
end

-- "A, B, C and 2 more"
local function JoinNames(list)
  if #list <= MAX_NAMES then return table.concat(list, ", ") end
  local shown = {}
  for i = 1, MAX_NAMES do shown[i] = list[i] end
  return table.concat(shown, ", ") .. (" and %d more"):format(#list - MAX_NAMES)
end

---------------------------------------------------------------------------
-- Trainer
---------------------------------------------------------------------------

-- The level a spell is learned at, or nil if the game won't say.
local function LevelLearned(id, slot, bank)
  local function num(v)
    v = tonumber(v)
    if v and v > 0 then return v end
    return nil
  end
  if slot and C_SpellBook and C_SpellBook.GetSpellBookItemLevelLearned then
    local ok, v = pcall(C_SpellBook.GetSpellBookItemLevelLearned, slot, bank)
    if ok and num(v) then return num(v) end
  end
  if id and C_Spell and C_Spell.GetSpellLevelLearned then
    local ok, v = pcall(C_Spell.GetSpellLevelLearned, id)
    if ok and num(v) then return num(v) end
  end
  if id and GetSpellLevelLearned then
    local ok, v = pcall(GetSpellLevelLearned, id)
    if ok and num(v) then return num(v) end
  end
  if slot and GetSpellAvailableLevel then
    local ok, v = pcall(GetSpellAvailableLevel, slot, "spell")
    if ok and num(v) then return num(v) end
  end
  return nil
end

-- Every spell the spellbook lists as not learned yet:
-- { name, id, level (or nil), line }. Other specs' and guild lines are left out.
function R.FutureSpells()
  local out, seen = {}, {}
  local function add(name, id, level, line)
    if type(name) ~= "string" or name == "" or seen[name] then return end
    seen[name] = true
    out[#out + 1] = { name = name, id = id, level = level, line = line }
  end

  local SB = C_SpellBook
  if SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemInfo
    and Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell then
    local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local okN, n = pcall(SB.GetNumSpellBookSkillLines)
    for li = 1, (okN and tonumber(n) or 0) do
      local okL, line = pcall(SB.GetSpellBookSkillLineInfo, li)
      if okL and type(line) == "table" and not line.isGuild and not line.shouldHide
        and (tonumber(line.offSpecID) or 0) == 0 then
        local first = (tonumber(line.itemIndexOffset) or 0) + 1
        for slot = first, first + (tonumber(line.numSpellBookItems) or 0) - 1 do
          local okI, info = pcall(SB.GetSpellBookItemInfo, slot, bank)
          if okI and type(info) == "table" and info.itemType == Enum.SpellBookItemType.FutureSpell
            and not info.isOffSpec then
            local id = info.spellID or info.actionID
            add(info.name or (id and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)),
              id, LevelLearned(id, slot, bank), line.name)
          end
        end
      end
    end
    return out
  end

  -- older spellbook functions
  if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
    local okN, tabs = pcall(GetNumSpellTabs)
    for t = 1, (okN and tonumber(tabs) or 0) do
      local okT, tabName, _, offset, numSlots, isGuild, offSpec = pcall(GetSpellTabInfo, t)
      if okT and not isGuild and (tonumber(offSpec) or 0) == 0 then
        for slot = (offset or 0) + 1, (offset or 0) + (numSlots or 0) do
          local okI, kind, id = pcall(GetSpellBookItemInfo, slot, "spell")
          if okI and kind == "FUTURESPELL" then
            local name
            if GetSpellBookItemName then
              local okName, n = pcall(GetSpellBookItemName, slot, "spell")
              if okName then name = n end
            end
            if type(name) ~= "string" and id and C_Spell and C_Spell.GetSpellName then
              local okName, n = pcall(C_Spell.GetSpellName, id)
              if okName then name = n end
            end
            add(name, id, LevelLearned(id, slot, "spell"), tabName)
          end
        end
      end
    end
  end
  return out
end

-- Spells your rotation uses that you haven't learned, as a set.
local function RotationWants()
  local set = {}
  if ns.RotationSpells then
    local ok, _, missing = pcall(ns.RotationSpells)
    if ok and type(missing) == "table" then
      for _, s in ipairs(missing) do set[s] = true end
    end
  end
  return set
end

-- Spells you can learn now (learn level at or below yours), the ones your
-- rotation uses first, then by level.
function R.TrainerSpells(level)
  level = tonumber(level) or PlayerLevel()
  local list = {}
  if not level then return list end
  local wants = RotationWants()
  for _, s in ipairs(R.FutureSpells()) do
    if s.level and s.level <= level then
      s.inRotation = wants[s.name] or false
      list[#list + 1] = s
    end
  end
  table.sort(list, function(a, b)
    if a.inRotation ~= b.inRotation then return a.inRotation end
    if a.level ~= b.level then return a.level < b.level end
    return a.name < b.name
  end)
  return list
end

function R.TrainerMessage(list)
  if not list or #list == 0 then return nil end
  local inRot, other = {}, {}
  for _, s in ipairs(list) do
    if s.inRotation then inRot[#inRot + 1] = "|cff00ff00" .. s.name .. "|r" else other[#other + 1] = s.name end
  end
  local parts = {}
  if #inRot > 0 then parts[#parts + 1] = JoinNames(inRot) .. " (in your rotation)" end
  if #other > 0 then parts[#parts + 1] = JoinNames(other) end
  return ("%d spell%s waiting at your class trainer: %s."):format(#list, #list == 1 and " is" or "s are",
    table.concat(parts, "; "))
end

-- atLogin: only speak up when your rotation is waiting on something.
function R.CheckTrainer(level, atLogin)
  if TactaraCharDB.trainerReminder == false then return false end
  local list = R.TrainerSpells(level)
  if #list == 0 then return false end
  if atLogin and not list[1].inRotation then return false end
  ns.Print(R.TrainerMessage(list))
  return true
end

-- /tac trainer: the list now, whatever the setting
function R.ShowTrainer()
  local list = R.TrainerSpells()
  if #list == 0 then
    ns.Print("Nothing new is waiting at your class trainer for your level.")
  else
    ns.Print(R.TrainerMessage(list))
  end
end

---------------------------------------------------------------------------
-- Before the pull
---------------------------------------------------------------------------

local PREP_KINDS = { missing = true, nopet = true }

local POISONS = { "Instant Poison", "Deadly Poison", "Wound Poison", "Crippling Poison",
  "Mind-numbing Poison", "Mind-Numbing Poison", "Numbing Poison", "Anesthetic Poison", "Leeching Poison" }
local IMBUES = { "Windfury Weapon", "Flametongue Weapon", "Earthliving Weapon", "Rockbiter Weapon",
  "Frostbrand Weapon" }
R.POISONS, R.IMBUES = POISONS, IMBUES

local function KnownOf(list)
  local out = {}
  for _, s in ipairs(list) do
    local name = ns.Locale.Spell(s)
    if ns.IsKnown(name) then out[#out + 1] = name end
  end
  return out
end

-- Rage spells (a Warrior's shouts) only count when you have the rage.
local function CostsRage(name)
  if C_Spell and C_Spell.GetSpellPowerCost then
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, name)
    if ok and type(costs) == "table" then
      for _, c in ipairs(costs) do
        local okT, rage = pcall(function() return c.type == 1 or c.name == "RAGE" end)
        if okT and rage then return true end
      end
      return false
    end
  end
  local _, class = UnitClass("player")
  return class == "WARRIOR"
end

local function OnCooldown(name)
  local start, dur = 0, 0
  if ns.IconCooldown then start, dur = ns.IconCooldown(name) end
  return (dur or 0) > 0
end

-- Is there a weapon in this slot (16 main hand, 17 off hand) that takes a
-- poison or imbue? Shields and off-hand items don't.
local OFFHAND_WEAPONS = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true }
local function WeaponIn(slot)
  if not GetInventoryItemID then return false end
  local ok, id = pcall(GetInventoryItemID, "player", slot)
  if not (ok and id) then return false end
  if slot == 16 then return true end
  if not (C_Item and C_Item.GetItemInfoInstant) then return false end
  local okI, _, _, _, equipLoc = pcall(C_Item.GetItemInfoInstant, id)
  return okI and OFFHAND_WEAPONS[equipLoc] or false
end

-- "4 min left", "40 sec left"
local function LeftText(sec)
  if sec >= 120 then return ("%d min left"):format(math.ceil(sec / 60)) end
  return ("%d sec left"):format(math.max(1, math.floor(sec)))
end
R.LeftText = LeftText

-- Poisons last 30 minutes, Shaman weapon imbues 5.
local COAT_LENGTH = { ROGUE = 1800, SHAMAN = 300 }

-- "missing" or "low" (with seconds left) = something to remind about,
-- false = all good, nil = can't tell.
local function WeaponNeedsCoat(spells, class)
  if #spells == 0 or not GetWeaponEnchantInfo then return false end
  local lowAt = ns.BuffLowAt(COAT_LENGTH[class] or 1800)
  -- some clients put poisons on you as a buff instead of on the weapon
  if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
    for _, s in ipairs(spells) do
      local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", s, "HELPFUL")
      if ok and aura ~= nil then
        local left, full = ns.BuffTimeLeft(s)
        if left and left > 0 and left < ns.BuffLowAt(full) then return "low", left end
        return false
      end
    end
  end
  local ok, mh, mhExp, _, _, oh, ohExp = pcall(GetWeaponEnchantInfo)
  if not ok then return nil end
  local okB, need, left = pcall(function()
    local bare, soonest = false, nil
    for _, w in ipairs({ { 16, mh, mhExp }, { 17, oh, ohExp } }) do
      if WeaponIn(w[1]) then
        if not w[2] then bare = true
        elseif type(w[3]) == "number" and w[3] > 0 then
          local sec = w[3] / 1000          -- the game counts in milliseconds
          if not soonest or sec < soonest then soonest = sec end
        end
      end
    end
    if bare then return "missing" end
    if soonest and soonest < lowAt then return "low", soonest end
    return false
  end)
  if not okB then return nil end
  return need, left
end

-- After the fight: buffs of a minute or more. Seals (30 seconds) would run
-- out before the next pull anyway; Battle Shout counts, for leftover rage.
R.AFTER_FIGHT_SHORTEST = 60

-- Is this [priority] line's buff missing or running low? "missing", or
-- "low" with seconds left; false = fine or can't tell.
local function BuffState(e)
  if ns.LiveOK(e) then return "missing" end
  if #e.live ~= 1 or e.live[1].kind ~= "missing" then return false end
  local left, full = ns.BuffTimeLeft(e.live[1].arg)
  if left and left > 0 and left ~= math.huge and left < ns.BuffLowAt(full) then return "low", left end
  return false
end

-- after = the after-the-fight check: no target needed, only longer buffs.
local function BuffChecks(comp, after)
  local out, seen = {}, {}
  if not comp then return out end
  local pets, buffs = {}, {}
  for _, e in ipairs(comp.priority or {}) do
    local prep = #e.live > 0 and not ns.Locale.English(e.spell):find("Totem$")
    local pet, buff = false, nil
    for _, c in ipairs(e.live) do
      if not PREP_KINDS[c.kind] then prep = false end
      if c.kind == "nopet" then pet = true end
      if c.kind == "missing" then buff = c.arg end
    end
    if prep and after and buff and not pet then
      local full = ns.BuffDuration(ns.Locale.English(buff))
      if full < R.AFTER_FIGHT_SHORTEST then prep = false end
    end
    local state, left
    if prep and not seen[e.spell] then
      if pet then state = ns.LiveOK(e) and "missing" or false else state, left = BuffState(e) end
    end
    if state and not OnCooldown(e.spell) and not (CostsRage(e.spell) and ns.UsableState(e.spell) ~= "yes") then
      seen[e.spell] = true
      if pet then
        if #pets == 0 then pets[1] = { spell = e.spell, text = "your pet", kind = "pet" } end
      else
        local text = e.spell
        if state == "low" then text = ("%s (%s)"):format(e.spell, LeftText(left)) end
        buffs[#buffs + 1] = { spell = e.spell, text = text, kind = "buff", low = state == "low" }
      end
    end
  end
  for _, x in ipairs(pets) do out[#out + 1] = x end
  for _, x in ipairs(buffs) do out[#out + 1] = x end

  local _, class = UnitClass("player")
  local coats = (class == "ROGUE" and KnownOf(POISONS)) or (class == "SHAMAN" and KnownOf(IMBUES)) or {}
  local need, left = WeaponNeedsCoat(coats, class)
  if need then
    local text = class == "ROGUE" and "a poison on your weapons" or "a weapon imbue"
    if need == "low" then text = ("%s (%s)"):format(text, LeftText(left)) end
    out[#out + 1] = { spell = coats[1], text = text, kind = "weapon", low = need == "low" }
  end
  return out
end

-- What's missing or running low before the pull: a list of { spell = icon
-- spell, text = short label, kind }. Pet first, then buffs from the
-- rotation's [priority] list (@missing / @nopet lines only, no totems), then
-- poisons or weapon imbues.
function R.PrePullList(comp)
  return BuffChecks(comp or (ns.HelperComp and ns.HelperComp()), false)
end

-- The same after a fight, without a target, leaving out buffs shorter than a
-- minute (Seals): they'd run out before the next pull anyway.
function R.AfterFightList(comp)
  return BuffChecks(comp or (ns.HelperComp and ns.HelperComp()), true)
end

local function Mode()
  local m = TactaraCharDB and TactaraCharDB.prePull
  if m == "helper" or m == "off" then return m end
  return "both"
end

local function Texts(list)
  local t = {}
  for _, x in ipairs(list) do t[#t + 1] = x.text end
  return t
end

-- What the throttles compare: the buffs, not the minutes left.
local function Keys(list)
  local t = {}
  for _, x in ipairs(list) do t[#t + 1] = tostring(x.spell or x.text) .. (x.low and "~" or "") end
  return table.concat(t, "|")
end

-- The optional sound with a buff reminder (off unless you pick one).
local function BuffSound()
  local key = TactaraCharDB and TactaraCharDB.buffSound
  if key and key ~= "off" and ns.PlayAlert then ns.PlayAlert(key) end
end

local AFTER_SHOW = 30     -- the after-the-fight line stays under the helper this long
local AFTER_SAME = 120    -- the same after-the-fight chat line at most every 2 minutes
local afterUntil, afterLast, afterKey = -1e9, -1e9, nil
local lastChat, lastChatKey = -1e9, nil

-- The lines under the helper popup, or nil when there's nothing to say.
function R.PrePullText()
  if InCombat() then return nil end
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return nil end
  local hostile = HostileTarget()
  local lines = {}
  if Mode() ~= "off" then
    if hostile then
      local list = R.PrePullList()
      if #list > 0 then lines[#lines + 1] = "|cffff9933Before the pull:|r " .. JoinNames(Texts(list)) end
    elseif GetTime() < afterUntil then
      local list = R.AfterFightList()
      if #list > 0 then lines[#lines + 1] = "|cffff9933After the fight:|r " .. JoinNames(Texts(list)) end
    end
  end
  if hostile and R.SupplyMode() ~= "off" then
    local list = R.Supplies()
    if #list > 0 then lines[#lines + 1] = "|cffff9933Supplies:|r " .. JoinNames(Texts(list)) end
  end
  if #lines == 0 then return nil end
  return table.concat(lines, "\n")
end

-- A chat line when you pick an enemy and something's missing or running low:
-- at most once a minute, and the same reminder at most every five minutes.
function R.ChatPrePull()
  if Mode() == "off" or InCombat() or not HostileTarget() then return false end
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false end
  -- riding past enemies isn't a pull; the line under the helper still shows
  if (IsMounted and IsMounted()) or (UnitOnTaxi and UnitOnTaxi("player")) then return false end
  local list = R.PrePullList()
  if #list == 0 then return false end
  local key = Keys(list)
  local now = GetTime()
  if (key ~= lastChatKey and now - lastChat >= CHAT_GAP) or now - lastChat >= CHAT_SAME then
    lastChat, lastChatKey = now, key
    BuffSound()
    if Mode() ~= "both" then return false end
    ns.Print("Before you pull: " .. JoinNames(Texts(list)) .. ".")
    return true
  end
  return false
end

-- A couple of seconds after a fight: the buffs your rotation keeps up that
-- last a minute or more (Blessings, Fortitude, armors, Battle Shout when you
-- have the rage, Mark of the Wild...), your pet and your
-- poisons or imbues, if any are missing or running low. Under the helper for
-- 30 seconds and in chat (the same line at most every 2 minutes).
function R.AfterFight()
  if Mode() == "off" or InCombat() then return false end
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false end
  if UnitOnTaxi and UnitOnTaxi("player") then return false end
  local list = R.AfterFightList()
  if #list == 0 then
    afterUntil = -1e9
    return false
  end
  local now = GetTime()
  afterUntil = now + AFTER_SHOW
  local key, said = Keys(list), false
  if key ~= afterKey or now - afterLast >= AFTER_SAME then
    afterKey, afterLast = key, now
    BuffSound()
    if Mode() == "both" then
      ns.Print("After the fight: " .. JoinNames(Texts(list)) .. ".")
      lastChat = now        -- and no "before you pull" line right on top of it
      said = true
    end
  end
  if ns.HelperRefresh then ns.HelperRefresh() end
  if C_Timer and C_Timer.After then
    C_Timer.After(AFTER_SHOW + 0.5, function() if ns.HelperRefresh then ns.HelperRefresh() end end)
  end
  return said
end

function R.ResetChatThrottle()
  lastChat, lastChatKey = -1e9, nil
  afterUntil, afterLast, afterKey = -1e9, -1e9, nil
end

---------------------------------------------------------------------------
-- Supplies: ammo, Soul Shards, reagents and totems
---------------------------------------------------------------------------

R.AMMO_LOW = 200      -- one stack of arrows or bullets
R.SHARD_LOW = 2       -- fewer Soul Shards than this
local SUPPLY_SAME = 600   -- the same supply line in chat at most every 10 minutes

-- English names, for when the game hasn't loaded an item's own name yet.
local ITEM_NAMES = {
  [6265] = "Soul Shard", [5140] = "Flash Powder", [5530] = "Blinding Powder", [17030] = "Ankh",
  [17056] = "Light Feather", [17020] = "Arcane Powder", [17028] = "Holy Candle", [17029] = "Sacred Candle",
  [17034] = "Maple Seed", [17035] = "Stranglethorn Seed", [17036] = "Ashwood Seed", [17037] = "Hornbeam Seed",
  [17038] = "Ironwood Seed", [17021] = "Wild Berries", [17026] = "Wild Thornroot", [17033] = "Symbol of Divinity",
  [21177] = "Symbol of Kings", [5565] = "Infernal Stone", [16583] = "Demonic Figurine",
  [5175] = "Earth Totem", [5176] = "Fire Totem", [5177] = "Water Totem", [5178] = "Air Totem",
}
R.ITEM_NAMES = ITEM_NAMES
local SOUL_SHARD = 6265

-- Spells that use up an item in WoW: Forever (from the Icy Veins spell
-- database, November 2026). Items go by ID, so any game language works.
-- always: checked whenever you know the spell; the rest only when your
-- rotation casts it. ranks: which item each rank needs, highest rank first.
R.REAGENTS = {
  { spell = "Reincarnation", item = 17030, always = true },
  { spell = "Vanish", item = 5140 },
  { spell = "Blind", item = 5530 },
  { spell = "Slow Fall", item = 17056 },
  { spell = "Levitate", item = 17056 },
  { spell = "Arcane Brilliance", item = 17020 },
  { spell = "Prayer of Fortitude", item = 17028, ranks = { { 21564, 17029 }, { 21562, 17028 } } },
  { spell = "Prayer of Spirit", item = 17029 },
  { spell = "Gift of the Wild", item = 17021, ranks = { { 21850, 17026 }, { 21849, 17021 } } },
  { spell = "Rebirth", item = 17034,
    ranks = { { 20748, 17038 }, { 20747, 17037 }, { 20742, 17036 }, { 20739, 17035 }, { 20484, 17034 } } },
  { spell = "Divine Intervention", item = 17033 },
  { spell = "Greater Blessing of Kings", item = 21177 },
  { spell = "Greater Blessing of Might", item = 21177 },
  { spell = "Greater Blessing of Wisdom", item = 21177 },
  { spell = "Greater Blessing of Salvation", item = 21177 },
  { spell = "Greater Blessing of Light", item = 21177 },
  { spell = "Greater Blessing of Sanctuary", item = 21177 },
  { spell = "Inferno", item = 5565 },
  { spell = "Ritual of Doom", item = 16583 },
}

-- A Shaman's totems need the element's totem in your bags (it isn't used up).
R.TOTEM_TOOLS = {
  { item = 5175, element = "Earth", totems = { "Stoneskin Totem", "Earthbind Totem", "Strength of Earth Totem",
    "Stoneclaw Totem", "Tremor Totem" } },
  { item = 5176, element = "Fire", totems = { "Searing Totem", "Fire Nova Totem", "Magma Totem", "Flametongue Totem",
    "Frost Resistance Totem" } },
  { item = 5177, element = "Water", totems = { "Healing Stream Totem", "Mana Spring Totem", "Poison Cleansing Totem",
    "Disease Cleansing Totem", "Fire Resistance Totem", "Mana Tide Totem" } },
  { item = 5178, element = "Air", totems = { "Grounding Totem", "Nature Resistance Totem", "Windfury Totem",
    "Sentry Totem", "Windwall Totem", "Grace of Air Totem", "Tranquil Air Totem" } },
}

function R.SupplyMode()
  local m = TactaraCharDB and TactaraCharDB.supplies
  if m == "helper" or m == "off" then return m end
  return "both"
end

-- How many of an item are in your bags, or nil if the game won't say.
local function ItemCount(id)
  local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
  if not fn then return nil end
  local ok, n = pcall(function() return tonumber(fn(id)) end)
  if ok then return n end
  return nil
end

local function ItemName(id)
  local fn = (C_Item and C_Item.GetItemNameByID) or GetItemInfo
  if fn then
    local ok, name = pcall(fn, id)
    if ok and type(name) == "string" and name ~= "" then return name end
  end
  return ITEM_NAMES[id] or ("item " .. tostring(id))
end
R.ItemName = ItemName

-- The item's class and subclass (6/2 arrows, 6/3 bullets, 2/2 a bow...).
local function ItemClass(id)
  if not (id and C_Item and C_Item.GetItemInfoInstant) then return nil end
  local ok, _, _, _, _, _, classID, subID = pcall(C_Item.GetItemInfoInstant, id)
  if ok then return classID, subID end
  return nil
end

-- bows and crossbows fire arrows (2), guns fire bullets (3)
local AMMO_FOR = { [2] = 2, [18] = 2, [3] = 3 }
local AMMO_WORDS = { [2] = { "arrow", "arrows" }, [3] = { "bullet", "bullets" } }

-- What your ranged weapon fires: 2 arrows, 3 bullets, false nothing (no
-- weapon, a wand or thrown), nil if the game won't say.
function R.AmmoKind()
  if not (GetInventoryItemID and C_Item and C_Item.GetItemInfoInstant) then return nil end
  for _, slot in ipairs({ 18, 16 }) do       -- the ranged slot, else a bow in the main hand
    local ok, id = pcall(GetInventoryItemID, "player", slot)
    if not ok then return nil end
    if id then
      local classID, subID = ItemClass(id)
      if classID == nil then return nil end
      if classID == 2 and AMMO_FOR[subID] then return AMMO_FOR[subID] end
      if slot == 18 then return false end
    end
  end
  return false
end

-- Shots left: the ammo you have equipped, counted across your bags, or
-- (no ammo slot) every arrow or bullet in your bags that fits. nil = can't tell.
function R.AmmoCount(kind)
  if GetInventoryItemID then
    local ok, id = pcall(GetInventoryItemID, "player", 0)
    if ok and id then
      local n = ItemCount(id)
      if n then return n end
    end
  end
  local C = C_Container
  if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return nil end
  local total, readBags = 0, false
  for bag = 0, 5 do      -- backpack, four bags, the reagent bag
    local okN, slots = pcall(C.GetContainerNumSlots, bag)
    slots = okN and tonumber(slots) or 0
    if slots > 0 then readBags = true end
    for slot = 1, slots do
      local okS, info = pcall(C.GetContainerItemInfo, bag, slot)
      if okS and type(info) == "table" and info.itemID then
        local classID, subID = ItemClass(info.itemID)
        if classID == 6 and (not kind or subID == kind) then total = total + (tonumber(info.stackCount) or 0) end
      end
    end
  end
  if not readBags then return nil end
  return total
end

local function SpellIdKnown(id)
  for _, fn in ipairs({ IsPlayerSpell, IsSpellKnown, C_SpellBook and C_SpellBook.IsSpellKnown }) do
    if type(fn) == "function" then
      local ok, v = pcall(fn, id)
      if ok and v ~= nil then return v and true or false end
    end
  end
  return nil
end

-- The items a reagent spell can use: the one for your highest rank, or every
-- rank's item when the game won't say which ranks you have.
local function ReagentItems(r)
  if not r.ranks then return { r.item } end
  for _, rank in ipairs(r.ranks) do
    local known = SpellIdKnown(rank[1])
    if known == nil then break end
    if known then return { rank[2] } end
  end
  local all = {}
  for _, rank in ipairs(r.ranks) do all[#all + 1] = rank[2] end
  return all
end

-- Spells your rotation casts (English names), as a set.
local function RotationUses()
  local set = {}
  if ns.RotationSpells then
    local ok, known = pcall(ns.RotationSpells)
    if ok and type(known) == "table" then
      for _, s in ipairs(known) do set[ns.Locale.English(s)] = true end
    end
  end
  return set
end

local function Known(english)
  return ns.IsKnown(ns.Locale.Spell(english))
end

-- What's running low, right now:
-- { key, level = "low"|"out", text (short), chat (a sentence), items = {ids} or ammo = kind }.
function R.SupplyList()
  local out = {}
  local _, class = UnitClass("player")

  if class == "HUNTER" then
    local kind = R.AmmoKind()
    local n = kind and R.AmmoCount(kind)
    if n and n < R.AMMO_LOW then
      local w = AMMO_WORDS[kind]
      if n <= 0 then
        out[#out + 1] = { key = "ammo", level = "out", ammo = kind, text = "no " .. w[2] .. " left",
          chat = ("You're out of %s. A general goods vendor sells them."):format(w[2]) }
      else
        out[#out + 1] = { key = "ammo", level = "low", ammo = kind, text = ("%d %s left"):format(n, w[n == 1 and 1 or 2]),
          chat = ("Low on %s: %d left."):format(w[2], n) }
      end
    end
  end

  if class == "WARLOCK" and Known("Drain Soul") then
    local n = ItemCount(SOUL_SHARD)
    if n and n < R.SHARD_LOW then
      local item = { SOUL_SHARD }
      if n <= 0 then
        out[#out + 1] = { key = "shards", level = "out", items = item, text = "no Soul Shards",
          chat = "You're out of Soul Shards. Drain Soul an enemy as it dies to get one." }
      else
        out[#out + 1] = { key = "shards", level = "low", items = item,
          text = ("%d Soul Shard%s left"):format(n, n == 1 and "" or "s"),
          chat = ("Low on Soul Shards: %d left. Drain Soul an enemy as it dies to get more."):format(n) }
      end
    end
  end

  local uses
  for _, r in ipairs(R.REAGENTS) do
    if Known(r.spell) then
      local wanted = r.always
      if not wanted then
        uses = uses or RotationUses()
        wanted = uses[r.spell]
      end
      if wanted then
        local items, have, readable = ReagentItems(r), 0, false
        for _, id in ipairs(items) do
          local n = ItemCount(id)
          if n then readable = true; have = have + n end
        end
        if readable and have <= 0 then
          local name = ItemName(items[1])
          out[#out + 1] = { key = "reagent:" .. r.spell, level = "out", items = items,
            text = ("no %s (%s)"):format(name, ns.Locale.Spell(r.spell)),
            chat = ("No %s left for %s."):format(name, ns.Locale.Spell(r.spell)) }
        end
      end
    end
  end

  if class == "SHAMAN" then
    for _, t in ipairs(R.TOTEM_TOOLS) do
      local knowsOne = false
      for _, totem in ipairs(t.totems) do
        if Known(totem) then knowsOne = true break end
      end
      if knowsOne and ItemCount(t.item) == 0 then
        local name = ItemName(t.item)
        out[#out + 1] = { key = "totem:" .. t.element, level = "out", items = { t.item }, text = "no " .. name,
          chat = ("No %s in your bags: your %s totems need it."):format(name, t.element) }
      end
    end
  end
  return out
end

-- The list again, kept for a few seconds (the helper popup asks often).
local supplyCache, supplyAt, supplyDirty = nil, -1e9, true
function R.Supplies()
  local now = GetTime()
  if supplyDirty or not supplyCache or now - supplyAt > 10 then
    supplyCache, supplyAt, supplyDirty = R.SupplyList(), now, false
  end
  return supplyCache
end

function R.MarkSupplies() supplyDirty = true end

-- Chat when something runs low or runs out (not every arrow), at most every
-- ten minutes for the same thing.
local lastLevel, saidAt = {}, {}
function R.CheckSupplyChat()
  R.MarkSupplies()
  local list = R.Supplies()
  local now, lines, levels = GetTime(), {}, {}
  for _, s in ipairs(list) do
    levels[s.key] = s.level
    local was = lastLevel[s.key]
    local worse = was == nil or (was == "low" and s.level == "out")
    local id = s.key .. ":" .. s.level
    if worse and (not saidAt[id] or now - saidAt[id] >= SUPPLY_SAME) then
      lines[#lines + 1] = s.chat
      if R.SupplyMode() == "both" then saidAt[id] = now end
    end
  end
  lastLevel = levels
  if R.SupplyMode() ~= "both" or #lines == 0 then return false end
  for _, line in ipairs(lines) do ns.Print(line) end
  return true
end

function R.ResetSupplyChat()
  lastLevel, saidAt = {}, {}
end

local function MerchantItems()
  local out = {}
  if not (GetMerchantNumItems and GetMerchantItemID) then return out end
  local okN, n = pcall(GetMerchantNumItems)
  for i = 1, (okN and tonumber(n) or 0) do
    local okI, id = pcall(GetMerchantItemID, i)
    if okI and id then
      local name
      if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local okM, info = pcall(C_MerchantFrame.GetItemInfo, i)
        if okM and type(info) == "table" then name = info.name end
      end
      if not name and GetMerchantItemInfo then
        local okM, mName = pcall(GetMerchantItemInfo, i)
        if okM then name = mName end
      end
      out[#out + 1] = { id = id, name = type(name) == "string" and name or ItemName(id) }
    end
  end
  return out
end

-- At a vendor: which of the things you're low on it sells.
function R.MerchantLine()
  local list = R.SupplyList()
  if #list == 0 then return nil end
  local names, seen = {}, {}
  for _, m in ipairs(MerchantItems()) do
    for _, s in ipairs(list) do
      local match = false
      if s.ammo then
        local classID, subID = ItemClass(m.id)
        match = classID == 6 and subID == s.ammo
      end
      for _, id in ipairs(s.items or {}) do
        if id == m.id then match = true end
      end
      if match and not seen[m.name] then
        seen[m.name] = true
        names[#names + 1] = m.name
      end
    end
  end
  if #names == 0 then return nil end
  return "This vendor sells what you're low on: " .. JoinNames(names) .. "."
end

-- /tac supplies: what's low now, whatever the setting
function R.ShowSupplies()
  R.MarkSupplies()
  local list = R.Supplies()
  if #list == 0 then
    ns.Print("Supplies: nothing is running low.")
  else
    ns.Print("Supplies: " .. JoinNames(Texts(list)) .. ".")
  end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local f = CreateFrame("Frame")
R.frame = f
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_LEVEL_UP", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED",
  "PLAYER_EQUIPMENT_CHANGED", "SPELLS_CHANGED", "MERCHANT_SHOW" }) do
  pcall(f.RegisterEvent, f, e)
end

-- Bags change a lot (every arrow): look once things settle.
local supplyReady, supplyPending = false, false
local function QueueSupplyCheck()
  R.MarkSupplies()
  if not supplyReady or supplyPending then return end
  supplyPending = true
  C_Timer.After(1, function()
    supplyPending = false
    R.CheckSupplyChat()
  end)
end

function R.HandleEvent(event, ...)
  if event == "PLAYER_LOGIN" then
    C_Timer.After(15, function() R.CheckTrainer(nil, true) end)
    -- your bags and spellbook are read in by then
    C_Timer.After(16, function()
      supplyReady = true
      R.CheckSupplyChat()
    end)
  elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "SPELLS_CHANGED" then
    QueueSupplyCheck()
  elseif event == "MERCHANT_SHOW" then
    if R.SupplyMode() == "both" then
      local line = R.MerchantLine()
      if line then ns.Print(line) end
    end
  elseif event == "PLAYER_LEVEL_UP" then
    local level = ...
    -- give the spellbook a moment to catch up with the new level
    C_Timer.After(3, function() R.CheckTrainer(math.max(tonumber(level) or 0, PlayerLevel() or 0)) end)
  elseif event == "PLAYER_TARGET_CHANGED" then
    if ns.loggedIn then R.ChatPrePull() end
  elseif event == "PLAYER_REGEN_ENABLED" then
    -- give the game a moment to settle (buffs that ran out, a pet that died)
    if ns.loggedIn then C_Timer.After(2, R.AfterFight) end
  end
end

f:SetScript("OnEvent", function(_, event, ...) R.HandleEvent(event, ...) end)
