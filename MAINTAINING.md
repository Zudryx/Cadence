# Maintaining Cadence rotations

These are the steps the scheduled rotation review follows. A person can follow them too.

## 1. Check the guides

For every class in `Cadence/Rotations/`, check the current **WoW Forever** guides for each spec:

- Icy Veins (`icy-veins.com/wow-forever/...`). Use web search results only. Icy Veins blocks automated page reading: don't try to get around that and don't scrape it.
- Warcraft Tavern (`warcrafttavern.com/forever/...`)
- Wowhead (WoW Forever guides)
- Mobalytics and Method (WoW Forever), when they have a guide for that spec

What to look for: priority order changes, new or renamed abilities, the level spells are learned at, talent-tree changes (a spec's signature talents), opener changes, and patch notes that change how a spell works (cooldown, stance, rage cost, proc).

Write rotations in our own format and our own words. Never copy guide text into the repo or the pull request; link the sources instead.

## 2. Update the rotation files

- `Cadence/Rotations/<Class>.lua`, one `ns.RegisterBuiltin([=[ ... ]=])` block per spec.
- Sections: `[keypress]`, `[opener]`, `[loop]`, `[aoe]`, `[priority]`, `[interrupt]`, `[defensive]`. The format is in `Cadence/README.md` and at the top of `Cadence/Parser.lua`.
- `tree:` = the talent tree's name. `weapon:` = two-hand / dual / shield. New talent trees need their signature talents added to `TREE_SIGNATURES` in `Cadence/Build.lua`.
- Buffs and debuffs used with `@missing` / `@nodebuff` need a duration in `DEFAULT_DURATIONS` in `Cadence/Tracker.lua`.
- Keep stuns and crowd control commented out (`# /cast ...`) unless the guide treats them as part of the normal rotation.

## 3. Test

```
python3 tests/runlua.py tests/syntax.lua Cadence
python3 tests/runlua.py tests/compile_test.lua Cadence
python3 tests/runlua.py tests/smoke_test.lua Cadence
python3 tests/runlua.py tests/helper_test.lua Cadence
```

(or `lua5.4 tests/<file>.lua Cadence`). All must pass. If a test fails because it hard-codes the old rotation, update the test, and say so in the pull request.

## 4. Version, changelog, pull request

- Bump the patch version in **both** `Cadence/Cadence.toc` (`## Version:`) and `Cadence/Core.lua` (`ns.VERSION`). The syntax test checks they match.
- Add a `## x.y.z` section at the top of `CHANGELOG.md`, written for players: what changed in plain words.
- Open a pull request titled `Rotation update YYYY-MM-DD` on a new branch. In the body, for each change: what changed, why, and the source link.
- If nothing needs changing, don't open a pull request. Just report that the rotations are current.

Merging the pull request publishes the release automatically (see `.github/workflows/release.yml`).

## When WoW Forever patches

If the game's interface version changes, update `## Interface:` in `Cadence/Cadence.toc`. The number comes from `/dump select(4, GetBuildInfo())` in game, or from patch notes and other Forever addons. Then bump the version, as in step 4.
