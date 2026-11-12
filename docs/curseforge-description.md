Tactara puts your rotation on one key, or highlights the next spell on your action bars so you can press it yourself. It covers every class and spec in **WoW Forever** and grows with you from level 1 to 60.

## Two ways to play

- **One-button key:** each press of your Tactara key casts the next step of your rotation. Bind it with `/tac bind` to any key, even one your action bar already uses. Your saved keybinds aren't changed, and `/tac unbind` gives the key back.
- **Rotation helper:** press your own spells. A glow on your action bars and a small popup show the best spell to use right now, and move on as you cast. Interrupts light up red and defensives orange, but only when you need them.

You can use both at once.

## Grows with your level

- Spells you haven't learned are skipped, so the same rotation works at level 5 and at 60. When you train a new spell, it's added to your rotation automatically.
- Tactara reads your talents and weapons and picks the right spec for you. `/tac use` picks one yourself.

## Every class and spec

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

Rotations are built from the WoW Forever class guides and include Forever's new spells. Healing specs get the solo damage rotation you level with. Healing your group stays in your hands, and self-heals still show up as suggestions when you're hurt.

## Make it yours

- **Rotation editor:** `/tac` opens an in-game editor. Change any rotation, write your own, and share it as plain text.
- **Talent planner:** `/tac talents` shows your talent trees with a build point by point, level 10 to 60. Follow Tactara's build (Warrior for now, more classes coming) or make your own, share it as text, and learn the next point with one click, or let Tactara learn it when you level up. The next talent also glows in your talent window.
- **Minimap button:** left-click opens the editor, right-click opens the settings page and shift-click the talent planner. Drag it anywhere around the minimap, or hide it.
- **Settings page:** Esc > Options > AddOns > Tactara, or `/tac options`.
  - Your keys: one-button, AoE and interrupt.
  - Displays: size, how many icons (1 to 10, or the whole rotation), and normal, see-through or hidden between fights.
  - The bar glow: on or off, and how strong.
  - Interrupt and defensive suggestions: on or off.
- **Helper icons work like action buttons:** each shows its keybind and a cooldown sweep. It turns red when your target is out of range, blue when you're short on mana, rage or energy, and grey when it can't be used.
- **Works with your bars:** the glow works on Blizzard's action bars and the popular action bar addons, and with spells inside your own macros. It only draws on top of your buttons and never changes them.

## Getting started

1. Install Tactara and log in, or type `/reload`.
2. Type `/tac bind` and press the key you want to use.
3. Press that key in combat, or follow the glow on your bars.

`/tac help` lists every command.

## Fair play

Tactara is an assistant, not a bot.

- **You press every key.** Each press of the Tactara key does what one press of a normal macro does. WoW only lets addons cast when you press a key or click, so Tactara can't cast by itself or repeat presses.
- **The rotation is set before the fight.** WoW locks addon buttons in combat, so the key steps through a list you can read with `/tac steps`. It can't react to the fight on its own.
- **The helper only points.** It shows you a spell. Using it is up to you.
- **Nothing outside the game controls it.** Tactara runs only inside WoW's addon system. It doesn't move, target or click for you.

Use one key press per cast. Turbo keys, key repeaters and programs that press keys for you break Blizzard's rules whatever addon you use.

## Good to know

- WoW Forever hides some things from addons, like your rage, your target's health and some buffs. Tactara works around this with its own timers and by checking whether each spell can be cast right now. In boss fights and arenas, where the game hides even more, the helper follows the rotation order.
- AoE suggestions need **enemy nameplates** turned on.
- Ground-targeted spells, such as Blizzard or Rain of Fire, need you to aim, so only the helper suggests them.

## Feedback and source

Tactara is free and open source under the GNU GPL v3. Report bugs, suggest rotation changes or read the code on GitHub: https://github.com/Zudryx/Tactara

The license covers the code, not the name or logo: a changed version you share needs its own name and logo.

Tactara is a fan-made project. It isn't made, endorsed or supported by Blizzard Entertainment. World of Warcraft is a trademark of Blizzard Entertainment, Inc.
