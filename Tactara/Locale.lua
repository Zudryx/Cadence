-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: game clients in other languages.
--
-- Rotations and talent builds are written with English spell names. On a
-- German, French, Spanish, ... client the game only knows its own names, so
-- Tactara looks up each English name's spell ID (SpellIDs.lua) and asks the
-- game what that spell is called in your language. On an English client
-- nothing here changes anything.
--
-- Tactara's own windows and messages stay in English.

local ADDON, ns = ...

local L = {}
ns.Locale = L

local function ClientLocale()
  if GetLocale then
    local ok, loc = pcall(GetLocale)
    if ok and type(loc) == "string" then return loc end
  end
  return "enUS"
end

L.locale = ClientLocale()
L.english = (L.locale == "enUS" or L.locale == "enGB")

-- Translating only happens on other languages (tests can turn it on).
function L.Active() return L.force or not L.english end

local cache, reverse = {}, {}

local function ClassToken()
  return ns.GetClassToken and ns.GetClassToken() or nil
end

-- The spell ID for an English spell or talent name: your class's spells,
-- then its talents, then any class (racials and the like).
function L.IdFor(name, class)
  if type(name) ~= "string" then return nil end
  class = class or ClassToken()
  local s = class and ns.SPELL_IDS and ns.SPELL_IDS[class]
  if s and s[name] then return s[name] end
  local t = class and ns.TALENT_IDS and ns.TALENT_IDS[class]
  if t and t[name] then return t[name] end
  for _, tbl in pairs(ns.SPELL_IDS or {}) do
    if tbl[name] then return tbl[name] end
  end
  return nil
end

-- The talent's spell ID (exactly as the game's talent tree has it).
function L.TalentId(name, class)
  class = class or ClassToken()
  local t = class and ns.TALENT_IDS and ns.TALENT_IDS[class]
  return t and t[name] or nil
end

function L.NameOf(id)
  if not id then return nil end
  if C_Spell and C_Spell.GetSpellName then
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok and type(n) == "string" and n ~= "" then return n end
  end
  if GetSpellInfo then
    local ok, n = pcall(GetSpellInfo, id)
    if ok and type(n) == "string" and n ~= "" then return n end
  end
  return nil
end

-- English name -> the name in your game's language (the English name when
-- it's an English game or the spell isn't known to Tactara).
function L.Spell(name)
  if not L.Active() or type(name) ~= "string" or name == "" then return name end
  local class = ClassToken() or "?"
  local key = class .. ":" .. name
  local hit = cache[key]
  if hit then return hit end
  local local_ = L.NameOf(L.IdFor(name, class))
  if local_ then
    cache[key] = local_     -- a miss isn't kept: the game may know it later
    reverse[local_] = reverse[local_] or name
    return local_
  end
  return name
end

-- The other way: a name from the game -> the English name Tactara's tables use.
function L.English(name)
  if not L.Active() or type(name) ~= "string" then return name end
  if reverse[name] then return reverse[name] end
  local class = ClassToken()
  for _, tbl in ipairs({ class and ns.SPELL_IDS and ns.SPELL_IDS[class], class and ns.TALENT_IDS and ns.TALENT_IDS[class] }) do
    for english, id in pairs(tbl or {}) do
      local n = L.NameOf(id)
      if n then reverse[n] = reverse[n] or english end
    end
  end
  return reverse[name] or name
end

-- Creature types for @creature (the game names them in your language).
L.CREATURE_IDS = {
  Beast = 1, Dragonkin = 2, Demon = 3, Elemental = 4, Giant = 5, Undead = 6, Humanoid = 7,
  Critter = 8, Mechanical = 9, ["Not specified"] = 10, Totem = 11, ["Non-combat Pet"] = 12,
  ["Gas Cloud"] = 13, ["Wild Pet"] = 14, Aberration = 15,
}

function L.Creature(name)
  if not L.Active() or type(name) ~= "string" then return name end
  local id = L.CREATURE_IDS[name]
  if id and C_CreatureInfo and C_CreatureInfo.GetCreatureTypeInfo then
    local ok, info = pcall(C_CreatureInfo.GetCreatureTypeInfo, id)
    if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then return info.name end
  end
  return name
end

local function Trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- One /cast line: each spell after its [conditions] (and an optional "!")
-- in your language. Anything that isn't /cast is left as it is.
function L.Command(cmd)
  if not L.Active() or type(cmd) ~= "string" then return cmd end
  local verb, args = cmd:match("^/(%a+)%s*(.*)$")
  if not verb or verb:lower() ~= "cast" then return cmd end
  local clauses = {}
  for clause in (args .. ";"):gmatch("([^;]*);") do
    local i, prefix = 1, ""
    while true do
      local s, e = clause:find("^%s*%b[]", i)
      if not s then break end
      prefix = prefix .. clause:sub(i, e)
      i = e + 1
    end
    local rest = clause:sub(i)
    local lead, bang, name = rest:match("^(%s*)(!?)(.-)%s*$")
    name = Trim(name or "")
    clauses[#clauses + 1] = prefix .. (lead or "") .. (bang or "") .. (name ~= "" and L.Spell(name) or "")
  end
  return "/" .. verb .. " " .. table.concat(clauses, ";")
end

-- Hooks the parser calls (it has no WoW calls of its own).
ns.LocalizeCommand = L.Command
ns.LocalizeSpell = L.Spell
ns.LocalizeCreature = L.Creature
