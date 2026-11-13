-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: the newest changelog sections, for the "what's new" window.
-- Made from CHANGELOG.md by tests/make_whats_new.py: edit the changelog,
-- then run that script. Don't edit this file by hand.

local ADDON, ns = ...

ns.WHATS_NEW = {
  { version = "0.18.0", lines = {
    "- **Your own limits:** on the settings page (Reminders), or with commands:",
    "  - **Buffs running low:** Early (twice as long left), Normal, Late (half) or Only when missing. `/tac buffs low early`",
    "  - **Low on ammo under** this many shots (200 by default). `/tac supplies ammo 300`",
    "  - **Low on Soul Shards under** this many (2 by default). `/tac supplies shards 3`",
    "  - At 0, ammo and shards only count when you're out.",
    "- **Hide while mounted:** the helper popup and the key bar step aside while you're on a mount or a flight path, and come back when you get off or a fight starts. Off until you turn it on: settings page (Displays) or `/tac mounted on`. While the displays are unlocked they stay, so you can still move them.",
    "- **Games in other languages:** Feral Charge now finds the right spell (in Forever the talent is the charge itself, in Cat and Bear Form), and a few spell IDs with old names were dropped. On English games nothing changes.",
    "- No gameplay changes.",
  } },
  { version = "0.17.0", lines = {
    "- **After the fight:** a couple of seconds after combat ends, Tactara checks the buffs your rotation keeps up, for every class: Blessings, Righteous Fury and your aura, Fortitude and Inner Fire, Mark of the Wild and Thorns, Arcane Intellect and your armor, Demon Armor, aspects, Lightning or Water Shield, Battle Shout (when you have the rage left over), your pet, and a Rogue's poisons or a Shaman's weapon imbue. Anything missing or running low shows under the helper for 30 seconds and in chat (the same line at most every 2 minutes). Seals are left out: they'd run out before the next pull anyway. No target needed.",
    "- **Running low counts too,** before the pull and after the fight: an hour-long Blessing under 5 minutes, a 30-minute buff under 2, a 5 to 10 minute one under 1, Battle Shout under 30 seconds. The line says how long is left, like *Blessing of Might (4 min left)*. Seals still only show when they're missing or about to drop. Auras, aspects and forms never run low.",
    "- **A sound for buff reminders,** off until you pick one: settings page (Reminders) or `/tac sound buffs ready`.",
    "- The setting is now **Buffs before and after a fight** (settings page, Reminders); `/tac buffs on` / `helper` / `off` works like `/tac prepull`.",
    "- **A buff you click off (or that's dispelled, or lost when you die) is noticed now.** In a fight the game hides your buffs, so Tactara times them from your casts, and a timer can't see a buff come off. Once the fight is over, when the game is showing your buffs again, its \"not there\" wins over the timer: the after-the-fight check and the before-the-pull line list it, and the opener puts it back up.",
    "- When the game hides your buffs, Tactara times them from your casts. Now a buff that replaces another (one Seal for another, one Blessing, aura, aspect, armor or shield for another) ends the old one's timer too, so Tactara doesn't think your old aspect is still up.",
    "- `/tac probe reminders` shows each buff's time left and what the after-the-fight check sees.",
    "- Tactara still only tells you; you cast the buff.",
  } },
  { version = "0.16.1", lines = {
    "- **Paladin auras:** the helper and the before-the-pull line now see the aura you have on, even after a reload or when you turned it on before logging in. Tactara reads it from your aura bar (the stance bar), which the game always shows to addons. The same goes for Warrior stances, Druid forms and Shadowform. `/tac probe reminders` lists what's on your stance bar.",
    "- No gameplay changes.",
  } },
}
