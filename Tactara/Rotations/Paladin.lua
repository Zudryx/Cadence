-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: built-in Paladin rotations for WoW Forever.
--
-- Based on the WoW Forever Paladin guides on Warcraft Tavern, wowtbc.gg
-- and Mobalytics, and Blizzard's Forever class deep dive (checked
-- November 2026). Forever changes that matter here:
--   * Holy Strike (level 6) is a baseline melee strike for every spec.
--   * Judgement no longer uses up your Seal; Seals still last 30 seconds.
--   * Seal of Fury (level 10) is the tanking Seal, and its Judgement taunts.
--   * Consecration and Blessing of Kings are trained at level 20.
--
-- Spells you haven't learned yet are skipped, so each rotation works from
-- level 1 to 60. Holy has no healing button: healing needs you to pick who
-- to heal, so "Paladin - Holy" is the solo damage rotation (Holy Shock,
-- Holy Strike, Judgement) and you heal your group by hand.

local ADDON, ns = ...

ns.RegisterBuiltin([=[
name: Paladin - Retribution
class: PALADIN
detect: Seal of Command
tree: Retribution
weapon: two-hand
default: yes
notes: Two-hander. Keeps a Seal up (Seal of Command once you have it, Seal of Righteousness before), then Holy Strike and Judgement on cooldown, Hammer of Wrath on low-health targets and Exorcism on Undead and Demons.

[keypress]
/startattack [harm,nodead]

# Seal first if it's missing, then Judgement and Holy Strike.
[opener]
/cast Seal of Command @ifmissing Seal of Command
    /cast Seal of Righteousness @ifmissing Seal of Righteousness @unless Seal of Command
    /cast Judgement
/cast Judgement
    /cast Holy Strike
/cast Holy Strike
    /cast Judgement

# Exorcism only works on Undead and Demons and Hammer of Wrath only below
# 20% health; otherwise the next line is tried. The Seal step keeps the
# 30-second Seal going in long fights.
[loop]
3x /cast Holy Strike
    /cast Judgement
    /cast Hammer of Wrath
    /cast Exorcism
2x /cast Judgement
    /cast Holy Strike
    /cast Hammer of Wrath
    /cast Exorcism
1x /cast Hammer of Wrath
    /cast Holy Strike
    /cast Judgement
1x /cast Exorcism
    /cast Holy Strike
    /cast Judgement
1x /cast Seal of Command
    /cast Seal of Righteousness @unless Seal of Command

[aoe]
3x /cast Consecration
    /cast Holy Strike
    /cast Judgement
2x /cast Holy Strike
    /cast Judgement
    /cast Consecration
1x /cast Judgement
    /cast Holy Strike
1x /cast Seal of Command
    /cast Seal of Righteousness @unless Seal of Command

[priority]
/cast Seal of Command @missing Seal of Command
/cast Seal of Righteousness @missing Seal of Righteousness @unless Seal of Command
/cast Blessing of Kings @missing Blessing of Kings
/cast Blessing of Might @missing Blessing of Might @unless Blessing of Kings
/cast Retribution Aura @missing Retribution Aura
/cast Devotion Aura @missing Devotion Aura @unless Retribution Aura
/cast Consecration @enemies 3
/cast Holy Strike
/cast Judgement
/cast Hammer of Wrath
/cast Exorcism @creature Undead, Demon
/cast Holy Wrath @creature Undead, Demon @enemies 3
/cast Consecration @enemies 2

# Paladins have no kick: Hammer of Justice stuns, which stops the cast.
[interrupt]
/cast Hammer of Justice
/cast Repentance

[defensive]
/cast Divine Shield @health 20
/cast Lay on Hands @health 15
/cast Divine Protection @health 25
/cast [@player] Holy Light @health 40
]=])

