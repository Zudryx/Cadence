# Tactara

One-button rotations and a rotation helper for **World of Warcraft: Forever**.

- **One-button:** each press of your Tactara key casts the next step of your rotation.
- **Rotation helper:** a popup and a glow on your action bars show the best skill to use right now. Interrupts glow red and defensives orange, but only when needed.
- **Grows with you:** spells you haven't learned are skipped, so one rotation works from level 1 to 60. Tactara reads your talents and weapons to pick Arms, Fury or Protection for you.
- **Editable in game:** `/tac` opens an editor. Edit or write rotations and share them as text.

Currently: **Warrior** (Arms, Fury, Protection). More classes to come.

## Install

**With the updater (recommended):** download `TactaraUpdater.zip` from the [latest release](../../releases/latest) and unzip it anywhere, e.g. your Desktop. Double-click **Update Tactara.bat**. It finds your `World of Warcraft\_forever_\Interface\AddOns` folder and installs or updates Tactara. Run it again any time to get the newest version.

**Used it when it was called Cadence?** Get `TactaraUpdater.zip` from the latest release once and run it with WoW closed. It carries your settings over and moves the old folder out of AddOns.

**By hand:** download `Tactara-x.y.z.zip` from the [latest release](../../releases/latest) and unzip it into `World of Warcraft\_forever_\Interface\AddOns`.

Then in game: `/tac bind` to pick your rotation key, and `/tac help` for everything else. See [Tactara/README.md](Tactara/README.md) for the full in-game guide.

## How updates work

1. Rotations live in `Tactara/Rotations/<Class>.lua` as plain text priority lists and sequences.
2. A scheduled review checks the Forever class guides (Icy Veins, Warcraft Tavern, Wowhead) and opens a **pull request** when rotations should change, explaining what changed and why. See [MAINTAINING.md](MAINTAINING.md).
3. Merging a pull request that bumps the version in `Tactara/Tactara.toc` publishes a new **release** automatically. The tests have to pass first.
4. The updater installs the newest release. Your own rotation edits are stored in WoW's SavedVariables and are never overwritten.

## Development

The tests run outside the game against a simulated WoW API:

```
lua5.4 tests/syntax.lua Tactara        # syntax + version consistency
lua5.4 tests/compile_test.lua Tactara  # rotation parser/compiler, all rotations at levels 3-60
lua5.4 tests/smoke_test.lua Tactara    # whole addon: events, secure buttons, editor, key binding
lua5.4 tests/helper_test.lua Tactara   # helper, timers, interrupts, defensives, build detection
```

(If you only have Python and the Lua library: `python3 tests/runlua.py tests/<file>.lua Tactara`.)

GitHub Actions runs them on every pull request and before every release.

Tactara is free, and its code is open to read, as Blizzard's addon policy requires.
