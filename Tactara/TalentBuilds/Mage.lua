-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: recommended Mage talent builds for WoW Forever, level 10-60.
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
name: Mage - Frost
class: MAGE
tree: Frost
source: Icy Veins leveling build (7/0/44), November 2026
notes: Ice Lance at 20, Ice Block at 29, Cold Snap at 32 and Ice Barrier at 40.
order:
Precision 2
Improved Frostbolt 3
Frostbite 3
Improved Frostbolt 2
Ice Lance
Ice Shards 4
Shatter 3
Ice Shards
Ice Block
Fingers of Frost 2
Cold Snap
Improved Cone of Cold 3
Frost Channeling 3
Improved Blizzard
Ice Barrier
Precision
Winter's Chill 5
Arctic Reach 2
Permafrost 2
Improved Blizzard 2
Frost Warding
Arcane Resilience 3
Wand Specialization 2
Arcane Subtlety 2
]=])

ns.RegisterTalentBuild([=[
name: Mage - Fire
class: MAGE
tree: Fire
source: Icy Veins leveling build (18/31/2), November 2026
notes: Arcane first for Arcane Concentration and Arcane Blast, Fire from 30: Pyroblast at 44, Blast Wave at 50 and Combustion at 60.
order:
Wand Specialization 2
Improved Channeling 3
Missile Barrage 2
Arcane Concentration 3
Arcane Blast
Precision 2
Improved Channeling 2
Arcane Concentration 2
Arcane Meditation 3
Incineration 5
Accelerant 5
Improved Fire Blast 2
Ignite 2
Pyroblast
Heating Up
Ignite 3
Improved Scorch
Blast Wave
Critical Mass 3
Improved Scorch
Fire Power 3
Improved Scorch
Master of Elements
Combustion
]=])

ns.RegisterTalentBuild([=[
name: Mage - Arcane
class: MAGE
tree: Arcane
source: Icy Veins leveling build (31/17/3), November 2026
notes: Arcane Blast at 20, Presence of Mind at 32 and Arcane Power at 42, then Fire for Incineration and Ignite.
order:
Wand Specialization 2
Improved Channeling 3
Missile Barrage 2
Arcane Concentration 3
Arcane Blast
Precision 2
Improved Channeling 2
Arcane Concentration 2
Arcane Wrath
Arcane Meditation 3
Arcane Subtlety
Presence of Mind
Arcane Mind 5
Arcane Instability 3
Arcane Subtlety
Arcane Power
Incineration 5
Accelerant 5
Improved Fire Blast 2
Ignite 2
Pyroblast
Heating Up
Ignite
Precision
]=])
