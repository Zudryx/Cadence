-- Tactara: built-in Shaman rotations for WoW Forever.
--
-- Based on the WoW Forever Shaman guides on Warcraft Tavern, wowtbc.gg and
-- Mobalytics, and Blizzard's Forever class deep dive (checked November
-- 2026). Forever changes that matter here:
--   * Totems have a 1-second global cooldown; buff totems last 5 minutes.
--     Fire Nova is now a spell that erupts from your Fire totem.
--   * Weapon imbues last 60 minutes: put yours on before you go out.
--   * Elemental: Lava Burst (40) hits harder on Flame Shocked targets.
--   * Enhancement: Stormstrike every 8 seconds, Rage of the Farseer (40).
--   * Restoration: Water Shield and Riptide.
--
-- Restoration has no healing button: healing needs you to pick who to heal,
-- so that rotation is the solo damage you level with and you heal your
-- group by hand. Totem timers are Tactara's own: if you walk away from a
-- totem, it's gone before the helper knows.

local ADDON, ns = ...

ns.RegisterBuiltin([=[
name: Shaman - Enhancement
class: SHAMAN
detect: Stormstrike
tree: Enhancement
weapon: two-hand
default: yes
notes: Melee. Lightning Shield and Searing Totem up, Stormstrike on cooldown, Flame Shock and Earth Shock between, Rage of the Farseer at 40. Put your weapon imbue (Rockbiter, later Windfury) on yourself: it lasts an hour.

[keypress]
/startattack [harm,nodead]

[opener]
/cast Lightning Shield @ifmissing Lightning Shield
    /cast Searing Totem
/cast Searing Totem
    /cast Stormstrike
    /cast Flame Shock
/cast Stormstrike
    /cast Flame Shock
    /cast Earth Shock

# The Shocks share a cooldown, so a Shock step falls through to the other.
[loop]
3x /cast Stormstrike
    /cast Earth Shock
    /cast Flame Shock
2x /cast Earth Shock
    /cast Stormstrike
    /cast Flame Shock
1x /cast Flame Shock
    /cast Stormstrike
    /cast Earth Shock
1x /cast Rage of the Farseer
    /cast Stormstrike
    /cast Earth Shock
1x /cast Searing Totem
    /cast Stormstrike
    /cast Earth Shock

[aoe]
1x /cast Magma Totem
    /cast Searing Totem
2x /cast Fire Nova
    /cast Stormstrike
    /cast Earth Shock
2x /cast Stormstrike
    /cast Flame Shock
    /cast Earth Shock
1x /cast Chain Lightning
    /cast Stormstrike

[priority]
/cast Lightning Shield @missing Lightning Shield
/cast Strength of Earth Totem @missing Strength of Earth Totem
/cast Windfury Totem @missing Windfury Totem
/cast Searing Totem @missing Searing Totem
/cast Magma Totem @enemies 3 @missing Magma Totem
/cast Fire Nova @enemies 3
/cast Rage of the Farseer
/cast Stormstrike
/cast Flame Shock @nodebuff Flame Shock
/cast Earth Shock

[interrupt]
/cast Earth Shock

[defensive]
/cast [@player] Healing Wave @health 35
/cast [@player] Lesser Healing Wave @health 45
]=])

ns.RegisterBuiltin([=[
name: Shaman - Elemental
class: SHAMAN
detect: Lava Burst
tree: Elemental
weapon: shield
notes: Caster. Flame Shock up, Lava Burst (40) on cooldown, Lightning Bolt to fill, Chain Lightning now and then. Searing Totem for extra damage while leveling.

[opener]
/cast Flame Shock
    /cast Lightning Bolt
/cast Searing Totem
    /cast Lava Burst
    /cast Lightning Bolt
/cast Lava Burst
    /cast Lightning Bolt

[loop]
3x /cast Lava Burst
    /cast Lightning Bolt
4x /cast Lightning Bolt
1x /cast Flame Shock
    /cast Lightning Bolt
1x /cast Chain Lightning
    /cast Lava Burst
    /cast Lightning Bolt
1x /cast Earth Shock
    /cast Lightning Bolt

[aoe]
1x /cast Magma Totem
    /cast Searing Totem
2x /cast Fire Nova
    /cast Chain Lightning
    /cast Lightning Bolt
3x /cast Chain Lightning
    /cast Lava Burst
    /cast Lightning Bolt
1x /cast Flame Shock
    /cast Lightning Bolt

[priority]
/cast Lightning Shield @missing Lightning Shield
/cast Searing Totem @missing Searing Totem
/cast Magma Totem @enemies 3 @missing Magma Totem
/cast Fire Nova @enemies 3
/cast Chain Lightning @enemies 2
/cast Flame Shock @nodebuff Flame Shock
/cast Lava Burst
/cast Chain Lightning
/cast Lightning Bolt

[interrupt]
/cast Earth Shock

[defensive]
/cast [@player] Healing Wave @health 35
/cast [@player] Lesser Healing Wave @health 45
# Crowd control is off by default. Remove the # to turn it on:
# /cast Earthbind Totem @health 40
]=])

ns.RegisterBuiltin([=[
name: Shaman - Restoration
class: SHAMAN
detect: Riptide
tree: Restoration
weapon: shield
notes: Solo damage for a Restoration Shaman: Water Shield (Lightning Shield before) up, Flame Shock, Lightning Bolt and Earth Shock. Group healing (Riptide, Chain Heal, Healing Wave) is up to you.

[opener]
/cast Water Shield @ifmissing Water Shield
    /cast Lightning Shield @ifmissing Lightning Shield @unless Water Shield
/cast Flame Shock
    /cast Lightning Bolt
/cast Lightning Bolt

[loop]
5x /cast Lightning Bolt
1x /cast Flame Shock
    /cast Lightning Bolt
1x /cast Earth Shock
    /cast Lightning Bolt
1x /cast Searing Totem
    /cast Lightning Bolt

[aoe]
2x /cast Fire Nova
    /cast Chain Lightning
    /cast Lightning Bolt
3x /cast Chain Lightning
    /cast Lightning Bolt
1x /cast Searing Totem
    /cast Lightning Bolt

[priority]
/cast Water Shield @missing Water Shield
/cast Lightning Shield @missing Lightning Shield @unless Water Shield
/cast Mana Spring Totem @missing Mana Spring Totem
/cast Searing Totem @missing Searing Totem
/cast Fire Nova @enemies 3
/cast Chain Lightning @enemies 2
/cast Flame Shock @nodebuff Flame Shock
/cast Lightning Bolt

[interrupt]
/cast Earth Shock

[defensive]
/cast [@player] Riptide @health 60
/cast [@player] Healing Wave @health 35
/cast [@player] Lesser Healing Wave @health 45
]=])
