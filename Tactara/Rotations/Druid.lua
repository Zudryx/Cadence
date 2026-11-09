-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: built-in Druid rotations for WoW Forever.
--
-- Based on the WoW Forever Druid guides on Warcraft Tavern, wowtbc.gg and
-- Mobalytics, and Blizzard's Forever class deep dive (checked November
-- 2026). Forever changes that matter here:
--   * Faerie Fire (Feral) is free in Bear and Cat Form (6-second cooldown).
--   * Omen of Clarity is trained at 20; Tiger's Fury is gone (the Shifting
--     Power talent gives Energy instead).
--   * Bears: Lacerate (42) and Primal Bite (talent) for threat.
--   * Balance: cheaper Wrath, Eclipse (Wrath speeds up Starfire), Insect
--     Swarm is a talent.
--
-- The key shifts you into the right form when you're in caster form, so
-- press it again after a heal. Feral picks Cat or Bear from your talents
-- (Primal Bite and Natural Reaction mean Bear). Restoration has no healing
-- button: it's the solo damage you level with, and you heal by hand.

local ADDON, ns = ...

ns.RegisterBuiltin([=[
name: Druid - Feral (Cat)
class: DRUID
detect: Cat Form
tree: Feral
prefer: Shifting Power, Improved Shifting Power, Shredding Attacks, Savage Fury
default: yes
notes: Cat Form from 20 (Bear Form from 10, Wrath and Moonfire before): Rake, Claw (Shred from behind), Rip and Ferocious Bite to spend, Faerie Fire (Feral) on cooldown, Shifting Power and Berserk.

[keypress]
/cast [noform] Cat Form
/cast [noform] Bear Form @unless Cat Form
/cast [nocombat,harm,nodead] Faerie Fire (Feral)
/startattack [harm,nodead]

[opener]
/cast Rake
    /cast Maul
    /cast Moonfire
/cast Claw
    /cast Maul
    /cast Wrath

[loop]
4x /cast Shred
    /cast Claw
    /cast Maul
    /cast Wrath
1x /cast Rake
    /cast Claw
    /cast Maul
    /cast Moonfire
1x /cast Rip
    /cast Claw
    /cast Maul
    /cast Wrath
1x /cast Ferocious Bite
    /cast Claw
    /cast Demoralizing Roar
    /cast Wrath
1x /cast Faerie Fire (Feral)
    /cast Claw
    /cast Maul
    /cast Wrath
1x /cast Shifting Power
    /cast Berserk
    /cast Claw
    /cast Maul

[aoe]
3x /cast Swipe
    /cast Claw
    /cast Wrath
2x /cast Shred
    /cast Claw
    /cast Maul
1x /cast Ferocious Bite
    /cast Claw
    /cast Demoralizing Roar

[priority]
/cast Mark of the Wild @missing Mark of the Wild
/cast Thorns @missing Thorns
/cast Omen of Clarity @missing Omen of Clarity
/cast Berserk
/cast Shifting Power
/cast Faerie Fire (Feral) @nodebuff Faerie Fire (Feral)
/cast Rake @nodebuff Rake
/cast Rip @nodebuff Rip @combo 5
/cast Ferocious Bite @combo 5
/cast Shred
/cast Claw
/cast Maul
/cast Wrath

[interrupt]
/cast Bash
/cast Feral Charge

[defensive]
/cast Barkskin @health 40
/cast Frenzied Regeneration @health 35
/cast [@player] Regrowth @health 45
/cast [@player] Rejuvenation @health 60
]=])

