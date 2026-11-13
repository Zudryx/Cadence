-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: recommended Priest talent builds for WoW Forever, level 10-60.
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
name: Priest - Shadow
class: PRIEST
tree: Shadow
source: Icy Veins leveling build (13/3/35), November 2026
notes: Spirit Tap early, Mind Flay at 22, Vampiric Embrace at 27 and Shadowform at 42, then Discipline for Mental Strength and Meditation.
order:
Wand Specialization 2
Spirit Tap 5
Improved Shadow Word: Pain 2
Improved Mind Blast 3
Mind Flay
Improved Mind Flay 2
Improved Mind Blast
Shadow Reach
Vampiric Embrace
Dark Inspiration 5
Devouring Contagion 2
Silence
Shadow Weaving
Darkness 5
Shadowform
Twin Disciplines 3
Mental Strength 5
Meditation 3
Twilight Focus 3
Shadow Weaving 2
Shadow Focus 2
]=])

ns.RegisterTalentBuild([=[
name: Priest - Discipline
class: PRIEST
tree: Discipline
source: Icy Veins leveling build (33/13/5), November 2026
notes: Spirit Tap early, then Discipline: Penance at 38 and Power Infusion at 48, then Holy for Divine Fury.
order:
Wand Specialization 2
Spirit Tap 5
Twilight Focus 3
Power in Light 5
Mental Strength 3
Meditation 3
Mental Strength 2
Improved Power Word: Shield 3
Soul Warding
Mental Agility
Penance
Renewed Hope 4
Divine Aegis
Renewed Hope
Divine Aegis 2
Mental Agility
Power Infusion
Holy Specialization 5
Divine Fury 5
Mental Agility
Inner Focus
]=])

ns.RegisterTalentBuild([=[
name: Priest - Holy
class: PRIEST
tree: Holy
source: Icy Veins leveling build (14/32/5), November 2026
notes: Spirit Tap early, Mental Strength and Meditation from Discipline, Holy Nova at 38, Spirit of Redemption at 48 and Prayer of Mending at 58.
order:
Wand Specialization 2
Spirit Tap 5
Twilight Focus 3
Improved Renew 3
Twin Disciplines 3
Mental Strength 5
Meditation 3
Divine Fury 4
Holy Nova
Inspiration
Divine Fury
Holy Specialization 2
Searing Light 2
Improved Healing 3
Spirit of Redemption
Litany of Light 2
Spiritual Guidance 2
Spiritual Healing 3
Spiritual Guidance 2
Prayer of Mending
Spiritual Guidance
Inner Focus
]=])
