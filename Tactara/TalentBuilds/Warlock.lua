-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: recommended Warlock talent builds for WoW Forever, level 10-60.
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
name: Warlock - Affliction
class: WARLOCK
tree: Affliction
source: Warcraft Tavern leveling build (41/7/3), November 2026
notes: Amplify Curse at 30, Siphon Life at 41 and Wrack at 50.
order:
Improved Life Tap 2
Suppression 5
Improved Corruption 5
Improved Drains 3
Improved Bane of Agony 2
Fel Concentration 3
Amplify Curse
Pandemic 3
Malevolence 5
Nightfall 2
Siphon Life
Soul Siphon 3
Shadow Mastery 5
Wrack
Unholy Power 5
Demonic Energies 2
Improved Shadow Bolt 3
]=])

ns.RegisterTalentBuild([=[
name: Warlock - Demonology
class: WARLOCK
tree: Demonology
source: Warcraft Tavern leveling build (20/31/0), November 2026
notes: Affliction first, Demonology from 30: Demonic Sacrifice at 44, Soul Link at 51 and Demonic Pact at 60.
order:
Improved Life Tap 2
Suppression 5
Improved Corruption 5
Improved Drains 3
Pandemic 3
Malevolence 2
Demonic Embrace
Unholy Power 5
Fel Vitality 3
Demonic Energies 2
Improved Sayaad 3
Demonic Sacrifice
Master Summoner 2
Fel Domination
Demonic Brand 3
Soul Link
Demonic Knowledge 3
Master Demonologist 5
Demonic Pact
]=])

ns.RegisterTalentBuild([=[
name: Warlock - Destruction
class: WARLOCK
tree: Destruction
source: Warcraft Tavern leveling build (17/3/31), November 2026
notes: Affliction first, Destruction from 30: Shadowburn at 46 and Conflagrate at 50.
order:
Improved Life Tap 2
Suppression 5
Improved Corruption 5
Amplify Curse
Pandemic 3
Malevolence
Improved Imp 3
Bane 5
Cataclysm 3
Aftermath 5
Ruin 3
Shadowburn
Agonizing Flames 3
Conflagrate
Bane of Havoc
Fire and Brimstone 3
Shadow and Flame 5
Incinerate
]=])
