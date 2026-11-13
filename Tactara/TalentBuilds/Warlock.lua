-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: recommended Warlock talent builds for WoW Forever, level 10-60.
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
name: Warlock - Affliction
class: WARLOCK
tree: Affliction
source: Icy Veins leveling build (40/11/0), November 2026
notes: Siphon Life at 30, Demonic Sacrifice at 41 and Wrack at 51.
order:
Suppression 4
Improved Corruption 5
Grim Reach
Improved Bane of Agony 2
Pandemic 3
Nightfall 2
Malevolence 3
Siphon Life
Demonic Embrace 5
Demonic Aegis 2
Fel Vitality 3
Demonic Sacrifice
Malevolence 2
Grim Reach
Improved Life Tap
Shadow Mastery 5
Wrack
Improved Life Tap
Soul Siphon 3
Improved Drains 3
Fel Concentration 2
]=])

ns.RegisterTalentBuild([=[
name: Warlock - Demonology
class: WARLOCK
tree: Demonology
source: Icy Veins leveling build (20/31/0), November 2026
notes: Fel Domination at 28, Soul Link at 30 and Demonic Pact at 40, then Affliction for Improved Corruption and Malevolence.
order:
Unholy Power 5
Demonic Energies 2
Fel Vitality 3
Master Summoner 2
Improved Voidwalker 3
Demonic Brand 3
Fel Domination
Demonic Sacrifice
Soul Link
Demonic Knowledge 3
Demonic Aegis
Master Demonologist 5
Demonic Pact
Suppression 4
Improved Corruption 5
Improved Life Tap
Improved Bane of Agony 2
Pandemic 3
Malevolence 5
]=])

ns.RegisterTalentBuild([=[
name: Warlock - Destruction
class: WARLOCK
tree: Destruction
source: Icy Veins leveling build (6/11/34), November 2026
notes: Shadowburn at 20, Conflagrate at 25 and Incinerate at 40, then Demonology for Demonic Embrace.
order:
Bane 5
Aftermath 5
Shadowburn
Destructive Reach 2
Ruin 2
Conflagrate
Intensity 3
Agonizing Flames
Fire and Brimstone 3
Bane of Havoc
Agonizing Flames
Shadow and Flame 5
Incinerate
Agonizing Flames
Suppression 4
Demonic Embrace 5
Demonic Aegis 2
Fel Vitality 3
Demonic Sacrifice
Improved Life Tap 2
Ruin 2
]=])
