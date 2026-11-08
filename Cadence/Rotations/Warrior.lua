-- Cadence: built-in Warrior rotations for WoW Forever.
--
-- Priorities are based on the WoW Forever Warrior guides on Icy Veins,
-- Warcraft Tavern and Mobalytics (checked November 2026), turned into
-- GSE-style one-button sequences.
--
-- Each rotation covers level 1-60: spells you haven't learned yet are
-- skipped automatically, so the same rotation grows as you level.
--
-- Auto-pick: "tree:" matches the talent tree you've spent the most points
-- in, "weapon:" (two-hand / dual / shield) is used before you have talents.
-- [priority] drives the rotation helper (bar highlight), Hekili-style: the
-- highest line that's ready right now is shown.
-- You can edit any of these in game with /cad. Your edits are saved
-- separately, and "Revert" brings back the version in this file.

local ADDON, ns = ...

ns.RegisterBuiltin([=[
name: Warrior - Arms
class: WARRIOR
detect: Mortal Strike
tree: Arms
weapon: two-hand
default: yes
notes: Two-hander in Battle Stance. Overpower and Mortal Strike first, Slam to fill, Heroic Strike with spare Rage.

# Every press: charge when out of combat, start auto-attack, stay in Battle Stance.
[keypress]
/cast [nocombat,harm,nodead] Charge
/startattack [harm,nodead]
/cast [nostance:1] Battle Stance

# Start of each fight: Bloodrage + Battle Shout (only if it's missing), then Rend.
[opener]
/cast Bloodrage
    /cast Battle Shout @ifmissing Battle Shout
/cast Rend
    /cast Overpower

# Indented lines are fallbacks: if the first spell can't be cast
# (cooldown, no proc, target above 20%), the next line is tried.
[loop]
3x /cast Mortal Strike
    /cast Overpower
    /cast Execute
    /cast Slam
    /cast Heroic Strike @unless Slam
2x /cast Overpower
    /cast Execute
    /cast Mortal Strike
    /cast Slam
    /cast Heroic Strike @unless Slam
1x /cast Victory Rush
    /cast Overpower
    /cast Execute
1x /cast Rend
    /cast Overpower
1x /cast Sunder Armor
    /cast Overpower
2x /cast Heroic Strike

# AoE button: Sweeping Strikes + Thunder Clap, Cleave instead of Heroic Strike.
[aoe]
2x /cast Sweeping Strikes
    /cast Thunder Clap
    /cast Mortal Strike
    /cast Overpower
2x /cast Thunder Clap
    /cast Mortal Strike
    /cast Overpower
1x /cast Mortal Strike
    /cast Overpower
    /cast Execute
2x /cast Cleave
1x /cast Heroic Strike @unless Cleave

# Rotation helper: the highest line that's ready right now glows.
[priority]
/cast Battle Shout @missing Battle Shout
/cast Bloodrage
/cast Sweeping Strikes @enemies 2
/cast Thunder Clap @enemies 3
/cast Overpower
/cast Mortal Strike
/cast Execute
/cast Victory Rush
/cast Rend @nodebuff Rend
/cast Slam
/cast Cleave @enemies 2
/cast Heroic Strike

# Interrupts (red): suggested when your target casts something you can
# interrupt. The Cadence Interrupt key (/cad bind interrupt) tries these in
# order, so it uses whichever works in your stance and gear.
[interrupt]
/cast Pummel
/cast Shield Bash
/cast Concussion Blow

# Defensives (orange): suggested in combat when the checks pass.
[defensive]
/cast Shield Wall @health 20
/cast Last Stand @health 25
/cast Retaliation @health 50 @enemies 3
# Stuns / crowd control are off by default. Remove the # to turn one on:
# /cast Intimidating Shout @health 25 @enemies 2
# /cast Piercing Howl @enemies 3
]=])

