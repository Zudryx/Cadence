# Maintaining Tactara rotations

These are the steps the scheduled rotation review follows. A person can follow them too.

## Ground rules

- **Tactara stays an assistant.** Never add anything that casts without the player's own key press, repeats presses, changes what the key casts mid-fight on its own, or controls the game from outside (the updater only downloads files). If a guide's advice could only be followed by automating play, leave it out and say so in the pull request.
- **Don't name other rotation or one-button addons** in the addon, its guide, the changelog or pull requests, and never suggest Tactara is one of them or works with them. (Listing the action-bar addons the glow works with is fine.)
- **License headers.** Tactara is GPL-3.0 only. New Lua files start with the same two license lines as the others (`-- Copyright (C) 2026 Zudryx. ...` and `-- SPDX-License-Identifier: GPL-3.0-only`). Don't change `LICENSE`, which must stay the unmodified GPL text; the name and logo terms live in `NOTICE.md`.
- **Keep the CurseForge page in step.** `docs/curseforge-description.md` is the text on the CurseForge project page. When a release changes what Tactara does (a new class feature, setting or limit), update it too, with the same rules as the README.

## 1. Check the guides

For every class in `Tactara/Rotations/` (all nine classes), check the current **WoW Forever** guides for each spec:

- Icy Veins (`icy-veins.com/wow-forever/...`). Use web search results only. Icy Veins blocks automated page reading: don't try to get around that and don't scrape it.
- Warcraft Tavern (`warcrafttavern.com/forever/...`)
- Wowhead (WoW Forever guides)
- Mobalytics and Method (WoW Forever), when they have a guide for that spec

What to look for: priority order changes, new or renamed abilities, the level spells are learned at, talent-tree changes (a spec's signature talents), opener changes, and patch notes that change how a spell works (cooldown, stance, rage cost, proc).

Write rotations in our own format and our own words. Never copy guide text into the repo or the pull request; link the sources instead.

## 2. Update the rotation files

- `Tactara/Rotations/<Class>.lua`, one `ns.RegisterBuiltin([=[ ... ]=])` block per spec.
- Sections: `[keypress]`, `[opener]`, `[loop]`, `[aoe]`, `[priority]`, `[interrupt]`, `[defensive]`. The format is in `Tactara/README.md` and at the top of `Tactara/Parser.lua`.
- `tree:` = the talent tree's name. `weapon:` = two-hand / dual / shield. New talent trees need their signature talents added to `TREE_SIGNATURES` in `Tactara/Build.lua`.
- Buffs and debuffs used with `@missing` / `@nodebuff` need a duration in `DEFAULT_DURATIONS` in `Tactara/Tracker.lua`.
- Keep stuns and crowd control commented out (`# /cast ...`) unless the guide treats them as part of the normal rotation.

## 3. Test

```
python3 tests/runlua.py tests/syntax.lua Tactara
python3 tests/runlua.py tests/compile_test.lua Tactara
python3 tests/runlua.py tests/smoke_test.lua Tactara
python3 tests/runlua.py tests/helper_test.lua Tactara
```

(or `lua5.4 tests/<file>.lua Tactara`). All must pass. If a test fails because it hard-codes the old rotation, update the test, and say so in the pull request.

## 4. Version, changelog, pull request

- Bump the patch version in **both** `Tactara/Tactara.toc` (`## Version:`) and `Tactara/Core.lua` (`ns.VERSION`). The syntax test checks they match.
- Add a `## x.y.z` section at the top of `CHANGELOG.md`, written for players: what changed in plain words.
- Open a pull request titled `Rotation update YYYY-MM-DD` on a new branch. In the body, for each change: what changed, why, and the source link.
- If nothing needs changing, don't open a pull request. Just report that the rotations are current.

Merging the pull request publishes the release automatically (see `.github/workflows/release.yml`).

## When WoW Forever patches

If the game's interface version changes, update `## Interface:` in `Tactara/Tactara.toc`. The number comes from `/dump select(4, GetBuildInfo())` in game, or from patch notes and other Forever addons. Then bump the version, as in step 4.

## CurseForge uploads

Each new release is also uploaded to CurseForge (project 1795307, set by `## X-Curse-Project-ID` in `Tactara/Tactara.toc`) by `.github/scripts/curseforge_upload.py`, tagged with the WoW Forever game version that matches `## Interface` (16001 = 1.60.1) and with that version's CHANGELOG section. It needs the `CF_API_KEY` repository secret; without it the upload is skipped with a notice. If an upload fails, fix the cause and run the Release workflow by hand with **Upload to CurseForge** ticked.
