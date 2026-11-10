# Contributing to Tactara

Thanks for helping! There are three easy ways to help, and you don't need to write code for the first two.

## 1. Report a bug

Open a [bug report](https://github.com/Zudryx/Tactara/issues/new/choose). The most useful things to include:

- Your class, spec and level, and your Tactara version (shown in the addon list and by `/tac test`).
- What you pressed, what happened, and what you expected.
- The text of any Lua error. Type `/console scriptErrors 1` in game to make WoW show them.
- The output of `/tac probe` (run it once out of combat and once in combat; screenshots are fine).

## 2. Suggest a rotation change

Open a [rotation suggestion](https://github.com/Zudryx/Tactara/issues/new/choose). Tell us the class, spec and level range, what Tactara does now, what it should do instead, and **link the guide or patch notes** you're going by. Describe it in your own words; please don't paste guide text.

## 3. Send a change (pull request)

### Ground rules

- **Tactara stays an assistant.** Nothing may cast without the player's own key press, repeat presses, change what the key casts mid-fight on its own, or control the game from outside. See the Fair play section in the [README](README.md#fair-play).
- **Write rotations and notes in your own words**, and link your sources in the pull request.
- **Don't name other rotation or one-button addons** anywhere in the addon, its guide, the changelog or pull requests, and don't suggest Tactara is one of them or works with them. (Listing the action-bar addons the glow works with is fine.)

### Where things are

| Path | What it is |
|---|---|
| `Tactara/Rotations/<Class>.lua` | The built-in rotations, one file per class. |
| `Tactara/README.md` | The player guide, including the rotation format ("Editing and writing rotations"). |
| `Tactara/Parser.lua` | The rotation format in detail (comments at the top). |
| `Tactara/Build.lua` | Talent tree names used to auto-pick a spec. |
| `Tactara/Tracker.lua` | How long buffs and debuffs last, for the helper's timers. |
| `Tactara/Options.lua` | The settings page in Esc > Options > AddOns. |
| `Tactara/Media/Icon.tga` | The icon in WoW's addon list (64x64, 32-bit TGA). |
| `media/` | Logo (`logo.svg` is the source), CurseForge logo and the GitHub banner. Not part of the addon download. |
| `tests/class_data.lua` | Which spells each class learns at which level, used by the tests. |
| `MAINTAINING.md` | The checklist for rotation updates. |
| `updater/` | The Windows updater. |

If you add a spell to a rotation, add it to `tests/class_data.lua` too (with the level it's learned), or the tests will flag it as an unknown spell.

### Run the tests

You need Lua 5.4 (on Windows, WSL works; on Linux, `sudo apt install lua5.4`). From the repository folder:

```
lua5.4 tests/syntax.lua Tactara
lua5.4 tests/compile_test.lua Tactara
lua5.4 tests/smoke_test.lua Tactara
lua5.4 tests/helper_test.lua Tactara
```

All four must pass. `TACTARA_VERBOSE=1 lua5.4 tests/compile_test.lua Tactara` prints every rotation's steps at levels 10, 30 and 60, which is handy for checking a change.

### Try it in game

Copy the `Tactara` folder into `World of Warcraft\_forever_\Interface\AddOns`, then `/reload`. `/tac steps` shows what the key will do at your level, and `/tac spells` lists what's in use and what's still to learn.

### Versions and releases

- If players should get your change as an update, raise the version in **both** `Tactara/Tactara.toc` and `Tactara/Core.lua` (the tests check they match) and add a short, plain-words entry at the top of `CHANGELOG.md`.
- When a pull request with a new version is merged into `main`, the release and its download files are published automatically, on GitHub and on CurseForge. Changes to docs alone don't make a release.

### License of your contribution

Tactara is licensed under the GNU GPL v3 only (see [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md)). By sending a pull request, you agree that your contribution is released under the same license.
