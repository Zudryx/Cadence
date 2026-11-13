-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: recommended Mage talent builds for WoW Forever, level 10-60.
--
-- Point-by-point leveling orders from the Warcraft Tavern leveling guides (November 2026),
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
source: Warcraft Tavern leveling build (13/5/33), November 2026
notes: Arcane first for Improved Channeling and Missile Barrage, Frost from 17: Ice Lance at 27, Ice Block at 32, Cold Snap at 39 and Ice Barrier at 47.
order:
Improved Channeling 5
Missile Barrage 2
Improved Frostbolt 5
Precision 2
Frostbite 3
Ice Lance
Ice Shards 4
Ice Block
Shatter 3
Ice Shards
Fingers of Frost 2
Cold Snap
Improved Cone of Cold 2
Winter's Chill 5
Ice Barrier
Precision
Arcane Concentration 5
Improved Cone of Cold
Incineration 5
Arcane Impact
]=])

ns.RegisterTalentBuild([=[
name: Mage - Fire
class: MAGE
tree: Fire
source: Warcraft Tavern leveling build (13/35/3), November 2026
notes: Pyroblast at 23, Heating Up at 28 and Combustion at 43, then Arcane for Arcane Concentration.
order:
Precision 3
Accelerant 5
Ignite 5
Pyroblast
Burning Soul 3
Incineration
Heating Up
Incineration 4
Critical Mass 3
Improved Fire Blast 2
Fire Power 3
Improved Scorch 2
Combustion
Improved Scorch
Improved Channeling 5
Missile Barrage 2
Arcane Concentration 5
Master of Elements 3
Arcane Subtlety
]=])

ns.RegisterTalentBuild([=[
name: Mage - Arcane
class: MAGE
tree: Arcane
source: Warcraft Tavern leveling build (32/16/3), November 2026
notes: Arcane Blast at 20, Presence of Mind at 33 and Arcane Power at 43, then Fire for Incineration and Ignite.
order:
Improved Channeling 5
Missile Barrage 2
Arcane Concentration 3
Arcane Blast
Arcane Concentration 2
Arcane Impact 2
Arcane Wrath
Arcane Meditation 3
Precision 3
Arcane Impact
Presence of Mind
Arcane Mind 5
Arcane Instability 3
Arcane Subtlety
Arcane Power
Arcane Subtlety
Incineration 5
Accelerant 5
Improved Fire Blast
Ignite 5
]=])
