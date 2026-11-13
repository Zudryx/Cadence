-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Tactara: the newest changelog sections, for the "what's new" window.
-- Made from CHANGELOG.md by tests/make_whats_new.py: edit the changelog,
-- then run that script. Don't edit this file by hand.

local ADDON, ns = ...

ns.WHATS_NEW = {
  { version = "0.16.0", lines = {
    "- **What's new:** after Tactara updates, a window shows what changed (including any versions you skipped), once for all your characters. `/tac new` shows it any time. Turn it off on the settings page (Reminders).",
    "- **Set up your key:** a character with no Tactara key is asked once whether to set one up, before the talent planner question. **Pick a key** works like `/tac bind`; **Later** asks again next time; **No thanks** doesn't ask again. The glow and the helper popup work without a key.",
    "- First-time questions (your key and the talent planner) can be turned off for all your characters on the settings page (Reminders).",
    "- **Share your settings:** `/tac export` (or **Export** on the settings page, Your characters) gives this character's settings as text, to back them up or give them to a friend on any account or computer. `/tac import` takes it back: you're asked first, and keys only come along if you choose **With keys**.",
    "- **Games in other languages:** rotations and talent builds now work on German, French, Spanish and other game clients. Tactara finds each spell's name in your language by its spell ID; its own windows stay in English. `/tac probe locale` checks the IDs against your game. On English games nothing changes.",
    "- No gameplay changes.",
  } },
  { version = "0.15.0", lines = {
    "- **Level 60 talent builds:** every spec now has a level 60 build as well, the main raid and dungeon build from each Icy Veins spec page (Druid has one for Cat and one for Bear), checked against the game's trees. They're under **Level 60** in the planner, below the leveling builds.",
    "- **Switching at 60:** unlearn your talents at your class trainer (it costs gold), then **Use this build** and **Learn all**. The planner says so when your talents don't fit a level 60 build.",
    "- **When you reach 60,** Tactara asks once whether to look at the level 60 build for your spec. Nothing changes unless you pick it.",
    "- The planner's build list is grouped (**Leveling**, **Level 60**, **Yours**) and leaves out your class name. Level 60 builds are listed point by point instead of level by level.",
    "- No gameplay changes.",
  } },
  { version = "0.14.0", lines = {
    "- **Talent builds for every class:** leveling builds for every spec of Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock and Druid (one Feral build for Cat and Bear), level 10 to 60, from the Icy Veins leveling guides. Each is checked point by point against the game's talent trees.",
    "- **Warrior builds updated:** Arms, Fury and Protection now follow the Icy Veins leveling guides too. If you follow one, Tactara asks before anything changes: **Switch**, **Later** or **Keep mine**.",
    "- **Talent planner, Hunter:** the trees draw and check correctly. The Hunter data has a second Lightning Reflexes far off to the side, an Improved Serpent Sting far below the tree, and an arrow from Bestial Wrath back up to Intimidation (which would make each need the other). Those are left out.",
    "- **Before the pull:** when you target an enemy and you're not fighting yet, a line under the helper popup lists what your rotation wants up and isn't: a buff it keeps up, your pet, or a poison or weapon imbue (Rogue, Shaman). A chat line says the same at most once a minute. Tactara only tells you; you cast it. Settings page (Reminders) or `/tac prepull on` / `helper` / `off`.",
    "- **Trainer reminder:** when you level up, a chat line lists the spells now waiting at your class trainer, the ones your rotation uses first. `/tac trainer` shows the list any time. New spells only, not new ranks.",
    "- **Dual spec:** each spec keeps its own talent build and rotation choice. Switch specs and Tactara switches with you, and says which build it's following. The talent glow only shows on your active spec's tab.",
    "- **The same settings on all your characters:** copy keys, display positions and sizes, the glow, suggestions, minimap button and talent options from another character (settings page > Your characters, or `/tac copy`). Or make them the default every new character starts with (`/tac defaults`). Rotation and talent builds always stay each character's own. Characters show up in the list after you've played them once with this version.",
    "- **A one-time question on each character:** the first time you play a character with Tactara (a new character, a fresh install, or one that hasn't picked a talent build), Tactara asks once whether to open the talent planner. Below level 10 you can choose **At level 10** instead, and you're asked again when you get your first talent point. Never in combat. Characters already following a build aren't asked. Turn it off for all your characters on the settings page (Talents).",
    "- **Build updates are your choice:** when Tactara updates one of its talent builds that you're following, you keep following the version you picked. Tactara asks once: **Switch**, **Later** or **Keep mine**. It tells you where the build changed and whether the new version fits your talents or would need a respec. **Keep mine** saves your version as your own build, which never changes. The planner shows the same choice.",
    "- **Talent planner, Warlock and Priest:** the trees now draw and check correctly. The game puts a few talents slightly off the grid (Warlock's Improved Life Tap and Amplify Curse), which made Suppression look like it needed 5 points first. A stray second Holy Specialization in the Priest data is now ignored.",
    "- No gameplay changes.",
  } },
}