ns.RegisterBuiltin([=[
name: Warrior - Fury
class: WARRIOR
detect: Bloodthirst
tree: Fury
weapon: dual
notes: Dual wield. Battle Stance while leveling; once you learn Whirlwind (36) it fights in Berserker Stance and goes back to Battle out of combat so Charge works. Whirlwind and Bloodthirst first.

# Stance numbers assume the usual order: 1 Battle, 2 Defensive, 3 Berserker.
[keypress]
/cast [nocombat,nostance:1] Battle Stance
/cast [nocombat,harm,nodead,stance:1] Charge
/startattack [harm,nodead]
/cast [combat,nostance:3] Berserker Stance @if Whirlwind
/cast [combat,nostance:1] Battle Stance @unless Whirlwind

[opener]
/cast Bloodrage
    /cast Battle Shout @ifmissing Battle Shout
/cast Bloodthirst
    /cast Rend @unless Whirlwind
    /cast Whirlwind

[loop]
3x /cast Whirlwind
    /cast Bloodthirst
    /cast Execute
    /cast Overpower @unless Whirlwind
    /cast Heroic Strike @unless Whirlwind
3x /cast Bloodthirst
    /cast Whirlwind
    /cast Execute
    /cast Overpower @unless Whirlwind
    /cast Heroic Strike @unless Whirlwind
1x /cast Victory Rush
    /cast Execute
    /cast Bloodthirst
1x /cast Rend @unless Whirlwind
    /cast Overpower @unless Whirlwind
2x /cast Heroic Strike

[aoe]
3x /cast Whirlwind
    /cast Bloodthirst
    /cast Thunder Clap @unless Whirlwind
    /cast Overpower @unless Whirlwind
2x /cast Bloodthirst
    /cast Whirlwind
    /cast Thunder Clap @unless Whirlwind
2x /cast Cleave
1x /cast Heroic Strike @unless Cleave

[priority]
/cast Battle Shout @missing Battle Shout
/cast Bloodrage
/cast Whirlwind
/cast Bloodthirst
/cast Execute
/cast Thunder Clap @enemies 3
/cast Overpower
/cast Victory Rush
/cast Rend @nodebuff Rend
/cast Cleave @enemies 2
/cast Heroic Strike

# Interrupts (red): suggested when your target casts something you can
# interrupt. The Cadence Interrupt key (/cad bind interrupt) tries these in
# order, so it uses whichever works in your stance and gear.
[interrupt]
/cast Pummel
/cast Shield Bash
/cast Concussion Blow

# Defensives (orange): suggested in combat when the checks pass.
[defensive]
/cast Shield Wall @health 20
/cast Last Stand @health 25
/cast Retaliation @health 50 @enemies 3
# Stuns / crowd control are off by default. Remove the # to turn one on:
# /cast Intimidating Shout @health 25 @enemies 2
# /cast Piercing Howl @enemies 3
]=])

ns.RegisterBuiltin([=[
name: Warrior - Protection
class: WARRIOR
detect: Shield Slam
tree: Protection
weapon: shield
notes: One-hander + shield in Defensive Stance (from level 10). Shield Slam and Revenge first, Sunder Armor to fill. Also the strongest leveling spec in Forever.

[keypress]
/cast [nocombat,harm,nodead] Charge
/startattack [harm,nodead]
/cast [nostance:2] Defensive Stance

[opener]
/cast Bloodrage
    /cast Battle Shout @ifmissing Battle Shout
    /cast Sunder Armor
/cast Rend
    /cast Sunder Armor

[loop]
3x /cast Shield Slam
    /cast Revenge
    /cast Sunder Armor
3x /cast Revenge
    /cast Shield Slam
    /cast Sunder Armor
1x /cast Victory Rush
    /cast Revenge
    /cast Sunder Armor
1x /cast Rend
    /cast Revenge
1x /cast Thunder Clap
    /cast Revenge
2x /cast Heroic Strike

[aoe]
3x /cast Thunder Clap
    /cast Revenge
    /cast Shield Slam
2x /cast Revenge
    /cast Shield Slam
    /cast Sunder Armor
1x /cast Demoralizing Shout
    /cast Revenge
2x /cast Cleave
1x /cast Heroic Strike @unless Cleave

[priority]
/cast Battle Shout @missing Battle Shout
/cast Bloodrage
/cast Thunder Clap @enemies 2
/cast Demoralizing Shout @enemies 3
/cast Shield Slam
/cast Revenge
/cast Victory Rush
/cast Thunder Clap @nodebuff Thunder Clap
/cast Rend @nodebuff Rend
/cast Sunder Armor
/cast Cleave @enemies 2
/cast Heroic Strike

# Interrupts (red): suggested when your target casts something you can
# interrupt. The Cadence Interrupt key (/cad bind interrupt) tries these in
# order, so it uses whichever works in your stance and gear.
[interrupt]
/cast Shield Bash
/cast Pummel
/cast Concussion Blow

# Defensives (orange): suggested in combat when the checks pass.
[defensive]
/cast Shield Wall @health 20
/cast Last Stand @health 30
/cast Shield Block @health 70
/cast Retaliation @health 50 @enemies 3
# Stuns / crowd control are off by default. Remove the # to turn one on:
# /cast Intimidating Shout @health 25 @enemies 2
# /cast Disarm @health 40
]=])
