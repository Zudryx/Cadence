Tactara puts your rotation on one key, or highlights the next spell on your action bars so you can press it yourself, and plans your talents level by level. It covers every class and spec in **WoW Forever** and grows with you from level 1 to 60.

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

## Plan your talents

- **Talent planner:** `/tac talents`, or the **Tactara planner** button at the bottom of your talent window, shows your three talent trees with a build laid out point by point from level 10 to 60.
- **Follow Tactara's build or make your own.** Every spec of every class has a recommended leveling build and a level 60 raid and dungeon build, both from Icy Veins and checked point by point against the game's trees. At 60, Tactara asks once whether to look at the level 60 build for your spec. Start a build from scratch, copy one of Tactara's, or start from the talents you already have so there's no need to respec. The planner only lets you add points the game would take.
- **Learn with one click.** **Learn next** and **Learn all** spend your points on the build you picked. You can also have Tactara learn them when you level up (off by default, never in combat). Otherwise you get a reminder, and the next talent glows in your talent window.
- **Dual spec:** each spec keeps its own build and rotation choice, and Tactara switches with you.
- **Your build never changes under you.** When Tactara updates a build you're following, it asks whether to switch or keep your version.
- **Share builds** as text and import other people's.

## Make it yours

- **Rotation editor:** `/tac` opens an in-game editor. Change any rotation, write your own, and share it as plain text.
- **Minimap button:** left-click opens the editor, right-click opens the settings page and shift-click the talent planner. Drag it anywhere around the minimap, or hide it.
- **Settings page:** Esc > Options > AddOns > Tactara, or `/tac options`.
  - Your keys: one-button, AoE and interrupt.
  - Displays: size, how many icons (1 to 10, or the whole rotation), and normal, see-through or hidden between fights.
  - The bar glow: on or off, and how strong.
  - Interrupt and defensive suggestions: on or off, with an optional sound for each.
  - Reminders: before the pull and supplies (each under the helper and in chat, under the helper only, or off), the trainer reminder, first-time questions on new characters, and a "what's new" window after each update.
  - Your characters: copy settings from another character, make them the default for new ones, or export them as text to share and import them anywhere.
  - Talents: learning when you level up, the planner button in your talent window, the glow on the next talent, the one-time question on new characters, and the reminder.
- **Reminders:** when you target an enemy before a fight, Tactara tells you if a buff your rotation keeps up, your pet, or a poison or weapon imbue is missing. After a level-up, it lists the new spells waiting at your class trainer, the ones your rotation uses first. It only tells you; you cast them.
- **Supplies:** a Hunter's arrows or bullets, a Warlock's Soul Shards, and the reagents and totems your spells need (Flash Powder for Vanish, an Ankh, a Fire Totem...), when they run low: under the helper, in chat, and at a vendor that sells them. Tactara never buys anything.
- **Sound alerts:** pick a sound for when the interrupt or defensive slot lights up. Off until you choose one.
- **Helper icons work like action buttons:** each shows its keybind and a cooldown sweep. It turns red when your target is out of range, blue when you're short on mana, rage or energy, and grey when it can't be used.
- **Works with your bars:** the glow works on Blizzard's action bars and the popular action bar addons, and with spells inside your own macros. It only draws on top of your buttons and never changes them.

## Games in other languages

Rotations and talent builds work on German, French, Spanish and other game clients: Tactara finds each spell's name in your language by its ID. Tactara's own windows are in English.

## Getting started

1. Install Tactara and log in, or type `/reload`.
2. Type `/tac bind` and press the key you want to use (Tactara also offers this the first time you play a character).
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