ns.RegisterBuiltin([=[
name: Paladin - Protection
class: PALADIN
detect: Templar's Bulwark
tree: Protection
weapon: shield
notes: One-hander + shield. Righteous Fury and Seal of Fury (Seal of Righteousness before level 10), Holy Shield up, then Holy Strike and Judgement on cooldown. Judgement with Seal of Fury is also your taunt. Consecration for groups.

[keypress]
/startattack [harm,nodead]

[opener]
/cast Righteous Fury @ifmissing Righteous Fury
/cast Seal of Fury @ifmissing Seal of Fury
    /cast Seal of Righteousness @ifmissing Seal of Righteousness @unless Seal of Fury
    /cast Judgement
/cast Judgement
    /cast Holy Strike
/cast Holy Shield
    /cast Holy Strike

[loop]
3x /cast Holy Strike
    /cast Judgement
    /cast Holy Shield
    /cast Exorcism
2x /cast Judgement
    /cast Swift Judgement
    /cast Holy Strike
    /cast Holy Shield
    /cast Exorcism
2x /cast Holy Shield
    /cast Holy Strike
    /cast Judgement
1x /cast Consecration
    /cast Holy Strike
    /cast Judgement
1x /cast Seal of Fury
    /cast Seal of Righteousness @unless Seal of Fury

[aoe]
3x /cast Consecration
    /cast Holy Shield
    /cast Holy Strike
2x /cast Holy Strike
    /cast Judgement
    /cast Consecration
2x /cast Holy Shield
    /cast Judgement
    /cast Holy Strike
1x /cast Seal of Fury
    /cast Seal of Righteousness @unless Seal of Fury

[priority]
/cast Righteous Fury @missing Righteous Fury
/cast Seal of Fury @missing Seal of Fury
/cast Seal of Righteousness @missing Seal of Righteousness @unless Seal of Fury
/cast Blessing of Kings @missing Blessing of Kings
/cast Blessing of Might @missing Blessing of Might @unless Blessing of Kings
/cast Devotion Aura @missing Devotion Aura
/cast Consecration @enemies 2
/cast Holy Shield
/cast Holy Strike
/cast Judgement
/cast Swift Judgement
/cast Exorcism @creature Undead, Demon
/cast Holy Wrath @creature Undead, Demon @enemies 3
/cast Hammer of Wrath

[interrupt]
/cast Hammer of Justice

[defensive]
/cast Templar's Bulwark @health 35
/cast Lay on Hands @health 15
/cast Divine Protection @health 25
]=])

ns.RegisterBuiltin([=[
name: Paladin - Holy
class: PALADIN
detect: Holy Shock
tree: Holy
weapon: one-hand
notes: Solo damage for a Holy Paladin ("Shockadin"): Seal of Righteousness, Holy Shock, Holy Strike and Judgement, Light's Vigil on the target once you have it. Healing in groups is up to you: the key never picks heal targets.

[keypress]
/startattack [harm,nodead]

[opener]
/cast Seal of Righteousness @ifmissing Seal of Righteousness
    /cast Judgement
/cast Light's Vigil
    /cast Holy Shock
    /cast Judgement
/cast Holy Shock
    /cast Judgement
    /cast Holy Strike

[loop]
3x /cast Holy Shock
    /cast Holy Strike
    /cast Judgement
    /cast Exorcism
2x /cast Holy Strike
    /cast Judgement
    /cast Holy Shock
    /cast Exorcism
2x /cast Judgement
    /cast Holy Strike
    /cast Holy Shock
1x /cast Light's Vigil
    /cast Holy Shock
    /cast Holy Strike
1x /cast Exorcism
    /cast Hammer of Wrath
    /cast Holy Strike
1x /cast Seal of Righteousness

[aoe]
3x /cast Consecration
    /cast Holy Shock
    /cast Holy Strike
2x /cast Holy Shock
    /cast Holy Strike
    /cast Judgement
1x /cast Seal of Righteousness

[priority]
/cast Seal of Righteousness @missing Seal of Righteousness
/cast Blessing of Kings @missing Blessing of Kings
/cast Blessing of Wisdom @missing Blessing of Wisdom @unless Blessing of Kings
/cast Devotion Aura @missing Devotion Aura
/cast Consecration @enemies 3
/cast Light's Vigil
/cast Holy Shock
/cast Holy Strike
/cast Judgement
/cast Hammer of Wrath
/cast Exorcism @creature Undead, Demon
/cast Holy Wrath @creature Undead, Demon @enemies 3

[interrupt]
/cast Hammer of Justice

[defensive]
/cast Divine Shield @health 20
/cast Lay on Hands @health 15
/cast [@player] Holy Shock @health 50
/cast [@player] Flash of Light @health 45
/cast [@player] Holy Light @health 35
]=])
