# Changelog

Each `## x.y.z` section becomes the release notes for that version.

## 0.4.3
- Cadence now describes itself in its own words: removed references to other addons from the addon, its notes and its guide. No gameplay changes.

## 0.4.2
- Battle Shout, Rend, Thunder Clap, Demoralizing Shout and Sunder Armor now drop off the helper after you cast them. WoW Forever doesn't report these buffs and debuffs to addons, so Cadence times them from your own casts. If the game does report one, Cadence uses that instead.
- The opener skips Battle Shout while it's still up.
- First release on GitHub, with the Windows updater (`CadenceUpdater.zip`).

## 0.4.1
- Much stronger bar glow by default (thicker border, halo, tinted icon). `/cad glow strong / normal / subtle`, plus `/cad glow test` for a 3-second preview.

## 0.4.0
- Helper popup showing the best skill to use right now, separate from the key bar.
- Interrupts (red) and defensives (orange), shown only when needed. `/cad bind interrupt` for an interrupt key.
- Stuns and crowd control in each rotation, off by default.

## 0.3.0
- Reads your talents and weapons to pick the rotation (`/cad build`).
- Priority lists for the helper, with live checks: `@missing`, `@nodebuff`, `@enemies`.

## 0.2.0
- Bar highlight: glow on the next spell on your action bars.

## 0.1.x
- One-button rotations for Warrior (Arms, Fury, Protection), level-aware.
- In-game editor, `/cad bind` key picker, pull (Charge) display, diagnostics.
