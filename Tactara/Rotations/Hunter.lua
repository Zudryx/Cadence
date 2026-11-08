-- Tactara: built-in Hunter rotations for WoW Forever.
--
-- Based on the WoW Forever Hunter guides on Warcraft Tavern, wowtbc.gg and
-- Mobalytics, Blizzard's Forever class deep dive and the Forever ability list
-- on warcraft.wiki.gg (checked November 2026). Forever changes that matter:
--   * Aimed Shot is trained at level 20 by every Hunter; traps work in combat.
--   * Summon Hawk (Beast Mastery talent) shares its cooldown with Arcane Shot.
--   * Sniper Shot (Marksmanship capstone) is a big 4-second shot.
--   * Survival is a melee spec: Strider Kick, Expose Prey (Mongoose Bite
--     without a dodge) and Lacerating Strikes.
--
-- Every press sends your pet and keeps Auto Shot going. Raptor Strike is the
-- last fallback in each step, so when something reaches you the key fights
-- in melee instead of doing nothing. Spells you haven't learned are skipped.

local ADDON, ns = ...

ns.RegisterBuiltin([=[
name: Hunter - Beast Mastery
class: HUNTER
detect: Bestial Wrath
tree: Beast Mastery
default: yes
notes: Pet first: Hunter's Mark, send the pet, Serpent Sting, then Summon Hawk / Arcane Shot, Aimed Shot and Multi-Shot on cooldown. Bestial Wrath, Intimidation and Rapid Fire as they come up. Aspect of the Hawk from level 10.

[keypress]
/petattack [harm,nodead]
/cast [harm,nodead] !Auto Shot

[opener]
/cast Hunter's Mark
    /cast Serpent Sting
/cast Serpent Sting
    /cast Arcane Shot
    /cast Raptor Strike
/cast Summon Hawk
    /cast Arcane Shot
    /cast Aimed Shot
    /cast Raptor Strike

[loop]
1x /cast Bestial Wrath
    /cast Intimidation
    /cast Rapid Fire
    /cast Arcane Shot
    /cast Raptor Strike
2x /cast Summon Hawk
    /cast Arcane Shot
    /cast Aimed Shot
    /cast Multi-Shot
    /cast Raptor Strike
2x /cast Aimed Shot
    /cast Multi-Shot
    /cast Arcane Shot
    /cast Raptor Strike
2x /cast Multi-Shot
    /cast Arcane Shot
    /cast Aimed Shot
    /cast Raptor Strike
1x /cast Serpent Sting
    /cast Arcane Shot
    /cast Raptor Strike
1x /cast Intimidation
    /cast Rapid Fire
    /cast Arcane Shot
    /cast Multi-Shot
    /cast Raptor Strike

[aoe]
3x /cast Multi-Shot
    /cast Arcane Shot
    /cast Raptor Strike
1x /cast Bestial Wrath
    /cast Rapid Fire
    /cast Multi-Shot
    /cast Raptor Strike
2x /cast Summon Hawk
    /cast Arcane Shot
    /cast Aimed Shot
    /cast Raptor Strike

[priority]
/cast Call Pet @nopet
/cast Aspect of the Hawk @missing Aspect of the Hawk
/cast Aspect of the Monkey @missing Aspect of the Monkey @unless Aspect of the Hawk
/cast Trueshot Aura @missing Trueshot Aura
/cast Hunter's Mark @nodebuff Hunter's Mark
/cast Bestial Wrath
/cast Rapid Fire
/cast Intimidation
/cast Serpent Sting @nodebuff Serpent Sting
/cast Multi-Shot @enemies 3
/cast Summon Hawk
/cast Arcane Shot
/cast Aimed Shot
/cast Multi-Shot
/cast Volley @enemies 4

# Hunters have no kick: Scatter Shot and Intimidation stop a cast.
[interrupt]
/cast Scatter Shot
/cast Intimidation

[defensive]
/cast Feign Death @health 20
/cast Deterrence @health 35
]=])

