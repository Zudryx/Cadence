<p align="center"><img src="media/logo.png" width="128" alt="Tactara logo"></p>

# Tactara

One-button rotations and a rotation helper for **World of Warcraft: Forever**.

- **One-button:** each press of your Tactara key casts the next step of your rotation.
- **Rotation helper:** a popup and a glow on your action bars show the best skill to use right now. Interrupts glow red and defensives orange, but only when needed.
- **Grows with you:** spells you haven't learned are skipped, so one rotation works from level 1 to 60. Tactara reads your talents and weapons to pick the right spec for you.
- **Editable in game:** `/tac` opens an editor. Edit or write rotations and share them as text.
- **Settings page:** Esc > Options > AddOns > Tactara (or `/tac options`) for the displays (size, how many icons, and normal, see-through or hidden between fights), the glow, suggestions and keys.
- **Minimap button:** left-click for the editor, right-click for settings, shift-click for talents, drag to move it.
- **Your characters:** copy your keys and display settings to an alt in one click, or make them the default for new characters.
- **Talent planner:** your talent trees with Tactara's builds or your own, level 10 to 60. Learn the next point with a click, or let it learn when you level up.
- **Reminders:** before a pull, a missing buff, pet, poison or weapon imbue; ammo, Soul Shards, reagents or totems running low; after a level-up, the new spells waiting at your class trainer. Tactara tells you; you cast and buy them.
- **Sound alerts (optional):** a sound when the interrupt or defensive slot lights up.

Every class and spec is included: **Warrior, Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock and Druid** (Cat and Bear are separate). Healing specs get the solo damage rotation you level with; healing your group stays in your hands. See [Tactara/README.md](Tactara/README.md#rotations-included) for the details per class.

## Fair play

Tactara is an assistant. It shows you what to press and can put your rotation on one key, but it never plays for you.

- **You press every key.** Each press of the Tactara key does what one press of a normal WoW macro does. WoW only lets an addon cast when you press a key or click, so Tactara can't cast by itself or repeat presses, and the key can't react to the fight on its own.
- **The rotation is set before the fight.** Once combat starts, WoW locks addon buttons, so Tactara can't rewrite the rotation mid-fight. The key just steps through a list you can read with `/tac steps` and edit with `/tac`.
- **The helper only points.** The popup and the glow show a spell. Using it is up to you.
- **Nothing outside the game controls it.** Tactara runs only inside WoW's own addon system. It doesn't move, target or click for you, and it doesn't read the game's memory. The Windows updater only downloads Tactara's files. It never connects to or controls the game.
- **No turbo keys.** Don't combine Tactara with turbo keys, key repeaters or programs that press keys for you. Those break Blizzard's rules whatever addon you use.
- **Free and open.** No price, no ads, no donation requests in game, and all of the code can be read here, as Blizzard's addon policy requires.

Blizzard decides what addons may do and can switch off any addon feature, so Tactara sticks to what the game's addon system allows.

Tactara is a fan-made project. It isn't made, endorsed or supported by Blizzard Entertainment. World of Warcraft is a trademark of Blizzard Entertainment, Inc.

## Install

**With the updater (recommended):** download `TactaraUpdater.zip` from the [latest release](../../releases/latest) and unzip it anywhere, e.g. your Desktop. Double-click **Update Tactara.bat**. It finds your `World of Warcraft\_forever_\Interface\AddOns` folder and installs or updates Tactara. Run it again any time to get the newest version.

**Used it when it was called Cadence?** Get `TactaraUpdater.zip` from the latest release once and run it with WoW closed. It carries your settings over and moves the old folder out of AddOns.

**By hand:** download `Tactara-x.y.z.zip` from the [latest release](../../releases/latest) and unzip it into `World of Warcraft\_forever_\Interface\AddOns`.

Then in game: `/tac bind` to pick your rotation key, and `/tac help` for everything else. See [Tactara/README.md](Tactara/README.md) for the full in-game guide.

## How updates work

1. Rotations live in `Tactara/Rotations/<Class>.lua` as plain text priority lists and sequences.
2. A scheduled review checks the Forever class guides (Icy Veins, Warcraft Tavern, Wowhead) and opens a **pull request** when rotations should change, explaining what changed and why. See [MAINTAINING.md](MAINTAINING.md).
3. Changes go to the `testing` branch first. Each push there publishes a **test build** as a GitHub pre-release: not on CurseForge, and the normal updater skips it. To try one, run **Update Tactara (testing).bat** from `TactaraUpdater.zip`, or download its zip.
4. Once a test build is approved, `testing` is merged into `main`, which publishes the **release** on GitHub and on [CurseForge](https://www.curseforge.com/projects/1795307). The tests have to pass first.
5. The updater installs the newest release. Your own rotation edits are stored in WoW's SavedVariables and are never overwritten.

## Development

The tests run outside the game against a simulated WoW API:

```
lua5.4 tests/syntax.lua Tactara        # syntax + version consistency
lua5.4 tests/compile_test.lua Tactara  # rotation parser/compiler, every rotation at levels 1-60
lua5.4 tests/smoke_test.lua Tactara    # whole addon: events, secure buttons, editor, key binding
lua5.4 tests/helper_test.lua Tactara   # helper, timers, interrupts, defensives, build detection
```

(If you only have Python and the Lua library: `python3 tests/runlua.py tests/<file>.lua Tactara`.)

GitHub Actions runs them on every pull request and before every release.


## Contributing

Bug reports, rotation suggestions and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md). Security problems: please follow [SECURITY.md](SECURITY.md) instead of opening a public issue.

## License

Tactara is free and open source under the [GNU General Public License v3](LICENSE) (GPL-3.0 only). You can fork it, change it and share your version, as long as your version stays under the same license with its code available.

**The name and logo aren't part of that.** A changed version you share needs its own name and logo, and can't present itself as the official Tactara. Saying it's "based on Tactara" with a link back is fine. See [NOTICE.md](NOTICE.md) for the exact terms.

Versions up to 0.11.0 were released under the MIT License, and copies of those stay under it.
