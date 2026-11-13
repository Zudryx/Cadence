# Changelog

Each `## x.y.z` section becomes the release notes for that version.

## 0.14.0
- **Talent builds for every class:** leveling builds for every spec of Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock and Druid (one Feral build for Cat and Bear), level 10 to 60, from the Icy Veins and Warcraft Tavern leveling guides. Each is checked point by point against the game's talent trees.
- **Talent planner, Hunter:** the trees draw and check correctly. The Hunter data has a second Lightning Reflexes far off to the side, an Improved Serpent Sting far below the tree, and an arrow from Bestial Wrath back up to Intimidation (which would make each need the other). Those are left out.
- **Before the pull:** when you target an enemy and you're not fighting yet, a line under the helper popup lists what your rotation wants up and isn't: a buff it keeps up, your pet, or a poison or weapon imbue (Rogue, Shaman). A chat line says the same at most once a minute. Tactara only tells you; you cast it. Settings page (Reminders) or `/tac prepull on` / `helper` / `off`.
- **Trainer reminder:** when you level up, a chat line lists the spells now waiting at your class trainer, the ones your rotation uses first. `/tac trainer` shows the list any time. New spells only, not new ranks.
- **Dual spec:** each spec keeps its own talent build and rotation choice. Switch specs and Tactara switches with you, and says which build it's following. The talent glow only shows on your active spec's tab.
- **The same settings on all your characters:** copy keys, display positions and sizes, the glow, suggestions, minimap button and talent options from another character (settings page > Your characters, or `/tac copy`). Or make them the default every new character starts with (`/tac defaults`). Rotation and talent builds always stay each character's own. Characters show up in the list after you've played them once with this version.
- **A one-time question on each character:** the first time you play a character with Tactara (a new character, a fresh install, or one that hasn't picked a talent build), Tactara asks once whether to open the talent planner. Below level 10 you can choose **At level 10** instead, and you're asked again when you get your first talent point. Never in combat. Characters already following a build aren't asked. Turn it off for all your characters on the settings page (Talents).
- **Build updates are your choice:** when Tactara updates one of its talent builds that you're following, you keep following the version you picked. Tactara asks once: **Switch**, **Later** or **Keep mine**. It tells you where the build changed and whether the new version fits your talents or would need a respec. **Keep mine** saves your version as your own build, which never changes. The planner shows the same choice.
- **Talent planner, Warlock and Priest:** the trees now draw and check correctly. The game puts a few talents slightly off the grid (Warlock's Improved Life Tap and Amplify Curse), which made Suppression look like it needed 5 points first. A stray second Holy Specialization in the Priest data is now ignored.
- No gameplay changes.

## 0.13.0
- **Talent planner (`/tac talents`):** your three talent trees, read from the game, with a build point by point from level 10 to 60.
- **Tactara's builds:** Arms, Fury and Protection leveling builds for Warrior, from current Forever guides and checked against the game's trees. More classes are coming.
- **Your own builds:** start new, copy one of Tactara's, or **start from your talents** (keep the points you have, no respec needed), then click talents in the order you want them. The planner only lets you add points the game would take. Share builds as text and import other people's.
- **Learn next / Learn all:** learn the next points of the build you're using with one click. **Learn automatically when I level up** is there too, off by default. Never in combat.
- The next talent glows in your talent window, and a chat line reminds you when you have points to spend. Both can be turned off on the settings page (Talents).
- Open the planner with the new **Tactara planner** button at the bottom of the game's talent window, the **Talents** button in `/tac`, or shift-click the minimap button.

## 0.12.1
- **`/tac probe talents`:** a read-only report on how your talents and the talent window look to Tactara, shown in a window you can copy from. It's groundwork for a talent planner and changes nothing.
- No gameplay changes.

## 0.12.0
- **Minimap button:** left-click opens the rotation editor, right-click the settings page. Drag it to move it around the minimap. Works with round and square minimaps.
- Show or hide it on the settings page (Displays) or with `/tac minimap`; `/tac minimap reset` puts it back where it started.
- The minimap's addon menu still has Tactara too, with the same clicks.
- No gameplay changes.

## 0.11.1
- **Tactara is now licensed under the GNU GPL v3** (it was MIT). You can still fork it and share changes, as long as your version stays open source under the same license.
- **The name and logo stay with Tactara:** a changed version you share needs its own name and logo. See NOTICE.md.
- The license and notice now come with every download.
- No gameplay changes.

## 0.11.0
- **See further ahead, or just one icon:** the key bar and the helper popup can each show 1 to 10 icons instead of always 3.
- **Key bar: whole rotation** shows every step your key will cast until the rotation repeats.
- **Helper popup: everything usable now** shows every spell in your rotation you can use right now, best first.
- Extra icons are added on the right, so the first icon stays where you put it.
- On the settings page (Displays), or `/tac icons helper|key 1-10|all` and `/tac icons 3` for both.
- No gameplay changes.

## 0.10.0
- **Between fights, your choice:** the helper popup and the key bar can each show normally, go see-through or hide when you're out of combat with no enemy targeted. They come back the moment you target an enemy or combat starts.
- A slider sets how visible see-through is (10% to 90%).
- Defaults match before: the helper popup goes see-through, the key bar stays as it is.
- On the settings page (Displays), or `/tac fade helper|key show|fade|hide` and `/tac fade 40`.
- While the displays are unlocked, "hide" shows them see-through instead so you can still move them.
- No gameplay changes.

## 0.9.0
- **Helper icons tell you more**, like your action bars do: a clock sweep while a spell is on cooldown, red when your target is out of range, blue when you're short on mana, rage or energy, and grey when it can't be used right now. In boss fights and arenas, where WoW hides this, the icons stay plain.
- Both can be turned off on the settings page (Displays).
- No gameplay changes.

## 0.8.0
- **Tactara has an icon.** It shows next to Tactara in WoW's addon list.
- Tactara is also in the minimap's addon menu: left-click opens the rotation editor, right-click the settings page.
- No gameplay changes.

## 0.7.1
- The key buttons on the settings page now show the key each one is set to (or "Not set"), and update as soon as you set or remove a key, or change it in WoW's Keybindings menu.

## 0.7.0
- **Settings page:** Esc > Options > AddOns > Tactara (or `/tac options`, or the new **Settings** button in the `/tac` window). Rotation choice, keys, both displays, the bar glow and suggestions are all on one page now; the `/tac` commands still work.
- **Display size:** make the helper popup and the key bar anywhere from 50% to 200%. They stay where you put them when you resize.
- **Reset positions** puts both displays back in the middle of the screen if you lose one.
- No gameplay changes.

## 0.6.0
- **Every class is here.** New rotations for Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock and Druid, one per spec (Druid gets both Cat and Bear), built from the WoW Forever guides and Forever's new spells: Holy Strike and Seal of Fury, Summon Hawk and Strider Kick, Shank, Mutilate and Venom, Shadow Word: Death and Penance, Lava Burst and Stormstrike, Arcane Blast, Ice Lance and Frostfire Bolt, Bane of Agony and Wrack, Lacerate and Primal Bite.
- Auto-pick works for every class: it reads your talent trees, then your weapon, then picks a default. Druids with Feral points get Cat or Bear from the talents they took.
- Healing specs get the solo damage rotation you level with. Healing your group stays in your hands.
- The helper knows more: Exorcism and Holy Wrath only on Undead and Demons, a reminder when your pet is missing, and finishers when you likely have the combo points.
- Pet abilities like Spell Lock are recognized, and the rotation updates when your pet changes.
- Warrior: a few steps that only had situational spells (Victory Rush, Overpower, Execute) now fall back to Heroic Strike, Slam or Cleave instead of doing nothing.
- `/tac probe` now checks things for your own class.

## 0.5.1
- Added a fair-play note to the guide, the GitHub page and `/tac help`: Tactara is an assistant, and every cast comes from your own key press. The addon list now says "You press every key."
- Removed the old "not tested in game yet" warning from the guide.
- No gameplay changes.

## 0.5.0
- New name: Cadence is now **Tactara**, because another addon already uses the old name. The slash command is now `/tac` (or `/tactara`).
- Your settings come with you. The updater copies your rotation edits, keys and options over to Tactara and moves the old folder out of AddOns. Keys you set in WoW's Keybindings menu move over the first time you log in.
- If you used the old updater: download `TactaraUpdater.zip` from this release once and run it with WoW closed. The old updater can't find the renamed download.
- No gameplay changes.

## 0.4.3
- Tactara now describes itself in its own words: removed references to other addons from the addon, its notes and its guide. No gameplay changes.

## 0.4.2
- Battle Shout, Rend, Thunder Clap, Demoralizing Shout and Sunder Armor now drop off the helper after you cast them. WoW Forever doesn't report these buffs and debuffs to addons, so Tactara times them from your own casts. If the game does report one, Tactara uses that instead.
- The opener skips Battle Shout while it's still up.
- First release on GitHub, with the Windows updater (`TactaraUpdater.zip`).

## 0.4.1
- Much stronger bar glow by default (thicker border, halo, tinted icon). `/tac glow strong / normal / subtle`, plus `/tac glow test` for a 3-second preview.

## 0.4.0
- Helper popup showing the best skill to use right now, separate from the key bar.
- Interrupts (red) and defensives (orange), shown only when needed. `/tac bind interrupt` for an interrupt key.
- Stuns and crowd control in each rotation, off by default.

## 0.3.0
- Reads your talents and weapons to pick the rotation (`/tac build`).
- Priority lists for the helper, with live checks: `@missing`, `@nodebuff`, `@enemies`.

## 0.2.0
- Bar highlight: glow on the next spell on your action bars.

## 0.1.x
- One-button rotations for Warrior (Arms, Fury, Protection), level-aware.
- In-game editor, `/tac bind` key picker, pull (Charge) display, diagnostics.
