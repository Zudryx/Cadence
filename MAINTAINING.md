# Maintaining Tactara rotations

These are the steps the scheduled rotation review follows. A person can follow them too.

## Ground rules

- **Tactara stays an assistant.** Never add anything that casts without the player's own key press, repeats presses, changes what the key casts mid-fight on its own, or controls the game from outside (the updater only downloads files). If a guide's advice could only be followed by automating play, leave it out and say so in the pull request.
- **Don't name other rotation or one-button addons** in the addon, its guide, the changelog or pull requests, and never suggest Tactara is one of them or works with them. (Listing the action-bar addons the glow works with is fine.)
- **License headers.** Tactara is GPL-3.0 only. New Lua files start with the same two license lines as the others (`-- Copyright (C) 2026 Zudryx. ...` and `-- SPDX-License-Identifier: GPL-3.0-only`). Don't change `LICENSE`, which must stay the unmodified GPL text; the name and logo terms live in `NOTICE.md`.
- **The owner tests before anything reaches players.** Work goes on the `testing` branch. Each push there publishes a GitHub **pre-release** test build (`vX.Y.Z-test.N`): not on CurseForge, and the normal updater skips it ("Update Tactara (testing).bat" installs it). Merge `testing` into `main` only after the owner approves; that publishes the normal GitHub release and uploads to CurseForge. A test build needs a version that isn't released yet: bump the version first (pushes for an already-released version, like docs-only changes, make no test build).
- **Talents are learned only by the player's choice:** a Learn click, or level-up learning the player turned on. Never in combat, only the build the player picked.
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
- Add a `## x.y.z` section at the top of `CHANGELOG.md`, written for players: what changed in plain words. Then run `python3 tests/make_whats_new.py`: it copies the newest sections into `Tactara/WhatsNew.lua` for the in-game "what's new" window, and the tests fail until you do.
- Open a pull request titled `Rotation update YYYY-MM-DD` on a new branch. In the body, for each change: what changed, why, and the source link.
- If nothing needs changing, don't open a pull request. Just report that the rotations are current.

Merging the pull request publishes the release automatically (see `.github/workflows/release.yml`).

## When WoW Forever patches

If the game's interface version changes, update `## Interface:` in `Tactara/Tactara.toc`. The number comes from `/dump select(4, GetBuildInfo())` in game, or from patch notes and other Forever addons. Then bump the version, as in step 4.

## CurseForge uploads

Each new release is also uploaded to CurseForge (project 1795307, set by `## X-Curse-Project-ID` in `Tactara/Tactara.toc`) by `.github/scripts/curseforge_upload.py`, tagged with the WoW Forever game version that matches `## Interface` (16001 = 1.60.1) and with that version's CHANGELOG section. It needs the `CF_API_KEY` repository secret; without it the upload is skipped with a notice. To test the token without uploading, run the Release workflow by hand (Actions > Release > Run workflow) with **CurseForge: check**. If an upload fails, fix the cause and run it with **upload**.

## Talent builds

Tactara's recommended talent builds live in `Tactara/TalentBuilds/<Class>.lua`, one `ns.RegisterTalentBuild` per spec, as a point-by-point order from level 10. Check them with the Forever guides when you check rotations. Players following one of these builds are asked before an update applies to them (they keep their version until they choose), so change a build only when the guides really changed, and **never rename a built-in build**: players are linked to it by name. Every build must be legal on the game's trees. The tests read the real trees in `tests/talent_fixtures/<class>.lua`, made from a `/tac probe talents` report (any level, even 1) with `python3 tests/make_talent_fixture.py report.txt`. When Blizzard changes a class's talents, get a new probe and remake its fixture.

Where the builds come from: the Icy Veins leveling guide for each spec (`icy-veins.com/wow-forever/<spec>-<class>-leveling`, checked November 2026). Each guide keeps the full level 10-60 order in its talent calculator link (`...-talent-calculator#tc-...`, also in the page as `data-talentcalculator-pointsurl`): one character per point, in order, where each character is a talent's own code, shown on the page as `data-talenturlid` next to the talent's name. Icy Veins has one Feral Druid guide, so Tactara has one Feral leveling build for Cat and Bear.

Level 60 builds (`level: 60`, named "<Class> - <Spec> (level 60)") come from the first build on each Icy Veins spec page (`icy-veins.com/wow-forever/<spec>-<class>-<role>-pve-spec-builds-talents`; for Druid, the Cat DPS and Bear Tank builds). Those calculator links keep the final 51 points but not in an order the game would take, so Tactara lists them top row first, its main tree before the others. The tests check them like the leveling builds, except that a level 60 build only needs its own tree to have the most points (some don't go 31 deep). The tests check that every build is legal on the real tree, has 51 points, matches the split on its `source:` line and puts at least 31 points in its tree.

