-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: recommended Druid talent builds for WoW Forever, level 10-60.
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
name: Druid - Feral
class: DRUID
tree: Feral
source: Icy Veins leveling build (9/32/10), November 2026
notes: For Cat and Bear: Feral Charge at 20, Leader of the Pack at 30, Primal Bite at 40 and Shifting Power at 41, then Restoration for Heart of the Wild.
order:
Ferocity 5
Feral Instinct 3
Feral Swiftness 2
Feral Charge
Savage Fury 2
Sharpened Claws 2
Lacerate
Blood Frenzy 2
Predatory Discipline
Predatory Strikes
Leader of the Pack
Natural Instinct 2
Predatory Strikes 2
Rend and Tear 5
Primal Bite
Shifting Power
Heart of the Wild 5
Naturalist 5
Genesis 5
Nature's Reach 2
Nature's Majesty 2
]=])

ns.RegisterTalentBuild([=[
name: Druid - Balance
class: DRUID
tree: Balance
source: Icy Veins leveling build (38/0/13), November 2026
notes: Insect Swarm at 33, Nature's Grace at 38 and Moonkin Form at 53, with Restoration for Nature's Focus and Naturalist.
order:
Improved Wrath 5
Nature's Focus 5
Reflection 3
Nature's Reach 2
Nature's Majesty 2
Moonglow
Nature's Splendor
Moonglow 2
Improved Moonfire 2
Insect Swarm
Genesis 4
Nature's Grace
Genesis
Naturalist 5
Eclipse 3
Moonfury 5
Moonkin Form
Improved Starfire 5
Vengeance 2
]=])

ns.RegisterTalentBuild([=[
name: Druid - Restoration
class: DRUID
tree: Restoration
source: Icy Veins leveling build (18/0/33), November 2026
notes: Balance first for Improved Wrath, Restoration from 15: Swiftmend at 41, Nature's Swiftness at 46 and Wild Growth at 58.
order:
Improved Wrath 5
Nature's Focus 5
Reflection 3
Nature's Reach 2
Nature's Majesty 2
Moonglow
Nature's Splendor
Moonglow 2
Genesis 2
Insect Swarm
Naturalist 2
Bloom
Naturalist 3
Gift of Nature
Swiftmend
Gift of Nature 4
Nature's Swiftness
Living Spirit 3
Improved Rejuvenation 3
Improved Regrowth 5
Wild Growth
Genesis 2
]=])
