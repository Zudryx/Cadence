-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: recommended Hunter talent builds for WoW Forever, level 10-60.
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
name: Hunter - Beast Mastery
class: HUNTER
tree: Beast Mastery
source: Warcraft Tavern leveling build (31/20/0), November 2026
notes: Bestial Swiftness at 22, Intimidation at 30 and Bestial Wrath at 40, then Marksmanship for Lethal Attacks and Mortal Shots.
order:
Deadly Aspects 5
Focused Fire 2
Endurance Training 3
Pathfinding 2
Bestial Swiftness
Unleashed Fury 2
Ferocity 5
Intimidation
Bestial Discipline 2
Unleashed Fury 2
Frenzy 5
Bestial Wrath
Lethal Attacks 5
Careful Aim 5
Efficiency 5
Mortal Shots 5
]=])

ns.RegisterTalentBuild([=[
name: Hunter - Marksmanship
class: HUNTER
tree: Marksmanship
source: Warcraft Tavern leveling build (5/46/0), November 2026
notes: Trueshot Aura at 30 and Sniper Shot at 40, then Deadly Aspects from Beast Mastery.
order:
Lethal Attacks 5
Careful Aim 5
Efficiency 5
Mortal Shots 5
Trueshot Aura
Rapid Killing 2
Rapid Recuperation 2
Barrage 3
Ranged Weapon Specialization 2
Sniper Shot
Ranged Weapon Specialization 3
Deadly Aspects 5
Improved Arcane Shot 5
Hawk Eye 3
Improved Stings 3
Lone Wolf
]=])

ns.RegisterTalentBuild([=[
name: Hunter - Survival
class: HUNTER
tree: Survival
source: Warcraft Tavern leveling build (0/18/33), November 2026
notes: Strider Kick at 30 and Lacerating Strikes at 42, then Marksmanship for Lethal Attacks and Careful Aim.
order:
Improved Tracking 5
Savage Strikes 2
Deflection 3
Surefooted 3
Clever Traps 2
Predator's Edge 5
Strider Kick
Resourcefulness 2
Survivalist's Discipline 2
Lightning Reflexes 5
Expose Prey 2
Lacerating Strikes
Lethal Attacks 5
Careful Aim 5
Efficiency 5
Mortal Shots
Trueshot Aura
Lone Wolf
]=])
