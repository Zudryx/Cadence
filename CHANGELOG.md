# Changelog

Each `## x.y.z` section becomes the release notes for that version.

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
