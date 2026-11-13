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
--     there. Shown under the helper popup, and in chat now and then.

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

-- true = something to remind about, false = all good, nil = can't tell.
local function WeaponNeedsCoat(spells)
  if #spells == 0 or not GetWeaponEnchantInfo then return false end
  -- some clients put poisons on you as a buff instead of on the weapon
  if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
    for _, s in ipairs(spells) do
      local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", s, "HELPFUL")
      if ok and aura ~= nil then return false end
    end
  end
  local ok, mh, _, _, _, oh = pcall(GetWeaponEnchantInfo)
  if not ok then return nil end
  local okB, need = pcall(function()
    if WeaponIn(16) and not mh then return true end
    if WeaponIn(17) and not oh then return true end
    return false
  end)
  if not okB then return nil end
  return need
end

-- What's missing before the pull: a list of { spell = icon spell, text = short label, kind }.
-- Pet first, then buffs from the rotation's [priority] list (@missing / @nopet
-- lines only, no totems), then poisons or weapon imbues.
function R.PrePullList(comp)
  comp = comp or (ns.HelperComp and ns.HelperComp())
  local out, seen = {}, {}
  if not comp then return out end
  local pets, buffs = {}, {}
  for _, e in ipairs(comp.priority or {}) do
    local prep = #e.live > 0 and not ns.Locale.English(e.spell):find("Totem$")
    local pet = false
    for _, c in ipairs(e.live) do
      if not PREP_KINDS[c.kind] then prep = false end
      if c.kind == "nopet" then pet = true end
    end
    if prep and not seen[e.spell] and ns.LiveOK(e) and not OnCooldown(e.spell)
      and not (CostsRage(e.spell) and ns.UsableState(e.spell) ~= "yes") then
      seen[e.spell] = true
      if pet then
        if #pets == 0 then pets[1] = { spell = e.spell, text = "your pet", kind = "pet" } end
      else
        buffs[#buffs + 1] = { spell = e.spell, text = e.spell, kind = "buff" }
      end
    end
  end
  for _, x in ipairs(pets) do out[#out + 1] = x end
  for _, x in ipairs(buffs) do out[#out + 1] = x end

  local _, class = UnitClass("player")
  if class == "ROGUE" then
    local known = KnownOf(POISONS)
    if WeaponNeedsCoat(known) then out[#out + 1] = { spell = known[1], text = "a poison on your weapons", kind = "weapon" } end
  elseif class == "SHAMAN" then
    local known = KnownOf(IMBUES)
    if WeaponNeedsCoat(known) then out[#out + 1] = { spell = known[1], text = "a weapon imbue", kind = "weapon" } end
  end
  return out
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

-- The line under the helper popup, or nil when there's nothing to say.
function R.PrePullText()
  if Mode() == "off" or InCombat() or not HostileTarget() then return nil end
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return nil end
  local list = R.PrePullList()
  if #list == 0 then return nil end
  return "|cffff9933Before the pull:|r " .. JoinNames(Texts(list))
end

local lastChat, lastChatKey = -1e9, nil
-- A chat line when you pick an enemy and something's missing: at most once a
-- minute, and the same reminder at most every five minutes.
function R.ChatPrePull()
  if Mode() ~= "both" or InCombat() or not HostileTarget() then return false end
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false end
  -- riding past enemies isn't a pull; the line under the helper still shows
  if (IsMounted and IsMounted()) or (UnitOnTaxi and UnitOnTaxi("player")) then return false end
  local list = R.PrePullList()
  if #list == 0 then return false end
  local texts = Texts(list)
  local key = table.concat(texts, "|")
  local now = GetTime()
  if (key ~= lastChatKey and now - lastChat >= CHAT_GAP) or now - lastChat >= CHAT_SAME then
    lastChat, lastChatKey = now, key
    ns.Print("Before you pull: " .. JoinNames(texts) .. ".")
    return true
  end
  return false
end

function R.ResetChatThrottle()
  lastChat, lastChatKey = -1e9, nil
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local f = CreateFrame("Frame")
R.frame = f
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_LEVEL_UP", "PLAYER_TARGET_CHANGED" }) do
  pcall(f.RegisterEvent, f, e)
end

function R.HandleEvent(event, ...)
  if event == "PLAYER_LOGIN" then
    C_Timer.After(15, function() R.CheckTrainer(nil, true) end)
  elseif event == "PLAYER_LEVEL_UP" then
    local level = ...
    -- give the spellbook a moment to catch up with the new level
    C_Timer.After(3, function() R.CheckTrainer(math.max(tonumber(level) or 0, PlayerLevel() or 0)) end)
  elseif event == "PLAYER_TARGET_CHANGED" then
    if ns.loggedIn then R.ChatPrePull() end
  end
end

f:SetScript("OnEvent", function(_, event, ...) R.HandleEvent(event, ...) end)
