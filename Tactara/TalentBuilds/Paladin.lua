-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: recommended Paladin talent builds for WoW Forever, level 10-60.
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
name: Paladin - Retribution
class: PALADIN
tree: Retribution
source: Icy Veins leveling build (18/0/33), November 2026
notes: Two-hander. Seal of Command at 22, Repentance at 33 and Unsealed Wrath at 40, then Holy for Divine Strength and Improved Seals.
order:
Deflection 5
Improved Judgement 2
Conviction 3
Pursuit of Justice 2
Seal of Command
Sanctified Judgement 2
Sacred Arbiter
Two-Handed Weapon Specialization 3
Sanctified Judgement
Vengeance 3
Repentance
Vindication
Champion of the Light 5
Unsealed Wrath
Divine Strength 5
Reverence 2
Improved Seals 3
Holy Conduit 2
Improved Seals 2
Purifying Power 2
Divine Precision 2
Vindication 2
]=])

ns.RegisterTalentBuild([=[
name: Paladin - Protection
class: PALADIN
tree: Protection
source: Icy Veins leveling build (0/35/16), November 2026
notes: Shield. Retribution first for Benediction and Pursuit of Justice, Protection from 22: Templar's Bulwark at 34, Holy Shield at 42 and Shieldsworn at 52.
order:
Benediction 5
Conviction 3
Improved Judgement 2
Pursuit of Justice 2
Redoubt 5
Precision 3
Sacred Duty 2
Shield Specialization 2
Templar's Bulwark
Toughness 2
Swift Judgement
Improved Righteous Fury 3
Anticipation
Holy Shield
Reckoning 5
Iron Creed 3
Anticipation
Shieldsworn
Anticipation 3
Sanctified Judgement 3
Sacred Arbiter
Toughness
]=])

ns.RegisterTalentBuild([=[
name: Paladin - Holy
class: PALADIN
tree: Holy
source: Icy Veins leveling build (34/5/12), November 2026
notes: Retribution first for Benediction and Pursuit of Justice, Holy from 22: Holy Shock at 42 and Light's Vigil at 52.
order:
Benediction 5
Conviction 3
Improved Judgement 2
Pursuit of Justice 2
Spiritual Focus 5
Reverence 2
Healing Light 3
Illumination 5
Oath of Light
Infusion of Light 2
Holy Conduit 2
Holy Shock
Boundless Light 2
Divine Favor
Consecrated Ground
Holy Power 5
Light's Vigil
Divine Intellect 5
Consecrated Ground
Improved Seals 2
]=])

-- Level 60 builds: the main raid and dungeon build from each Icy Veins
-- spec page, as the full 51 points (learned top row first). Switching to
-- one at 60 means unlearning your talents at your class trainer first.

ns.RegisterTalentBuild([=[
name: Paladin - Retribution (level 60)
class: PALADIN
tree: Retribution
level: 60
source: Icy Veins level 60 build "Unsealed Wrath" (12/8/31), November 2026
notes: Unsealed Wrath at the bottom of Retribution, plus Holy for Divine Strength and Improved Seals; Protection for Divine Intellect and Precision.
order:
Benediction 5
Improved Judgement 2
Conviction 3
Sanctified Judgement 3
Unyielding Faith
Seal of Command
Pursuit of Justice 2
Sacred Arbiter
Two-Handed Weapon Specialization 3
Repentance
Vengeance 3
Champion of the Light 5
Unsealed Wrath
Divine Strength 5
Improved Seals 5
Holy Conduit 2
Divine Intellect 5
Precision 3
]=])

ns.RegisterTalentBuild([=[
name: Paladin - Protection (level 60)
class: PALADIN
tree: Protection
level: 60
source: Icy Veins level 60 build "Deep Protection" (0/35/16), November 2026
notes: Shieldsworn at the bottom of Protection, plus Retribution for Benediction and Conviction.
order:
Redoubt 5
Precision 3
Sacred Duty 2
Templar's Bulwark
Shield Specialization 2
Toughness 3
Swift Judgement
Improved Righteous Fury 3
Anticipation 5
Holy Shield
Reckoning 5
Iron Creed 3
Shieldsworn
Benediction 5
Improved Judgement 2
Conviction 3
Sanctified Judgement 3
Pursuit of Justice 2
Sacred Arbiter
]=])

ns.RegisterTalentBuild([=[
name: Paladin - Holy (level 60)
class: PALADIN
tree: Holy
level: 60
source: Icy Veins level 60 build "Light's Vigil" (31/8/12), November 2026
notes: Light's Vigil at the bottom of Holy, plus Retribution for Benediction and Conviction; Protection for Divine Intellect and Sacred Duty.
order:
Spiritual Focus 5
Healing Light 3
Reverence 2
Purifying Power 2
Divine Favor
Illumination 5
Holy Conduit
Infusion of Light 2
Oath of Light
Holy Shock
Boundless Light 2
Holy Power 5
Light's Vigil
Divine Intellect 5
Guardian's Favor
Sacred Duty 2
Benediction 5
Improved Judgement 2
Conviction 3
Pursuit of Justice 2
]=])
