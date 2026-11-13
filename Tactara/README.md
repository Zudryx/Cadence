# Tactara 0.14.0: one-button rotations and a rotation helper for WoW Forever

Rotations that grow with your level, played two ways:

- **One-button:** each press of your Tactara key casts the next step.
- **Rotation helper:** press your own spells. Tactara puts a pulsing blue border on the next spell on your action bars, like retail's Assisted Highlight, and moves on as you cast.

You can use both at once. Spells you haven't learned yet are skipped, so the same rotation works from level 1 to 60.

## Fair play

Tactara is an assistant, not a bot. **You press every key:** each press of the Tactara key does what one press of a normal macro does, and WoW only lets addons cast when you press something. Tactara can't cast by itself, repeat presses or change its plan mid-fight, and the helper only shows you a spell. Nothing outside the game controls it, and the updater only downloads files.

Use one key press per cast. Turbo keys, key repeaters and programs that press keys for you break Blizzard's rules whatever addon you use.

Tactara is a fan-made project, not made or endorsed by Blizzard Entertainment.

## Install

1. Unzip and copy the `Tactara` folder into
   `World of Warcraft\_forever_\Interface\AddOns\`
   so the file path is `...\AddOns\Tactara\Tactara.toc`.
   (Battle.net > gear icon next to Play > Show in Explorer opens the WoW folder.)
2. Start the game or type `/reload`. At character select, click **AddOns** and check that Tactara is ticked.
   If it says *Out of date*, tick **Load out of date AddOns**. Then type
   `/dump select(4, GetBuildInfo())` in game and send me the number so the version can be fixed.

## Set up your key (pick one)

The first time you play a character with no Tactara key, a small window offers to set them up, with the same buttons as the settings page: **One-button key**, **AoE key**, **Interrupt key**, and **Remove** to give them all back. Click a button and press any key; right-click one to clear it. **Done** closes it (with no key set, it asks again next time you log in); **No thanks** doesn't ask again. `/tac reset keybinds` (or `/tac keys`) opens it any time and keeps the keys you have. The glow on your bars and the helper popup work without a key.

- **`/tac bind` (recommended):** type `/tac bind` and press any key, with Shift/Ctrl/Alt if you want, or mouse button 3-5. It can be a key your action bar already uses, like `1`. Tactara takes that key over while the addon is loaded. **Your saved keybinds aren't changed**, and `/tac unbind` gives the key back. Use `/tac bind aoe` for the AoE button. You can also use the **Main key** / **AoE key** buttons in the `/tac` window: left-click to set a key, right-click to remove it.
- **WoW's keybinding menu:** Esc > Options > Keybindings > AddOns > Tactara. This replaces whatever was on that key.

*Action-bar macros can't run Tactara.* WoW doesn't let a macro `/click` a button that runs another macro. If you made "Tactara" macros with an older version, you can delete them.

## Rotations included

Every class has a rotation for each spec, built from the WoW Forever guides:

| Class | Rotations |
|---|---|
| Warrior | Arms, Fury, Protection |
| Paladin | Retribution, Protection, Holy |
| Hunter | Beast Mastery, Marksmanship, Survival |
| Rogue | Combat, Assassination, Subtlety |
| Priest | Shadow, Discipline, Holy |
| Shaman | Enhancement, Elemental, Restoration |
| Mage | Frost, Fire, Arcane |
| Warlock | Affliction, Demonology, Destruction |
| Druid | Feral (Cat), Feral (Bear), Balance, Restoration |

- **Healers** (Holy Paladin, Discipline and Holy Priest, Restoration Shaman and Druid): the key can't choose who to heal, so these rotations are the solo damage you level with. You heal your group with your own keys. Self-heals still show up as orange suggestions when you're hurt.
- **Pets** (Hunter, Warlock): every press sends your pet in, and the helper reminds you when your pet is missing.
- **Rogues and Cat Druids:** WoW doesn't tell addons your combo points, so the key mixes about four builders per finisher. The helper counts your builders to guess when to spend.
- **Forms and stances** (Warrior, Druid, Priest's Shadowform): the key moves you into the right one. Druids: after a heal in caster form, the next press shifts back.
- **Channels** (Mind Flay, Drain Life, Arcane Missiles): pressing again during the channel cuts it short. Let it finish when you can.
- **Ground spells** (Blizzard, Flamestrike, Rain of Fire, Volley, Hurricane) need you to aim, so they're only suggested by the helper for groups.

## Using it

- Press the button repeatedly in combat. **One press = one step.** It never presses anything by itself.
- Out of combat, the first icon on the strip can be your **PULL** (a Warrior's Charge, a Rogue's Cheap Shot, a Druid's Faerie Fire): your first press uses it. Then the fight's **opener** plays (for a Warrior: Bloodrage, Battle Shout if it's missing, Rend). After that it repeats the **loop**. The sequence restarts when combat ends.
- **Two displays** (drag to move, then `/tac lock`; change their size in `/tac options`):
  - **Key bar:** what your Tactara key will cast on its next presses: 3 by default, anywhere from 1 to 10, or the **whole rotation** (every step until it repeats).
  - **Helper popup:** the best skill to use right now, plus what comes after: 3 by default, anywhere from 1 to 10, or **everything usable now**, best first. A red **INTERRUPT** slot and an orange **DEFENSIVE** slot appear only when needed. Each icon shows its keybind from your action bars, and works like an action button: a **clock sweep** while it's on cooldown, **red** when the target is out of range, **blue** when you're short on mana, rage or energy, and **grey** when it can't be used right now. In boss fights and arenas, where WoW hides this from addons, the icons stay plain.
  - `/tac hide key` or `/tac hide helper` if you only want one.
  - **How many icons:** on the settings page, or `/tac icons key 6`, `/tac icons helper all`, `/tac icons 1` (both). Extra icons are added on the right, so the first icon stays where you put it.
  - **Between fights** (out of combat, no enemy targeted), the helper popup goes see-through and the key bar stays as it is. Each can show normally, go see-through or hide; target an enemy or get pulled and it's back at once. Set it on the settings page or with `/tac fade helper hide`, `/tac fade key fade`, `/tac fade show` (both), and `/tac fade 40` for how visible see-through is (10% to 90%).
- **Which rotation:** Tactara reads your build and picks for you: first the talent tree you've spent the most points in, then your weapons (for a Warrior: two-hander = Arms, dual wield = Fury, shield = Protection), then a sensible default for your class. Druids with points in Feral get Cat or Bear depending on the talents they took. `/tac build` shows what it detected and why it picked what it did. To change it, use `/tac use` with part of the name (`/tac use prot`, `/tac use bear`, `/tac use fire`), or **Use This** in the editor. `/tac use auto` goes back to automatic.
- When you learn new spells, the rotation updates on its own and prints *Added to your rotation: ...*. New spells are **bought from your class trainer** (a Warrior gets Rend and Charge at 4, Thunder Clap at 6, ...). Leveling up alone doesn't add them. `/tac spells` shows what's in use and what's still to learn.

## Settings

Everything below can be changed on one page: **Esc > Options > AddOns > Tactara**, or type `/tac options`, or click **Settings** in the `/tac` window.

- **Rotation:** automatic (follows your talents) or a fixed one, plus a button to the rotation editor.
- **Keys:** set your one-button, AoE and interrupt keys, give them back, hide the red "not ready" errors.
- **Displays:** show or hide the helper popup and the key bar, change their size (50% to 200%) and how many icons each shows (1 to 10, or all), turn the helper's cooldown sweep and colors on or off, choose how each looks between fights (normal, see-through or hidden) and how see-through, pick the **display look** (Standard: a thin frame around each icon, the best spell and your key's next press framed in Tactara's cyan, red and orange frames and captions on the interrupt and defensive slots; Minimal: just the icons), hide them while you're mounted or on a flight path, lock them, or reset them to the middle of the screen, and show or hide the minimap button. While they're unlocked, "hidden" shows see-through instead so you can still find and move them.
- **Bar highlight:** on or off, how strong the glow is (with a preview), and whether it follows the best spell or the key's next step.
- **Your characters:** copy keys, display positions and sizes, the glow, suggestions, minimap button and talent options from another of your characters, or make this character's settings the default for new ones. **Export** gives the same settings as text to back up or give to a friend (any account or computer); **Import** takes that text back, asks first, and only sets keys if you choose **With keys**. Rotation and talent builds stay each character's own.
- **Talents:** open the talent planner, learn talents when you level up (off by default), the planner button in the talent window, the glow on the next talent, the one-time question on new characters, and the chat reminder.
- **Suggestions:** interrupt and defensive suggestions on or off, and a sound for each (off until you pick one).
- **Reminders:** buff reminders before and after a fight, with an optional sound, and supply reminders (each under the helper and in chat, under the helper only, or off), the trainer reminder after a level-up, first-time questions on new characters (your keys and the talent planner), and the "what's new" window after an update.

The `/tac` commands still work, and both always show the same settings.

**Minimap button:** left-click opens the rotation editor, right-click the settings page. Drag it to move it around the edge of the minimap. `/tac minimap` hides or shows it, and `/tac minimap reset` puts it back where it started. Tactara is also in the **minimap's addon menu** (the button that lists your addons, if your minimap has it), which works the same way.

## Talent planner

`/tac talents` (or the **Tactara planner** button at the bottom of the game's talent window, the **Talents** button in `/tac`, or shift-click the minimap button) opens your three talent trees, read straight from the game, with a build on them point by point from level 10 to 60.

- **Tactara's builds:** a leveling build for every spec of every class, from the Icy Veins leveling guides, each checked point by point against the game's trees. Druid's Feral build covers both Cat and Bear.
- **Level 60 builds:** every spec also has a level 60 build, the main raid and dungeon build from its Icy Veins page (Druid has one for Cat and one for Bear). They're listed under **Level 60**, below the leveling builds. To switch at 60, unlearn your talents at your class trainer (it costs gold), then **Use this build** and **Learn all**. When you reach 60, Tactara asks once whether to look at the one for your spec; nothing changes unless you pick it.
- **Your own builds:** click **New**, **Copy** one of Tactara's, or **Start from my talents** to begin with the points you already have (no respec needed) and plan the rest. Click a talent to add a point to the end of the build, right-click to take its last point back, **Undo** takes back the last point. If you change one of Tactara's builds, you get your own copy and the original stays as it was. Rename yours in the box at the top. The planner won't let you add a point the game wouldn't take: 5 points per row in a tree, an arrow needs the talent before it maxed, 51 points in all.
- **Share:** **Share** gives your build as text; **Import** takes one pasted from someone else.
- **Use this build** picks the build Tactara follows for this character. Then:
  - **Learn next** and **Learn all** learn the next points of the build when you have points to spend. Never in combat.
  - **Learn automatically when I level up** (off by default) does the same by itself after each level, once you're out of combat.
  - Otherwise Tactara reminds you in chat, and the next talent glows in your talent window for you to click.
  - If WoW ever stops addons from learning talents, Tactara says so once and keeps the glow.
- **Dual spec:** each spec keeps its own build (and its own rotation choice). When you switch specs, Tactara switches too and tells you which build it's following.
- **First time on a character,** Tactara asks once whether to open the planner. Below level 10 you can pick **At level 10** to be asked when your first talent point arrives. Turn it off for all characters on the settings page.
- **When Tactara updates a build you're following,** nothing changes under you: you keep following the version you picked, and Tactara asks once whether to **Switch**, decide **Later**, or **Keep mine** (saved as your own build, which never changes). It says where the build changed and whether the new version needs a respec. The planner shows the same choice.
- The build list is grouped: **Leveling**, **Level 60** and **Yours**.
- The level-by-level list (point by point for level 60 builds) shows what you've learned (green) and what's next (blue). Talents you have that the build doesn't use show their points in red on the trees.

## Rotation helper (bar highlight)

- On by default. Toggle it with `/tac highlight` or the **Bar highlight** button in `/tac`.
- **How loud:** `/tac glow strong` (default: thick border, halo and a tinted icon), `/tac glow normal` or `/tac glow subtle`. `/tac glow test` shows a 3-second preview of all three colors on your bars, even out of combat.
- **Best skill next:** each rotation has a **priority list** built from the Forever guides. At any moment the glow shows the highest spell that's ready: Battle Shout if it's missing, AoE spells when 2-3+ enemies are nearby, Overpower when it procs, Rend when it's not on the target, and so on. The helper popup shows the top 3 (or as many as you set).
- While you're pressing the Tactara key, the glow follows the key's sequence instead, so it matches what the key will cast. After a few seconds without a press it goes back to the priority list. `/tac helper priority` or `/tac helper sequence` locks it to one.
- WoW Forever often won't tell addons which buffs and debuffs are up, so when you cast Battle Shout, Rend, Thunder Clap and similar spells, Tactara starts its own timer for them. If the game does report them, its answer wins.
- WoW Forever hides your Rage and the target's health from addons, so the helper uses *"can this spell be cast right now?"* instead. That still covers Execute below 20%, Overpower procs, and spells you can't afford yet. AoE detection needs **enemy nameplates** turned on.
- With an enemy targeted out of combat, Charge glows. In combat, the next spell glows. Cast it and the glow moves on. Casting a spell from a later step jumps ahead, and anything else is ignored.
- Without a priority list, the glow follows the sequence. Within each step it skips spells on cooldown or unusable right now (Overpower without a dodge, Execute above 20%). Not having enough Rage doesn't count, so the glow stays put until you can press it.
- **Restricted fights:** in boss encounters, arenas and battlegrounds WoW hides cooldowns and procs from addons. There the glow just follows the rotation order.
- Works with Blizzard's bars, Bartender4, ElvUI and Dominos, and with a spell inside a normal macro. It only draws on top of your buttons and never changes them.

## Interrupts and defensives

- **Interrupts (red):** when your target casts something you can interrupt, the best interrupt for your stance and gear (Pummel, Shield Bash, Concussion Blow) glows red and shows in the helper popup. Bind `/tac bind interrupt` to get a key that always casts the right one.
- **Defensives (orange):** in combat, Shield Wall / Last Stand / Shield Block / Retaliation light up when your health is low (and, for Retaliation, when 3+ enemies are on you).
- They're never part of the one-button rotation, so the key won't waste them.
- **Stuns and crowd control** (Intimidating Shout, Piercing Howl, Disarm) are in each rotation's `[defensive]` list but commented out. Remove the `#` in `/tac` to turn one on.
- `/tac interrupts` and `/tac defensives` turn each one on or off. If WoW hides what they need (your health, what the target is casting), they don't guess. They just stay quiet.
- **Sounds:** a sound can play when either slot lights up: raid warning, ready check, alarm clock, map ping or whisper. Both are off until you pick one on the settings page (Suggestions) or with `/tac sound interrupt raid` / `/tac sound defensive alarm` (`off` turns one off). The interrupt sound plays at most every 1.5 seconds and the defensive one at most every 10, so a chain of casts or your health bobbing around doesn't keep buzzing. They play on the master channel, so you hear them with game sounds turned down. `/tac sound test` plays both. Like the glow, a sound only tells you; you still press the key.

