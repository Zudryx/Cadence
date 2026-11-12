-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: recommended Warrior talent builds for WoW Forever, level 10-60.
--
-- Point-by-point leveling orders from the Method (Arms) and Maxroll (Fury,
-- Protection) leveling builds, checked November 2026 against the talent
-- trees in the game (game build 70888): every row and arrow requirement is
-- met at the level each point is taken.
--
-- Open /tac talents to see them on the trees, use one, or copy one and make
-- it your own. Each line after "order:" is a talent and how many points go
-- into it at that spot.

local ADDON, ns = ...

ns.RegisterTalentBuild([=[
name: Warrior - Arms
class: WARRIOR
tree: Arms
source: Method leveling build (34/15/2), November 2026
notes: Two-hander. Sweeping Strikes at 30 and Mortal Strike at 40, then Fury for Cruelty and Enrage.
order:
Improved Rend 3
Deflection 2
Improved Overpower 2
Improved Tactical Mastery 3
Anger Management
Deep Wounds 3
Improved Charge
Two-Handed Weapon Specialization 3
Spearing Strike
Improved Charge
Sweeping Strikes
Bloodthrill 2
Weaponmaster 2
Improved Slam 2
Weaponmaster 3
Mortal Strike
Cruelty 5
Lingering Rage 5
Enrage 5
Deflection 3
Improved Bloodrage 2
]=])

ns.RegisterTalentBuild([=[
name: Warrior - Fury
class: WARRIOR
tree: Fury
source: Maxroll leveling build (19/32/0), November 2026
notes: Dual wield. Blood Craze and Gore Drinker heal you, Bloodthirst at 40, then Arms for Deep Wounds and Impale.
order:
Cruelty 5
Unbridled Wrath 5
Blood Craze 3
Enrage 2
Dual Wield Specialization 5
Gore Drinker 2
Death Wish
Enrage 2
Flurry 3
Improved Whirlwind 2
Bloodthirst
Improved Rend 3
Deflection 2
Improved Tactical Mastery 3
Improved Overpower 2
Anger Management
Deep Wounds 3
Enrage
Deflection
Impale 2
Deflection 2
]=])

ns.RegisterTalentBuild([=[
name: Warrior - Protection
class: WARRIOR
tree: Protection
source: Maxroll leveling build (10/10/31), November 2026
notes: One-hander and shield. Master of Defense at 20 and Shield Slam at 40, then Arms and Fury for damage.
order:
Shield Specialization 5
Improved Revenge 3
Improved Thunder Clap 2
Master of Defense 2
Improved Thunder Clap
Last Stand
Improved Bloodrage
Vanguard
Improved Bloodrage
Anticipation 3
Concussion Blow
Focused Rage 3
Anticipation
Bastion 5
Shield Slam
Improved Rend 3
Deflection 5
Cruelty 5
Improved Charge 2
Unbridled Wrath 5
]=])
