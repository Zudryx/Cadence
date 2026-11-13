-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: the newest changelog sections, for the "what's new" window.
-- Made from CHANGELOG.md by tests/make_whats_new.py: edit the changelog,
-- then run that script. Don't edit this file by hand.

local ADDON, ns = ...

ns.WHATS_NEW = {
  { version = "0.17.0", lines = {
    "- **After the fight:** a couple of seconds after combat ends, Tactara checks the buffs your rotation keeps up, for every class: Blessings, Righteous Fury and your aura, Fortitude and Inner Fire, Mark of the Wild and Thorns, Arcane Intellect and your armor, Demon Armor, aspects, Lightning or Water Shield, Battle Shout (when you have the rage left over), your pet, and a Rogue's poisons or a Shaman's weapon imbue. Anything missing or running low shows under the helper for 30 seconds and in chat (the same line at most every 2 minutes). Seals are left out: they'd run out before the next pull anyway. No target needed.",
    "- **Running low counts too,** before the pull and after the fight: an hour-long Blessing under 5 minutes, a 30-minute buff under 2, a 5 to 10 minute one under 1, Battle Shout under 30 seconds. The line says how long is left, like *Blessing of Might (4 min left)*. Seals still only show when they're missing or about to drop. Auras, aspects and forms never run low.",
    "- **A sound for buff reminders,** off until you pick one: settings page (Reminders) or `/tac sound buffs ready`.",
    "- The setting is now **Buffs before and after a fight** (settings page, Reminders); `/tac buffs on` / `helper` / `off` works like `/tac prepull`.",
    "- When the game hides your buffs, Tactara times them from your casts. Now a buff that replaces another (one Seal for another, one Blessing, aura, aspect, armor or shield for another) ends the old one's timer too, so Tactara doesn't think your old aspect is still up.",
    "- `/tac probe reminders` shows each buff's time left and what the after-the-fight check sees.",
    "- Tactara still only tells you; you cast the buff.",
  } },
  { version = "0.16.1", lines = {
    "- **Paladin auras:** the helper and the before-the-pull line now see the aura you have on, even after a reload or when you turned it on before logging in. Tactara reads it from your aura bar (the stance bar), which the game always shows to addons. The same goes for Warrior stances, Druid forms and Shadowform. `/tac probe reminders` lists what's on your stance bar.",
    "- No gameplay changes.",
  } },
  { version = "0.16.0", lines = {
    "- **What's new:** after Tactara updates, a window shows what changed (including any versions you skipped), once for all your characters. `/tac new` shows it any time. Turn it off on the settings page (Reminders).",
    "- **Set up your keys:** a character with no Tactara key gets a small window, before the talent planner question, with the same key buttons as the settings page: **One-button key**, **AoE key**, **Interrupt key**, and **Remove** to give them all back. Click a button and press any key; right-click one to clear it. **Done** closes it (with no key set, it asks again next time); **No thanks** doesn't ask again. `/tac reset keybinds` (or `/tac keys`) opens it any time and keeps the keys you have. The glow and the helper popup work without a key.",
    "- First-time questions (your key and the talent planner) can be turned off for all your characters on the settings page (Reminders).",
    "- **Share your settings:** `/tac export` (or **Export** on the settings page, Your characters) gives this character's settings as text, to back them up or give them to a friend on any account or computer. `/tac import` takes it back: you're asked first, and keys only come along if you choose **With keys**.",
    "- **Games in other languages:** rotations and talent builds now work on German, French, Spanish and other game clients. Tactara finds each spell's name in your language by its spell ID; its own windows stay in English. `/tac probe locale` checks the IDs against your game. On English games nothing changes.",
    "- **Sound alerts:** pick a sound to play when the red interrupt slot lights up, and one for the orange defensive slot (raid warning, ready check, alarm clock, map ping or whisper). Both are off until you pick one on the settings page (Suggestions) or with `/tac sound interrupt raid`. `/tac sound test` plays them. Like the glow, a sound only tells you; you still press the key.",
    "- **Supplies:** a Hunter's arrows or bullets (under 200), a Warlock's Soul Shards (under 2), and the reagents and totems your spells need: Flash Powder when your rotation uses Vanish, an Ankh for Reincarnation, a Fire Totem for your fire totems, and so on. You see them under the helper popup when you target an enemy, in chat when one runs low or runs out, and at a vendor that sells one. `/tac supplies` shows the list any time; settings page (Reminders) or `/tac supplies on` / `helper` / `off`. Tactara never buys anything.",
    "- No gameplay changes.",
  } },
}
