-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: recommended Rogue talent builds for WoW Forever, level 10-60.
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
name: Rogue - Combat
class: ROGUE
tree: Combat
source: Warcraft Tavern leveling build (15/36/0), November 2026
notes: Riposte at 22, Blade Flurry at 32 and Adrenaline Rush at 42, then Assassination for Malice and Ruthlessness.
order:
Remorseless Attacks 2
Efficient Strikes 2
Coup de Grace 3
Deflection 3
Precision 2
Riposte
Precision
Endurance 2
Composure
Flawless Execution
Weapon Expertise 2
Aggression 2
Blade Flurry
Dual Wield Specialization 2
Hack and Slash 5
Flash of Steel 2
Adrenaline Rush
Flash of Steel 3
Composure
Aggression
Malice 3
Improved Slice and Dice 3
Malice 2
Lethality 2
Ruthlessness 3
]=])

ns.RegisterTalentBuild([=[
name: Rogue - Assassination
class: ROGUE
tree: Assassination
source: Warcraft Tavern leveling build (36/10/5), November 2026
notes: Daggers for Mutilate. Venom at 30, Mutilate at 40 and Cold Blood at 50, then Subtlety for Opportunity.
order:
Remorseless Attacks 2
Malice 5
Improved Slice and Dice 3
Lethality 2
Ruthlessness 3
Improved Poisons 5
Venom
Relentless Strikes 5
Seal Fate 3
Vile Poisons
Mutilate
Vile Poisons 4
Opportunity 5
Cold Blood
Coup de Grace 3
Lightning Reflexes 2
Puncturing Wounds 3
Precision 2
]=])

ns.RegisterTalentBuild([=[
name: Rogue - Subtlety
class: ROGUE
tree: Subtlety
source: Warcraft Tavern leveling build (13/3/35), November 2026
notes: Bleeds and Hemorrhage: Premeditation at 25, Ghostly Strike at 27, Hemorrhage at 32 and Death Mark at 42, then Assassination for Malice.
order:
Remorseless Attacks 2
Setup 3
Master of Deception 2
Camouflage 3
Dirty Deeds 2
Serrated Blades 3
Premeditation
Initiative
Ghostly Strike
Initiative 2
Dirty Tricks 2
Hemorrhage
Quick Getaway 2
Preparation
Opportunity
Boot Knife 2
Opportunity 3
Death Mark
Opportunity
Master of Deception
Malice 5
Improved Slice and Dice 3
Blood Splatter
Coup de Grace 3
Lethality 2
Elusiveness 2
]=])