## Reminders

Tactara only tells you; it never casts, buys or learns anything for you.

- **Before the pull:** when you target an enemy and you're not fighting yet, a line under the helper popup lists what your rotation wants up and isn't, or what's running low: a buff it keeps up (Battle Shout only when you have the rage), your pet, or, for Rogues and Shamans, a poison or weapon imbue. Running low means an hour-long Blessing under 5 minutes, a 30-minute buff under 2, a 5 to 10 minute one under 1, Battle Shout under 30 seconds; the line says how long is left (*Blessing of Might (4 min left)*). Seals only show when they're missing or about to drop, and auras, aspects and forms never run low. Totems and in-fight lines like Slice and Dice aren't on it. A chat line says the same when you pick an enemy, at most once a minute (the same reminder at most every five minutes, and not while you're mounted). Paladin auras, Warrior stances, Druid forms and Shadowform are read from your stance bar (the Paladin aura bar), so they're right even after a reload. If WoW hides a buff from addons (it does in a fight), Tactara goes by its own timer from your cast, and doesn't guess without one. Out of combat, when the game is showing your buffs, its "not there" wins over the timer, so a buff you clicked off or that was dispelled in the fight is noticed after it.
- **After the fight:** a couple of seconds after combat ends, the same check without a target, for buffs that last a minute or more: Blessings, Fortitude, Mark of the Wild, armors, aspects, shields, Battle Shout when you have rage left over, your pet, poisons and weapon imbues. Anything missing or running low shows under the helper for 30 seconds and in chat (the same line at most every 2 minutes). Seals are left out; they'd run out before the next pull anyway.
- Both are one setting, **Buffs before and after a fight** on the settings page (Reminders), or `/tac buffs on` / `helper` / `off` (`/tac prepull` works too). A sound can go with them: `/tac sound buffs ready` (off until you pick one). **Buffs running low** moves the limits: Early (twice as long left), Normal, Late (half) or Only when missing (`/tac buffs low early`).
- **Supplies:** what your spells need, when it runs low:
  - **Hunters:** arrows or bullets for the bow, crossbow or gun you have on, under 200 shots.
  - **Warlocks:** Soul Shards, under 2 (once you have Drain Soul).
  - **Reagents** for spells your rotation casts: Flash Powder for Vanish, Blinding Powder for Blind, a Light Feather for Slow Fall or Levitate, Arcane Powder, candles, seeds for Rebirth, Symbols, an Infernal Stone... An **Ankh** for Reincarnation always, rotation or not.
  - **Shamans:** the Earth, Fire, Water or Air Totem item your totems need.

  The limits for ammo (200) and Soul Shards (2) are yours to change on the settings page or with `/tac supplies ammo 300` / `/tac supplies shards 3`; at 0 they only count when you're out.

  You see them under the helper popup (with the before-the-pull line) when you target an enemy, in chat when one runs low or runs out (not every arrow; the same one at most every 10 minutes), and at a vendor that sells one (*This vendor sells what you're low on: ...*). `/tac supplies` shows the list any time. Turn chat off, or the whole thing, on the settings page (Reminders) or with `/tac supplies on` / `helper` / `off`. Items go by their item ID, so this works in any game language.
- **Trainer:** when you level up, a chat line lists the spells now waiting at your class trainer, the ones your rotation uses first. It's read from your spellbook, so it covers new spells, not new ranks of ones you know. At login it only speaks up if your rotation is waiting on one. `/tac trainer` shows the list any time; `/tac trainer off` turns the level-up line off.

## Commands

| Command | What it does |
|---|---|
| `/tac` | Open the editor |
| `/tac options` | Open the settings page (also in Esc > Options > AddOns) |
| `/tac use <name>` / `/tac use auto` | Pick a rotation, or let talents decide |
| `/tac list` | Rotations for your class |
| `/tac bind` / `bind aoe` / `bind interrupt` | Press a key for the rotation, AoE or interrupt (keybinds stay as they are) |
| `/tac unbind` / `unbind aoe` / `unbind interrupt` / `unbind all` | Give the key back |
| `/tac highlight` | Bar highlight on/off |
| `/tac glow strong` / `normal` / `subtle` / `test` | Glow strength, or a 3-second preview |
| `/tac helper auto` / `priority` / `sequence` | What the glow follows |
| `/tac build` | Your detected talents and weapons, and the rotation they pick |
| `/tac steps` | Print the current sequence to chat |
| `/tac spells` | Rotation spells you've learned, and the ones still to come |
| `/tac show` / `hide` [`key` / `helper`] | The key bar and/or the helper popup |
| `/tac lock` / `unlock` | Lock or move both displays |
| `/tac talents` | Talent planner |
| `/tac talents learn` / `learn all` | Learn the next point (or all your spare points) of the build you're using |
| `/tac talents auto` | Learn talents by itself when you level up (on/off) |
| `/tac copy` [name] | Copy settings from another of your characters (no name: pick from a list) |
| `/tac defaults` / `defaults clear` | New characters start with this character's settings / with Tactara's normal ones |
| `/tac minimap` | Show or hide the minimap button (`/tac minimap reset` puts it back) |
| `/tac icons` [`helper` / `key`] `1`-`10` / `all` | How many icons each display shows |
| `/tac fade` [`helper` / `key`] `show` / `fade` / `hide` | How the displays look between fights; `/tac fade 40` sets how visible see-through is |
| `/tac interrupts` / `/tac defensives` | Red interrupt / orange defensive suggestions on or off |
| `/tac sound` `interrupt` / `defensive` / `buffs` <sound> / `off` | A sound when that slot lights up, or with buff reminders; `/tac sound` lists the sounds, `/tac sound test` plays them |
| `/tac buffs` (or `/tac prepull`) `on` / `helper` / `off` | Buff reminders before and after a fight: under the helper and in chat, under the helper only, or off |
| `/tac supplies` | Ammo, Soul Shards, reagents or totems running low (`on` / `helper` / `off`: the reminder; `ammo 300` / `shards 3`: your limits) |
| `/tac buffs low` `early` / `normal` / `late` / `off` | When a buff counts as running low |
| `/tac mounted` `on` / `off` | Hide the helper and key bar while mounted or on a flight path |
| `/tac look` `standard` / `minimal` | How the helper popup and key bar look: framed icons, or just the icons |
| `/tac new` | What's new in this version (also shown once after each update) |
| `/tac export` / `import` | Your settings as text, to back up or share; import asks first and keeps your keys unless you choose otherwise |
| `/tac trainer` | Spells waiting at your class trainer (`/tac trainer on` / `off`: the level-up reminder) |
| `/tac reset` | Restart from the opener |
| `/tac reset keybinds` (or `/tac keys`) | The key setup window: one-button, AoE and interrupt keys, and Remove |
| `/tac errors` | Show/hide red "not ready" errors while pressing (hidden by default) |
| `/tac test` | Diagnostics: your keys and settings |
| `/tac probe` | What the game lets addons read (run out of combat and in combat) |
| `/tac probe talents` | A read-only report on your talents and the talent window, in a window you can copy from. Changes nothing. |
| `/tac probe locale` | A read-only check of Tactara's spell IDs (used on games in other languages) against your game |
| `/tac probe reminders` | A read-only report on what the trainer, buff (before and after a fight) and supply reminders can see, with each buff's time left. Changes nothing. |
| `/tac debug` | Prints every press, every cast sent and every game error to chat |
| `/tac keydown auto` / `off` | Troubleshooting only: cast on key down (default) or key up |

## Editing and writing rotations

Open `/tac`. Choose a rotation on the left, edit the text and click **Save**. When you edit a built-in rotation, your copy is stored separately, and **Revert** brings back the original. **Show Steps** prints what your text builds at your current level without saving it.

```
name: Warrior - Arms
class: WARRIOR
detect: Mortal Strike      # auto-pick this rotation once you know this spell

[keypress]                 # added to EVERY press
/cast [nocombat,harm,nodead] Charge
/startattack [harm,nodead]
/cast [nostance:1] Battle Stance

[opener]                   # played once at the start of each fight
/cast Bloodrage
    /cast Battle Shout @ifmissing Battle Shout

[loop]                     # repeated for the rest of the fight
3x /cast Mortal Strike     # "3x" = comes up 3 times per cycle, spread out
    /cast Overpower        # indented = fallback if the line above can't be cast
    /cast Slam
1x /cast Rend
2x /cast Heroic Strike

[aoe]                      # used by the AoE button (optional; otherwise it copies [loop])
2x /cast Thunder Clap
2x /cast Cleave
```

- `@ifmissing Buff`: only cast if that buff is missing or about to run out. This is checked out of combat, before each fight.
- `[priority]` section (rotation helper): one spell per line, best first. Live checks: `@missing Buff` (not on you), `@nodebuff Debuff` (your debuff not on the target), `@enemies 3` (at least 3 enemies nearby). If WoW hides what a check needs, that line is skipped.
- `[interrupt]`: interrupts, best first (helper + interrupt key). `[defensive]`: defensives with checks like `@health 30`.
- `@health 35`: only when your health is below 35%.
- `@creature Undead, Demon`: only when the target is one of these (Exorcism, Holy Wrath).
- `@nopet`: only when your pet is missing or dead (Call Pet, summons).
- `@combo 4`: only with at least 4 combo points (the game's number if it shows it, otherwise Tactara's count of your builders).
- `prefer: Talent, Talent`: when two rotations use the same talent tree (Druid Cat and Bear), auto-pick takes the one whose talents you have more of.
- `tree: Arms` and `weapon: two-hand` / `dual` / `shield` tell auto-pick when to choose your rotation.
- `@if Spell` / `@unless Spell`: only include the line if you do or don't know that spell, e.g. `@unless Whirlwind`.
- Anything WoW macros accept also works here: `[conditions]`, `/startattack`, `/use`, and so on.
- Lines starting with `#` are comments.

## Sharing and updating

- **Export:** select the rotation, click **Select All**, then press Ctrl+C. Paste it anywhere.
- **Import:** click **New / Import**, delete the template, paste the rotation and click **Save**.
- **New built-in rotations** (for example when the guides change): replace `Rotations\Warrior.lua` with the newer file. Your own edits are kept. Click **Revert** on an edited rotation to switch to the new built-in.

## If something doesn't work

1. Type `/tac test` and check that your key shows under **Tactara keys** (or next to **Main key binding** if you set it in WoW's menu).
2. Type `/tac debug`, target a mob and press the button a few times. Each press shows up in chat as `key down: step N -> ...`, followed by `cast sent` or a `game error` such as *Not enough rage*.
   - Errors like *Not enough rage* or *Out of range* mean the addon is working and the game is saying no. At very low level you start fights with 0 rage, so the first few presses can't cast anything.
   - If presses show up but there's no cast and no error, send me what `/tac test` prints.
3. Type `/tac debug` again to turn the messages off.

## Limits

- If you get Lua errors, type `/console scriptErrors 1` to show them and send the error text.
- WoW Forever hides cooldowns, procs and buffs from addons during combat. The Tactara key plays a fixed sequence with fallbacks instead of reacting, so some presses won't cast anything. That's normal.
- **Games in other languages:** rotations and talent builds are written in English, and Tactara finds each spell's name in your game's language by its spell ID, so they work on German, French, Spanish and other clients too. Rotations you write yourself can use English names or your game's names. Tactara's own windows and messages stay in English. A handful of spells have no ID yet (Faerie Fire (Feral) for Druids); on another language those lines are skipped. `/tac probe locale` checks the IDs against your game.
- A rotation step can hold about 255 characters, and spell names in some languages are longer, so a long step may get cut off there.
- Stance numbers assume 1 = Battle, 2 = Defensive, 3 = Berserker. If you skipped the Defensive Stance quest, Berserker becomes stance 2. Edit the `nostance:` numbers if that applies to you.
- A step longer than 255 characters may get cut off. The editor warns you if that happens.

## License

Copyright (C) 2026 Zudryx. Tactara is free software under the GNU General Public License v3 only (see `LICENSE.txt`). The name "Tactara" and its logo aren't covered by the license: a changed version you share needs its own name and logo (see `NOTICE.md`). Source code: https://github.com/Zudryx/Tactara
