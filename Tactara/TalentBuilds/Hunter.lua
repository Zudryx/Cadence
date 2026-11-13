-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: recommended Hunter talent builds for WoW Forever, level 10-60.
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
name: Hunter - Beast Mastery
class: HUNTER
tree: Beast Mastery
source: Icy Veins leveling build (32/14/5), November 2026
notes: Bestial Swiftness at 22, Intimidation at 36 and Bestial Wrath at 40, then Marksmanship for Lethal Attacks and Careful Aim.
order:
Deadly Aspects 5
Focused Fire 2
Improved Revive Pet 2
Endurance Training
Pathfinding 2
Bestial Swiftness
Unleashed Fury 2
Summon Hawk
Unleashed Fury 3
Ferocity
Bestial Discipline 2
Ferocity 4
Intimidation
Frenzy 3
Bestial Wrath
Frenzy
Lethal Attacks 5
Careful Aim 5
Rapid Killing 2
Improved Tracking 5
Improved Stings 2
]=])

ns.RegisterTalentBuild([=[
name: Hunter - Marksmanship
class: HUNTER
tree: Marksmanship
source: Icy Veins leveling build (19/32/0), November 2026
notes: Trueshot Aura at 25 and Sniper Shot at 40, then Beast Mastery for Deadly Aspects.
order:
Lethal Attacks 5
Careful Aim 5
Rapid Killing 2
Improved Stings 3
Trueshot Aura
Mortal Shots 4
Rapid Recuperation 2
Mortal Shots
Barrage 2
Ranged Weapon Specialization 5
Sniper Shot
Deadly Aspects 5
Focused Fire 2
Improved Revive Pet 2
Endurance Training
Pathfinding 2
Bestial Swiftness
Barrage
Unleashed Fury 2
Summon Hawk
Unleashed Fury 3
]=])

ns.RegisterTalentBuild([=[
name: Hunter - Survival
class: HUNTER
tree: Survival
source: Icy Veins leveling build (0/17/34), November 2026
notes: Lethal Attacks first, Survival from 15: Strider Kick at 35 and Lacerating Strikes at 45, then Marksmanship for Careful Aim.
order:
Lethal Attacks 5
Improved Tracking 5
Savage Strikes 2
Survivalist 3
Surefooted 3
Clever Traps 2
Predator's Edge 5
Strider Kick
Expose Prey 2
Survivalist's Discipline 2
Lightning Reflexes 5
Lacerating Strikes
Resourcefulness
Survival Tactics 2
Careful Aim 5
Lone Wolf
Improved Stings 3
Efficiency
Mortal Shots 2
]=])
