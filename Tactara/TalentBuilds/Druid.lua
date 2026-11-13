-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: recommended Druid talent builds for WoW Forever, level 10-60.
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
name: Druid - Feral
class: DRUID
tree: Feral
source: Warcraft Tavern leveling build (9/37/5), November 2026
notes: For Cat and Bear: Feral Charge at 20, Leader of the Pack at 30, Shifting Power at 40 and Primal Bite at 41.
order:
Ferocity 5
Feral Swiftness 2
Feral Instinct 3
Feral Charge
Savage Fury 2
Sharpened Claws 2
Predatory Discipline
Lacerate
Blood Frenzy 2
Predatory Strikes
Leader of the Pack
Predatory Strikes 2
Natural Instinct 2
Rend and Tear 5
Shifting Power
Primal Bite
Heart of the Wild 5
Genesis 5
Nature's Reach 2
Nature's Majesty 2
Furor 5
]=])

ns.RegisterTalentBuild([=[
name: Druid - Balance
class: DRUID
tree: Balance
source: Warcraft Tavern leveling build (38/0/13), November 2026
notes: Insect Swarm at 25, Eclipse at 30 and Moonkin Form at 40, then Restoration for Nature's Focus.
order:
Improved Wrath 5
Moonglow 3
Nature's Majesty 2
Nature's Reach 2
Improved Moonfire 2
Nature's Splendor
Insect Swarm
Improved Starfire 4
Eclipse 3
Improved Starfire
Nature's Grace
Moonfury 5
Moonkin Form
Nature's Focus 5
Reflection 3
Vengeance 5
Heart of the Wild 5
Genesis 2
]=])

ns.RegisterTalentBuild([=[
name: Druid - Restoration
class: DRUID
tree: Restoration
source: Warcraft Tavern leveling build (13/0/38), November 2026
notes: Swiftmend at 25, Nature's Swiftness at 33 and Wild Growth at 42, then Balance for Genesis and Improved Wrath.
order:
Heart of the Wild 5
Reflection 3
Naturalist 5
Gift of Nature 2
Swiftmend
Gift of Nature 3
Bloom
Living Spirit 3
Nature's Swiftness
Tranquil Spirit 5
Improved Rejuvenation 3
Wild Growth
Genesis 5
Nature's Majesty 2
Improved Wrath 3
Nature's Splendor
Improved Wrath 2
Nature's Focus 5
]=])