ns.RegisterBuiltin([=[
name: Druid - Feral (Bear)
class: DRUID
detect: Primal Bite
tree: Feral
prefer: Primal Bite, Natural Reaction, Thick Hide
notes: Tanking in Dire Bear Form (Bear Form before 40): Faerie Fire (Feral) to pull, Lacerate (42) and Primal Bite for threat, Maul with spare Rage, Swipe and Demoralizing Roar for groups.

[keypress]
/cast [noform] Dire Bear Form
/cast [noform] Bear Form @unless Dire Bear Form
/cast [nocombat,harm,nodead] Faerie Fire (Feral)
/startattack [harm,nodead]

[opener]
/cast Faerie Fire (Feral)
    /cast Maul
    /cast Moonfire
/cast Demoralizing Roar
    /cast Maul
    /cast Wrath

[loop]
3x /cast Lacerate
    /cast Primal Bite
    /cast Maul
    /cast Wrath
3x /cast Primal Bite
    /cast Maul
    /cast Wrath
1x /cast Faerie Fire (Feral)
    /cast Maul
1x /cast Demoralizing Roar
    /cast Maul
1x /cast Enrage
    /cast Maul

[aoe]
3x /cast Swipe
    /cast Maul
    /cast Wrath
1x /cast Demoralizing Roar
    /cast Swipe
1x /cast Primal Bite
    /cast Swipe
1x /cast Lacerate
    /cast Swipe

[priority]
/cast Mark of the Wild @missing Mark of the Wild
/cast Thorns @missing Thorns
/cast Omen of Clarity @missing Omen of Clarity
/cast Berserk
/cast Swipe @enemies 3
/cast Demoralizing Roar @nodebuff Demoralizing Roar
/cast Faerie Fire (Feral) @nodebuff Faerie Fire (Feral)
/cast Primal Bite
/cast Lacerate
/cast Maul
/cast Wrath

[interrupt]
/cast Bash
/cast Feral Charge

[defensive]
/cast Frenzied Regeneration @health 40
/cast Barkskin @health 35
]=])

ns.RegisterBuiltin([=[
name: Druid - Balance
class: DRUID
detect: Moonkin Form
tree: Balance
notes: Caster: Moonfire and Insect Swarm up, Wrath to build Eclipse and Starfire to spend it. Moonkin Form when you have it.

[keypress]
/cast [noform] Moonkin Form

[opener]
/cast Moonfire
    /cast Wrath
/cast Insect Swarm
    /cast Wrath
/cast Wrath

[loop]
3x /cast Wrath
2x /cast Starfire
    /cast Wrath
1x /cast Moonfire
    /cast Wrath
1x /cast Insect Swarm
    /cast Wrath
1x /cast Faerie Fire
    /cast Wrath

[aoe]
3x /cast Moonfire
    /cast Wrath
2x /cast Insect Swarm
    /cast Wrath
2x /cast Wrath

[priority]
/cast Mark of the Wild @missing Mark of the Wild
/cast Thorns @missing Thorns
/cast Omen of Clarity @missing Omen of Clarity
/cast Moonkin Form @missing Moonkin Form
/cast Hurricane @enemies 4
/cast Moonfire @nodebuff Moonfire
/cast Insect Swarm @nodebuff Insect Swarm
/cast Faerie Fire @nodebuff Faerie Fire
/cast Starfire
/cast Wrath

[interrupt]
/cast Bash

[defensive]
/cast Barkskin @health 40
/cast [@player] Regrowth @health 45
/cast [@player] Rejuvenation @health 60
# Crowd control is off by default. Remove the # to turn it on:
# /cast Entangling Roots @health 40
]=])

ns.RegisterBuiltin([=[
name: Druid - Restoration
class: DRUID
detect: Wild Growth
tree: Restoration
notes: Solo damage for a Restoration Druid: Moonfire up, Wrath to fill, Faerie Fire. Group healing (Rejuvenation, Regrowth, Swiftmend, Wild Growth) is up to you.

[opener]
/cast Moonfire
    /cast Wrath
/cast Wrath

[loop]
4x /cast Wrath
1x /cast Moonfire
    /cast Wrath
1x /cast Faerie Fire
    /cast Wrath
1x /cast Insect Swarm
    /cast Wrath

[priority]
/cast Mark of the Wild @missing Mark of the Wild
/cast Thorns @missing Thorns
/cast Omen of Clarity @missing Omen of Clarity
/cast Moonfire @nodebuff Moonfire
/cast Insect Swarm @nodebuff Insect Swarm
/cast Faerie Fire @nodebuff Faerie Fire
/cast Wrath

[interrupt]
/cast Bash

[defensive]
/cast Barkskin @health 40
/cast [@player] Swiftmend @health 50
/cast [@player] Regrowth @health 45
/cast [@player] Rejuvenation @health 65
]=])
