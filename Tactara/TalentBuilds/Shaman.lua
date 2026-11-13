-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: recommended Shaman talent builds for WoW Forever, level 10-60.
--
-- Point-by-point leveling orders from the Icy Veins leveling guides (November 2026),
-- checked against the talent trees in the game (game build 70888): every
-- row and arrow requirement is met at the level each point is taken.
--
-- Open /tac talents to see them on the trees, use one, or copy one and make
-- it your own. Each line after "order:" is a talent and how many points go
-- into it at that spot.

local ADDON, ns = ...

ns.RegisterTalentBuild([=[
name: Shaman - Enhancement
class: SHAMAN
tree: Enhancement
source: Icy Veins leveling build (9/34/8), November 2026
notes: Stormstrike at 25, Maelstrom Weapon from 46 and Rage of the Farseer at 51, with Restoration for Tidal Focus and Mindfulness.
order:
Thundering Strikes 5
Mental Dexterity 3
Ancestral Knowledge 2
Shamanistic Focus
Elemental Weapons 3
Ancestral Knowledge
Stormstrike
Improved Ghost Wolf 2
Flurry 2
Improved Stormstrike 2
Mental Quickness 2
Spirit Weapons
Tidal Focus 5
Mindfulness 3
Flurry 3
Maelstrom Weapon 5
Rage of the Farseer
Concussion 5
Elemental Devastation 3
Call of Flame
]=])

ns.RegisterTalentBuild([=[
name: Shaman - Elemental
class: SHAMAN
tree: Elemental
source: Icy Veins leveling build (33/7/11), November 2026
notes: Elemental Focus at 20, Call of Thunder at 30 and Lightning Mastery at 40, then Restoration for Tidal Focus and Mindfulness.
order:
Concussion 5
Elemental Alacrity 3
Call of Flame 2
Elemental Focus
Call of Flame
Convection 3
Earthbound
Trial by Fire 2
Eye of the Storm 2
Call of Thunder
Lightning Overload 3
Eye of the Storm
Elemental Fury 5
Lightning Mastery
Tidal Focus 5
Mindfulness 3
Improved Reincarnation 2
Water Shield
Thundering Strikes 5
Convection 2
Ancestral Knowledge 2
]=])

ns.RegisterTalentBuild([=[
name: Shaman - Restoration
class: SHAMAN
tree: Restoration
source: Icy Veins leveling build (0/10/41), November 2026
notes: Water Shield at 20, Mana Tide Totem at 25, Nature's Swiftness at 30 and Riptide at 40, then Enhancement for Thundering Strikes.
order:
Tidal Focus 5
Mindfulness 3
Improved Healing Wave 2
Water Shield
Improved Healing Wave 3
Healing Focus
Mana Tide Totem
Tidal Mastery 4
Nature's Swiftness
Healing Way 3
Tidal Mastery
Purification 5
Riptide
Healing Focus 2
Ancestral Healing 3
Thundering Strikes 5
Restorative Totems 5
Ancestral Knowledge 5
]=])
