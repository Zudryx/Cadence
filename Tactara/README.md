# Tactara 0.7.1: one-button rotations and a rotation helper for WoW Forever

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
  - **Key bar:** what your Tactara key will cast on its next 3 presses.
  - **Helper popup:** the best skill to use right now, plus what comes after. A red **INTERRUPT** slot and an orange **DEFENSIVE** slot appear only when needed. Each icon shows its keybind from your action bars.
  - `/tac hide key` or `/tac hide helper` if you only want one.
- **Which rotation:** Tactara reads your build and picks for you: first the talent tree you've spent the most points in, then your weapons (for a Warrior: two-hander = Arms, dual wield = Fury, shield = Protection), then a sensible default for your class. Druids with points in Feral get Cat or Bear depending on the talents they took. `/tac build` shows what it detected and why it picked what it did. To change it, use `/tac use` with part of the name (`/tac use prot`, `/tac use bear`, `/tac use fire`), or **Use This** in the editor. `/tac use auto` goes back to automatic.
- When you learn new spells, the rotation updates on its own and prints *Added to your rotation: ...*. New spells are **bought from your class trainer** (a Warrior gets Rend and Charge at 4, Thunder Clap at 6, ...). Leveling up alone doesn't add them. `/tac spells` shows what's in use and what's still to learn.

## Settings

Everything below can be changed on one page: **Esc > Options > AddOns > Tactara**, or type `/tac options`, or click **Settings** in the `/tac` window.

- **Rotation:** automatic (follows your talents) or a fixed one, plus a button to the rotation editor.
- **Keys:** set your one-button, AoE and interrupt keys, give them back, hide the red "not ready" errors.
- **Displays:** show or hide the helper popup and the key bar, change their size (50% to 200%), lock them, or reset them to the middle of the screen.
- **Bar highlight:** on or off, how strong the glow is (with a preview), and whether it follows the best spell or the key's next step.
- **Suggestions:** interrupt and defensive suggestions on or off.

The `/tac` commands still work, and both always show the same settings.

## Rotation helper (bar highlight)

- On by default. Toggle it with `/tac highlight` or the **Bar highlight** button in `/tac`.
- **How loud:** `/tac glow strong` (default: thick border, halo and a tinted icon), `/tac glow normal` or `/tac glow subtle`. `/tac glow test` shows a 3-second preview of all three colors on your bars, even out of combat.
- **Best skill next:** each rotation has a **priority list** built from the Forever guides. At any moment the glow shows the highest spell that's ready: Battle Shout if it's missing, AoE spells when 2-3+ enemies are nearby, Overpower when it procs, Rend when it's not on the target, and so on. The strip shows the top 3.
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
| `/tac interrupts` / `/tac defensives` | Red interrupt / orange defensive suggestions on or off |
| `/tac reset` | Restart from the opener |
| `/tac errors` | Show/hide red "not ready" errors while pressing (hidden by default) |
| `/tac test` | Diagnostics: your keys and settings |
| `/tac probe` | What the game lets addons read (run out of combat and in combat) |
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
- Spell names are in English, so non-English game clients need translated rotations.
- Stance numbers assume 1 = Battle, 2 = Defensive, 3 = Berserker. If you skipped the Defensive Stance quest, Berserker becomes stance 2. Edit the `nostance:` numbers if that applies to you.
- A step longer than 255 characters may get cut off. The editor warns you if that happens.
