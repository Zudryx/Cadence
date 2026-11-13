-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: recommended Warrior talent builds for WoW Forever, level 10-60.
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
name: Warrior - Arms
class: WARRIOR
tree: Arms
source: Icy Veins leveling build (33/16/2), November 2026
notes: Two-hander. Anger Management at 22, Sweeping Strikes at 30 and Mortal Strike at 40, then Fury for Cruelty and Enrage.
order:
Improved Rend 3
Deflection 2
Improved Overpower 2
Improved Charge 2
Improved Tactical Mastery 3
Anger Management
Deep Wounds 2
Spearing Strike
Two-Handed Weapon Specialization 3
Deep Wounds
Sweeping Strikes
Bloodthrill 2
Weaponmaster 2
Improved Slam 2
Weaponmaster 3
Mortal Strike
Cruelty 5
Lingering Rage 5
Enrage 5
Reckless Swings
Improved Bloodrage 2
Impale 2
]=])

ns.RegisterTalentBuild([=[
name: Warrior - Fury
class: WARRIOR
tree: Fury
source: Icy Veins leveling build (16/33/2), November 2026
notes: Dual wield. Death Wish at 30 and Bloodthirst at 40, then Arms for Deep Wounds and Anger Management.
order:
Cruelty 5
Unbridled Wrath 5
Furious Precision 3
Enrage 2
Dual Wield Specialization 5
Death Wish
Reckless Swings
Improved Berserker Rage 2
Enrage
Improved Whirlwind 2
Flurry 3
Bloodthirst
Improved Rend 3
Deflection 2
Improved Charge 2
Improved Overpower 2
Improved Tactical Mastery 3
Anger Management
Improved Bloodrage 2
Enrage 2
Deep Wounds 3
]=])

ns.RegisterTalentBuild([=[
name: Warrior - Protection
class: WARRIOR
tree: Protection
source: Icy Veins leveling build (4/16/31), November 2026
notes: Shield. Last Stand at 23, Concussion Blow at 33 and Shield Slam at 40, then Fury for Cruelty and Enrage.
order:
Shield Specialization 5
Improved Revenge 3
Improved Thunder Clap 2
Master of Defense 2
Improved Thunder Clap
Last Stand
Defiance
Vanguard
Improved Sunder Armor 3
Defiance
Focused Rage 3
Concussion Blow
Defiance
Bastion 5
Shield Slam
Improved Rend 3
Cruelty 5
Unbridled Wrath 5
Enrage 5
Reckless Swings
Deflection
]=])

-- Level 60 builds: the main raid and dungeon build from each Icy Veins
-- spec page, as the full 51 points (learned top row first). Switching to
-- one at 60 means unlearning your talents at your class trainer first.

ns.RegisterTalentBuild([=[
name: Warrior - Arms (level 60)
class: WARRIOR
tree: Arms
level: 60
source: Icy Veins level 60 build "Mortal Strike Two Handed" (32/17/2), November 2026
notes: Mortal Strike at the bottom of Arms, plus Fury for Cruelty and Unbridled Wrath; Protection for Improved Bloodrage.
order:
Improved Heroic Strike 3
Improved Rend 3
Improved Tactical Mastery 3
Improved Overpower 2
Anger Management
Deep Wounds 3
Spearing Strike
Two-Handed Weapon Specialization 3
Impale 2
Bloodthrill 2
Sweeping Strikes
Weaponmaster 5
Improved Slam 2
Mortal Strike
Cruelty 5
Unbridled Wrath 5
Enrage 5
Reckless Swings
Improved Execute
Improved Bloodrage 2
]=])

ns.RegisterTalentBuild([=[
name: Warrior - Fury (level 60)
class: WARRIOR
tree: Fury
level: 60
source: Icy Veins level 60 build "Bloodthirst Dual Wield" (18/33/0), November 2026
notes: Bloodthirst at the bottom of Fury, plus Arms for Improved Heroic Strike and Improved Rend.
order:
Cruelty 5
Unbridled Wrath 5
Furious Precision 3
Enrage 5
Dual Wield Specialization 5
Reckless Swings
Improved Berserker Rage 2
Death Wish
Improved Whirlwind 2
Flurry 3
Bloodthirst
Improved Heroic Strike 3
Improved Rend 3
Improved Tactical Mastery 3
Improved Overpower 2
Anger Management
Deep Wounds 3
Spearing Strike
Impale 2
]=])

ns.RegisterTalentBuild([=[
name: Warrior - Protection (level 60)
class: WARRIOR
tree: Protection
level: 60
source: Icy Veins level 60 build "Shield Slam Tank" (5/15/31), November 2026
notes: Shield Slam at the bottom of Protection, plus Fury for Cruelty and Lingering Rage; Arms for Deflection.
order:
Shield Specialization 5
Anticipation 5
Improved Revenge 3
Last Stand
Master of Defense 2
Defiance 3
Vanguard
Improved Shield Wall 2
Concussion Blow
Focused Rage 2
Bastion 5
Shield Slam
Deflection 5
Cruelty 5
Lingering Rage 5
Enrage 5
]=])
