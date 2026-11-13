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

-- Level 60 builds: the main raid and dungeon build from each Icy Veins
-- spec page, as the full 51 points (learned top row first). Switching to
-- one at 60 means unlearning your talents at your class trainer first.

ns.RegisterTalentBuild([=[
name: Priest - Shadow (level 60)
class: PRIEST
tree: Shadow
level: 60
source: Icy Veins level 60 build "Cookie Cutter" (15/3/33), November 2026
notes: Shadowform at the bottom of Shadow, plus Discipline for Twin Disciplines and Mental Strength; Holy for Twilight Focus.
order:
Shadow Focus 5
Improved Mind Blast 4
Improved Shadow Word: Pain 2
Shadow Reach
Mind Flay
Improved Mind Flay 2
Dark Inspiration 5
Vampiric Embrace
Shadow Weaving 3
Silence
Devouring Contagion 2
Darkness 5
Shadowform
Twin Disciplines 5
Silent Resolve 3
Mental Strength 4
Meditation 3
Twilight Focus 3
]=])

ns.RegisterTalentBuild([=[
name: Priest - Discipline (level 60)
class: PRIEST
tree: Discipline
level: 60
source: Icy Veins level 60 build "The Mitigation Machine" (31/20/0), November 2026
notes: Power Infusion at the bottom of Discipline, plus Holy for Holy Specialization and Divine Fury.
order:
Twin Disciplines 5
Mental Strength 5
Mental Agility 3
Inner Focus
Improved Power Word: Shield 3
Meditation 3
Soul Warding
Penance
Renewed Hope 5
Divine Aegis 3
Power Infusion
Twilight Focus 3
Holy Specialization 5
Divine Fury 5
Holy Nova
Inspiration 3
Holy Reach
Searing Light 2
]=])

ns.RegisterTalentBuild([=[
name: Priest - Holy (level 60)
class: PRIEST
tree: Holy
level: 60
source: Icy Veins level 60 build "Full Throttle Group Healer" (17/34/0), November 2026
notes: Prayer of Mending at the bottom of Holy, plus Discipline for Twin Disciplines and Mental Strength.
order:
Improved Renew 3
Holy Specialization 5
Divine Fury 5
Holy Nova
Inspiration 3
Improved Healing 3
Searing Light 2
Litany of Light 2
Spirit of Redemption
Spiritual Guidance 5
Spiritual Healing 3
Prayer of Mending
Twin Disciplines 5
Silent Resolve 3
Mental Strength 5
Inner Focus
Meditation 3
]=])
