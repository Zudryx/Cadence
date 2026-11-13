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

-- Level 60 builds: the main raid and dungeon build from each Icy Veins
-- spec page, as the full 51 points (learned top row first). Switching to
-- one at 60 means unlearning your talents at your class trainer first.

ns.RegisterTalentBuild([=[
name: Druid - Feral Cat (level 60)
class: DRUID
tree: Feral
level: 60
source: Icy Veins level 60 build "Cat DPS" (8/33/10), November 2026
notes: Shifting Power at the bottom of Feral, plus Restoration for Heart of the Wild and Naturalist; Balance for Genesis and Nature's Majesty.
order:
Ferocity 5
Furor 3
Feral Swiftness 2
Shredding Attacks 3
Savage Fury 2
Feral Charge
Sharpened Claws 2
Predatory Strikes 3
Predatory Discipline
Blood Frenzy 2
Leader of the Pack
Natural Instinct 2
Rend and Tear 5
Shifting Power
Genesis 5
Nature's Majesty 2
Nature's Reach
Heart of the Wild 5
Naturalist 5
]=])

ns.RegisterTalentBuild([=[
name: Druid - Feral Bear (level 60)
class: DRUID
tree: Feral
level: 60
source: Icy Veins level 60 build "Bear Tank Only" (9/32/10), November 2026
notes: Primal Bite at the bottom of Feral, plus Restoration for Heart of the Wild and Naturalist; Balance for Genesis and Nature's Majesty.
order:
Ferocity 5
Feral Swiftness 2
Feral Instinct 3
Thick Hide 3
Savage Fury 2
Feral Charge
Sharpened Claws 2
Predatory Strikes 3
Lacerate
Blood Frenzy
Leader of the Pack
Natural Instinct 2
Rend and Tear 5
Primal Bite
Genesis 5
Nature's Majesty 2
Nature's Reach 2
Heart of the Wild 5
Naturalist 5
]=])

ns.RegisterTalentBuild([=[
name: Druid - Balance (level 60)
class: DRUID
tree: Balance
level: 60
source: Icy Veins level 60 build "Balance Default - Eclipse & DoTs" (41/0/10), November 2026
notes: Moonkin Form at the bottom of Balance, plus Restoration for Nature's Focus and Naturalist.
order:
Improved Wrath 5
Genesis 5
Moonglow 3
Improved Moonfire 2
Nature's Majesty 2
Nature's Reach 2
Nature's Splendor
Insect Swarm
Vengeance 5
Improved Starfire 5
Nature's Grace
Eclipse 3
Moonfury 5
Moonkin Form
Nature's Focus 5
Naturalist 5
]=])

ns.RegisterTalentBuild([=[
name: Druid - Restoration (level 60)
class: DRUID
tree: Restoration
level: 60
source: Icy Veins level 60 build "Restoration Default" (18/0/33), November 2026
notes: Wild Growth at the bottom of Restoration, plus Balance for Improved Wrath and Genesis.
order:
Heart of the Wild 5
Naturalist 5
Reflection 3
Gift of Nature 5
Bloom
Improved Rejuvenation 3
Swiftmend
Nature's Swiftness
Living Spirit 3
Improved Regrowth 5
Wild Growth
Improved Wrath 5
Genesis 5
Moonglow 2
Nature's Majesty 2
Nature's Reach 2
Nature's Splendor
Insect Swarm
]=])