ns.RegisterBuiltin([=[
name: Hunter - Marksmanship
class: HUNTER
detect: Trueshot Aura
tree: Marksmanship
notes: Ranged: Aspect of the Hawk and Trueshot Aura up, Hunter's Mark and Serpent Sting, then Sniper Shot, Aimed Shot, Arcane Shot and Multi-Shot on cooldown with Rapid Fire. Works with or without a pet (Lone Wolf).

[keypress]
/petattack [harm,nodead]
/cast [harm,nodead] !Auto Shot

[opener]
/cast Hunter's Mark
    /cast Serpent Sting
/cast Aimed Shot
    /cast Serpent Sting
    /cast Arcane Shot
    /cast Raptor Strike
/cast Serpent Sting
    /cast Arcane Shot
    /cast Raptor Strike

[loop]
2x /cast Sniper Shot
    /cast Aimed Shot
    /cast Arcane Shot
    /cast Multi-Shot
    /cast Raptor Strike
3x /cast Aimed Shot
    /cast Arcane Shot
    /cast Multi-Shot
    /cast Raptor Strike
3x /cast Arcane Shot
    /cast Multi-Shot
    /cast Aimed Shot
    /cast Raptor Strike
2x /cast Multi-Shot
    /cast Arcane Shot
    /cast Aimed Shot
    /cast Raptor Strike
1x /cast Rapid Fire
    /cast Arcane Shot
    /cast Raptor Strike
1x /cast Serpent Sting
    /cast Arcane Shot
    /cast Raptor Strike

[aoe]
3x /cast Multi-Shot
    /cast Arcane Shot
    /cast Raptor Strike
1x /cast Rapid Fire
    /cast Multi-Shot
    /cast Raptor Strike
2x /cast Aimed Shot
    /cast Arcane Shot
    /cast Raptor Strike

[priority]
/cast Call Pet @nopet @unless Lone Wolf
/cast Aspect of the Hawk @missing Aspect of the Hawk
/cast Aspect of the Monkey @missing Aspect of the Monkey @unless Aspect of the Hawk
/cast Trueshot Aura @missing Trueshot Aura
/cast Hunter's Mark @nodebuff Hunter's Mark
/cast Rapid Fire
/cast Serpent Sting @nodebuff Serpent Sting
/cast Multi-Shot @enemies 3
/cast Sniper Shot
/cast Aimed Shot
/cast Arcane Shot
/cast Multi-Shot
/cast Volley @enemies 4

[interrupt]
/cast Scatter Shot
/cast Intimidation

[defensive]
/cast Feign Death @health 20
/cast Deterrence @health 35
]=])

ns.RegisterBuiltin([=[
name: Hunter - Survival
class: HUNTER
detect: Strider Kick
tree: Survival
notes: Melee Hunter: shoot as they come in, then Strider Kick, Mongoose Bite, Raptor Strike and Immolation Trap at your feet in melee. Aspect of the Beast from 30 (Aspect of the Hawk before).

[keypress]
/petattack [harm,nodead]
/startattack [harm,nodead]
/cast [harm,nodead] !Auto Shot

[opener]
/cast Hunter's Mark
    /cast Serpent Sting
/cast Serpent Sting
    /cast Raptor Strike
    /cast Arcane Shot
/cast Immolation Trap
    /cast Raptor Strike
    /cast Arcane Shot

# Melee spells come first: at range they fail and the shots behind them fire.
[loop]
3x /cast Strider Kick
    /cast Mongoose Bite
    /cast Raptor Strike
    /cast Arcane Shot
    /cast Aimed Shot
3x /cast Counterattack
    /cast Mongoose Bite
    /cast Raptor Strike
    /cast Strider Kick
    /cast Arcane Shot
3x /cast Raptor Strike
    /cast Mongoose Bite
    /cast Strider Kick
    /cast Arcane Shot
    /cast Multi-Shot
1x /cast Immolation Trap
    /cast Raptor Strike
    /cast Arcane Shot
1x /cast Serpent Sting
    /cast Raptor Strike
    /cast Arcane Shot

[aoe]
2x /cast Explosive Trap
    /cast Immolation Trap
    /cast Raptor Strike
    /cast Multi-Shot
3x /cast Raptor Strike
    /cast Mongoose Bite
    /cast Strider Kick
    /cast Multi-Shot
2x /cast Multi-Shot
    /cast Raptor Strike
    /cast Arcane Shot

[priority]
/cast Call Pet @nopet
/cast Aspect of the Beast @missing Aspect of the Beast
/cast Aspect of the Hawk @missing Aspect of the Hawk @unless Aspect of the Beast
/cast Aspect of the Monkey @missing Aspect of the Monkey @unless Aspect of the Hawk
/cast Hunter's Mark @nodebuff Hunter's Mark
/cast Explosive Trap @enemies 3
/cast Counterattack
/cast Strider Kick
/cast Mongoose Bite
/cast Raptor Strike
/cast Immolation Trap
/cast Serpent Sting @nodebuff Serpent Sting
/cast Arcane Shot
/cast Aimed Shot
/cast Multi-Shot

[interrupt]
/cast Scatter Shot
/cast Intimidation

[defensive]
/cast Feign Death @health 20
/cast Deterrence @health 35
]=])
