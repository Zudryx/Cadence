-- Tactara: built-in Mage rotations for WoW Forever.
--
-- Based on the WoW Forever Mage guides on Warcraft Tavern, wowtbc.gg and
-- Mobalytics, and Blizzard's Forever class deep dive (checked November
-- 2026). Forever changes that matter here:
--   * Frostfire Bolt is trained at 40 by every Mage.
--   * Arcane: Arcane Blast builds stacks, Arcane Wrath spends them, Missile
--     Barrage speeds up Arcane Missiles.
--   * Fire: Scorch, Fire Blast and Fireball crits stack Heating Up, which
--     shortens Pyroblast.
--   * Frost: Ice Lance (8-second cooldown) hits hard on frozen targets;
--     Fingers of Frost lets it count as frozen.
--
-- Frost Nova, Cone of Cold and Blink depend on where the enemy is, so the
-- key leaves them to you (Frost Nova is suggested when you're hurt).
-- Ground spells (Blizzard, Flamestrike) are suggested for groups but not
-- cast by the key, since they need you to aim. Use your wand when you run
-- low on mana: the helper shows it then.

local ADDON, ns = ...

ns.RegisterBuiltin([=[
name: Mage - Frost
class: MAGE
detect: Ice Lance
tree: Frost
default: yes
notes: Frostbolt (Fireball before level 4), Ice Lance when it's ready, Fire Blast as an instant. Frost Nova and Ice Lance when they reach you. Arcane Intellect and Frost Armor (Ice Armor from 30) up.

[opener]
/cast Frostbolt
    /cast Fireball
/cast Frostbolt
    /cast Fireball

[loop]
5x /cast Frostbolt
    /cast Fireball
2x /cast Ice Lance
    /cast Frostbolt
    /cast Fireball
1x /cast Fire Blast
    /cast Frostbolt
    /cast Fireball
1x /cast Cold Snap
    /cast Frostbolt

[aoe]
2x /cast Frost Nova
    /cast Arcane Explosion
4x /cast Arcane Explosion
    /cast Frostbolt
1x /cast Cone of Cold
    /cast Arcane Explosion

[priority]
/cast Arcane Intellect @missing Arcane Intellect
/cast Ice Armor @missing Ice Armor
/cast Frost Armor @missing Frost Armor @unless Ice Armor
/cast Ice Barrier @missing Ice Barrier
/cast Blizzard @enemies 4
/cast Arcane Explosion @enemies 3
/cast Ice Lance
/cast Frostbolt
/cast Fireball
/cast Fire Blast
/cast Shoot

[interrupt]
/cast Counterspell

[defensive]
/cast Ice Block @health 15
/cast Frost Nova @health 60
/cast Mana Shield @health 35
]=])

ns.RegisterBuiltin([=[
name: Mage - Fire
class: MAGE
detect: Pyroblast
tree: Fire
notes: Fireball to fill, Fire Blast on cooldown, Scorch to stack the debuff, Pyroblast (faster with Heating Up), Frostfire Bolt from 40, Combustion on cooldown.

[opener]
/cast Pyroblast
    /cast Fireball
/cast Fireball
/cast Fire Blast
    /cast Fireball

[loop]
4x /cast Fireball
2x /cast Fire Blast
    /cast Fireball
1x /cast Scorch
    /cast Fireball
1x /cast Pyroblast
    /cast Fireball
1x /cast Frostfire Bolt
    /cast Fireball
1x /cast Combustion
    /cast Fire Blast
    /cast Fireball

[aoe]
2x /cast Blast Wave
    /cast Arcane Explosion
    /cast Fire Blast
4x /cast Arcane Explosion
    /cast Fireball
1x /cast Frost Nova
    /cast Arcane Explosion

[priority]
/cast Arcane Intellect @missing Arcane Intellect
/cast Ice Armor @missing Ice Armor
/cast Frost Armor @missing Frost Armor @unless Ice Armor
/cast Flamestrike @enemies 4
/cast Blast Wave @enemies 3
/cast Arcane Explosion @enemies 3
/cast Combustion
/cast Fire Blast
/cast Pyroblast
/cast Scorch
/cast Fireball
/cast Shoot

[interrupt]
/cast Counterspell

[defensive]
/cast Ice Block @health 15
/cast Frost Nova @health 60
/cast Mana Shield @health 35
]=])

ns.RegisterBuiltin([=[
name: Mage - Arcane
class: MAGE
detect: Arcane Blast
tree: Arcane
notes: Arcane Blast to build stacks (careful with mana), Arcane Wrath (25) at 3-4 stacks, Arcane Missiles, Fire Blast as an instant. Presence of Mind and Arcane Power on cooldown. Mage Armor from 34 for mana.

[opener]
/cast Arcane Blast
    /cast Frostbolt
    /cast Fireball
/cast Arcane Blast
    /cast Frostbolt
    /cast Fireball

# Before Arcane Blast (20), Frostbolt is the main spell.
[loop]
3x /cast Arcane Blast
    /cast Frostbolt
    /cast Fireball
1x /cast Arcane Wrath
    /cast Arcane Missiles
    /cast Frostbolt
    /cast Fireball
2x /cast Arcane Missiles
    /cast Frostbolt
    /cast Fireball
1x /cast Presence of Mind
    /cast Arcane Power
    /cast Fire Blast
    /cast Arcane Missiles
1x /cast Fire Blast
    /cast Arcane Missiles
    /cast Frostbolt

[aoe]
4x /cast Arcane Explosion
    /cast Frostbolt
2x /cast Frost Nova
    /cast Arcane Explosion
1x /cast Arcane Power
    /cast Arcane Explosion

[priority]
/cast Arcane Intellect @missing Arcane Intellect
/cast Mage Armor @missing Mage Armor
/cast Ice Armor @missing Ice Armor @unless Mage Armor
/cast Frost Armor @missing Frost Armor @unless Ice Armor
/cast Arcane Explosion @enemies 3
/cast Arcane Power
/cast Presence of Mind
/cast Arcane Wrath
/cast Arcane Blast
/cast Arcane Missiles
/cast Frostbolt
/cast Fire Blast
/cast Shoot

[interrupt]
/cast Counterspell

[defensive]
/cast Ice Block @health 15
/cast Frost Nova @health 60
/cast Mana Shield @health 35
]=])
