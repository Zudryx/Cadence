-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: recommended Rogue talent builds for WoW Forever, level 10-60.
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
name: Rogue - Combat
class: ROGUE
tree: Combat
source: Icy Veins leveling build (16/35/0), November 2026
notes: Riposte at 20, Blade Flurry at 30 and Adrenaline Rush at 40, then Assassination for Malice and Ruthlessness.
order:
Efficient Strikes 2
Coup de Grace 3
Precision 2
Deflection 3
Riposte
Precision
Composure 2
Endurance
Flawless Execution
Weapon Expertise 2
Aggression 2
Blade Flurry
Hack and Slash 4
Flash of Steel 5
Adrenaline Rush
Hack and Slash
Aggression
Dual Wield Specialization 2
Remorseless Attacks 2
Malice 3
Ruthlessness 3
Malice 2
Blood Splatter
Lethality 2
Improved Slice and Dice 2
Cold Blood
]=])

ns.RegisterTalentBuild([=[
name: Rogue - Assassination
class: ROGUE
tree: Assassination
source: Icy Veins leveling build (31/15/5), November 2026
notes: Daggers for Mutilate. Cold Blood at 25, Venom at 30 and Mutilate at 40, then Subtlety for Opportunity.
order:
Remorseless Attacks 2
Malice 3
Ruthlessness 3
Malice 2
Blood Splatter
Lethality 2
Improved Slice and Dice 2
Cold Blood
Vile Poisons 4
Venom
Relentless Strikes 4
Seal Fate 3
Relentless Strikes
Vile Poisons
Mutilate
Opportunity 5
Coup de Grace 3
Lightning Reflexes 2
Precision 3
Puncturing Wounds 3
Composure 2
Endurance 2
]=])

ns.RegisterTalentBuild([=[
name: Rogue - Subtlety
class: ROGUE
tree: Subtlety
source: Icy Veins leveling build (15/5/31), November 2026
notes: Premeditation at 23, Ghostly Strike at 25, Hemorrhage at 30 and Death Mark at 42, then Combat and Assassination.
order:
Opportunity 5
Improved Ambush 3
Setup 2
Serrated Blades 3
Premeditation
Dirty Deeds
Ghostly Strike
Setup
Camouflage 3
Hemorrhage
Efficient Strikes 2
Preparation
Initiative 3
Boot Knife 5
Death Mark
Coup de Grace 3
Remorseless Attacks 2
Malice 3
Ruthlessness 3
Malice 2
Blood Splatter
Lethality 2
Improved Slice and Dice 2
]=])

-- Level 60 builds: the main raid and dungeon build from each Icy Veins
-- spec page, as the full 51 points (learned top row first). Switching to
-- one at 60 means unlearning your talents at your class trainer first.

ns.RegisterTalentBuild([=[
name: Rogue - Combat (level 60)
class: ROGUE
tree: Combat
level: 60
source: Icy Veins level 60 build "Sinister Strike Combat" (16/35/0), November 2026
notes: Adrenaline Rush at the bottom of Combat, plus Assassination for Malice and Ruthlessness.
order:
Coup de Grace 3
Efficient Strikes 2
Lightning Reflexes
Precision 3
Improved Sprint 2
Endurance 2
Composure 2
Flawless Execution
Weapon Expertise 2
Aggression 3
Dual Wield Specialization 2
Blade Flurry
Hack and Slash 5
Flash of Steel 5
Adrenaline Rush
Malice 5
Ruthlessness 3
Improved Expose Armor 2
Improved Slice and Dice 3
Blood Splatter
Lethality
Cold Blood
]=])

ns.RegisterTalentBuild([=[
name: Rogue - Assassination (level 60)
class: ROGUE
tree: Assassination
level: 60
source: Icy Veins level 60 build "Mutilate Assassination" (33/18/0), November 2026
notes: Mutilate at the bottom of Assassination, plus Combat for Coup de Grace and Puncturing Wounds.
order:
Malice 5
Ruthlessness 3
Improved Expose Armor 2
Improved Slice and Dice 3
Blood Splatter
Lethality 2
Vile Poisons 5
Cold Blood
Improved Poisons
Relentless Strikes 5
Venom
Seal Fate 3
Mutilate
Coup de Grace 3
Lightning Reflexes 2
Puncturing Wounds 3
Precision 3
Endurance 2
Composure 2
Flawless Execution
Weapon Expertise 2
]=])

ns.RegisterTalentBuild([=[
name: Rogue - Subtlety (level 60)
class: ROGUE
tree: Subtlety
level: 60
source: Icy Veins level 60 build "Subtlety Bleed" (15/5/31), November 2026
notes: Death Mark at the bottom of Subtlety, plus Assassination for Malice and Ruthlessness; Combat for Coup de Grace and Efficient Strikes.
order:
Setup 3
Opportunity 5
Dirty Deeds 2
Camouflage 2
Improved Ambush 3
Initiative 3
Premeditation
Serrated Blades 3
Ghostly Strike
Preparation
Hemorrhage
Boot Knife 5
Death Mark
Remorseless Attacks 2
Malice 5
Ruthlessness 3
Improved Slice and Dice 2
Blood Splatter
Lethality 2
Coup de Grace 3
Efficient Strikes 2
]=])
