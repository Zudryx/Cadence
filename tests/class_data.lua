-- Test data: which spells each class knows at each level in WoW Forever,
-- which come from talents, and which only work in special situations.
-- Levels follow the Forever trainer lists (Warcraft Tavern leveling guides);
-- where a guide doesn't list a spell, the Classic level is used. The addon
-- itself never relies on these numbers: in game it reads your spellbook.

local D = {}

-- class -> { {level, spell}, ... }  (trained or quest spells every spec gets)
D.BY_LEVEL = {
  WARRIOR = {
    {1, "Battle Stance"}, {1, "Battle Shout"}, {1, "Heroic Strike"},
    {4, "Rend"}, {4, "Charge"}, {6, "Thunder Clap"}, {8, "Hamstring"},
    {10, "Defensive Stance"}, {10, "Bloodrage"}, {10, "Taunt"}, {10, "Sunder Armor"},
    {12, "Overpower"}, {12, "Shield Bash"}, {14, "Revenge"}, {14, "Demoralizing Shout"},
    {16, "Shield Block"}, {20, "Victory Rush"}, {20, "Cleave"}, {20, "Slam"}, {20, "Retaliation"},
    {20, "Intimidating Shout"}, {24, "Execute"}, {26, "Challenging Shout"}, {28, "Shield Wall"},
    {30, "Berserker Stance"}, {30, "Intercept"}, {32, "Berserker Rage"}, {36, "Whirlwind"},
    {38, "Pummel"}, {40, "Disarm"}
  },
  PALADIN = {
    {1, "Seal of Righteousness"}, {1, "Holy Light"}, {1, "Devotion Aura"},
    {4, "Blessing of Might"}, {4, "Judgement"}, {6, "Divine Protection"}, {6, "Holy Strike"},
    {8, "Hammer of Justice"}, {10, "Blessing of Protection"}, {10, "Lay on Hands"}, {10, "Seal of Fury"},
    {14, "Blessing of Wisdom"}, {16, "Retribution Aura"}, {16, "Righteous Fury"},
    {20, "Blessing of Kings"}, {20, "Consecration"}, {20, "Exorcism"}, {20, "Flash of Light"},
    {22, "Concentration Aura"}, {30, "Seal of Light"}, {32, "Divine Shield"}, {38, "Seal of Wisdom"},
    {44, "Hammer of Wrath"}, {50, "Holy Wrath"},
  },
  -- warcraft.wiki.gg "Hunter abilities (Forever)"
  HUNTER = {
    {1, "Auto Shot"}, {1, "Raptor Strike"}, {4, "Aspect of the Monkey"}, {4, "Serpent Sting"},
    {6, "Arcane Shot"}, {6, "Hunter's Mark"}, {8, "Concussive Shot"}, {10, "Aspect of the Hawk"},
    {10, "Call Pet"}, {10, "Revive Pet"}, {12, "Mend Pet"}, {12, "Wing Clip"}, {12, "Distracting Shot"},
    {16, "Immolation Trap"}, {16, "Mongoose Bite"}, {18, "Multi-Shot"}, {20, "Aimed Shot"},
    {20, "Disengage"}, {20, "Freezing Trap"}, {20, "Aspect of the Cheetah"}, {22, "Scorpid Sting"},
    {26, "Rapid Fire"}, {28, "Frost Trap"}, {30, "Feign Death"}, {30, "Aspect of the Beast"},
    {34, "Explosive Trap"}, {36, "Viper Sting"}, {40, "Volley"}, {40, "Aspect of the Pack"},
    {46, "Aspect of the Wild"},
  },
  -- warcraft.wiki.gg "Rogue abilities (Forever)"
  ROGUE = {
    {1, "Eviscerate"}, {1, "Sinister Strike"}, {1, "Stealth"}, {4, "Backstab"}, {6, "Gouge"},
    {8, "Evasion"}, {10, "Slice and Dice"}, {10, "Sprint"}, {10, "Sap"}, {12, "Kick"},
    {14, "Expose Armor"}, {14, "Garrote"}, {16, "Feint"}, {18, "Ambush"}, {20, "Rupture"},
    {22, "Vanish"}, {22, "Distract"}, {24, "Shank"}, {26, "Cheap Shot"}, {30, "Kidney Shot"}, {34, "Blind"},
  },
  -- Classic trainer levels plus Blizzard's Forever deep dive (Devouring Plague,
  -- Fear Ward, Divine Spirit, Shadow Word: Death). Desperate Prayer is a racial.
  PRIEST = {
    {1, "Smite"}, {1, "Lesser Heal"}, {1, "Power Word: Fortitude"}, {4, "Shadow Word: Pain"},
    {6, "Power Word: Shield"}, {8, "Fade"}, {8, "Renew"}, {10, "Mind Blast"}, {10, "Desperate Prayer"},
    {12, "Inner Fire"}, {14, "Psychic Scream"}, {16, "Heal"}, {20, "Flash Heal"}, {20, "Holy Fire"},
    {20, "Devouring Plague"}, {20, "Fear Ward"}, {24, "Mana Burn"}, {30, "Divine Spirit"},
    {30, "Prayer of Healing"}, {32, "Shadow Word: Death"}, {40, "Greater Heal"},
  },
  -- Classic trainer levels plus Blizzard's Forever deep dive (Fire Nova spell,
  -- Totemic Recall, Totemic Projection, Call of the Elements/Spirits/Ancestors).
  SHAMAN = {
    {1, "Lightning Bolt"}, {1, "Rockbiter Weapon"}, {1, "Healing Wave"}, {4, "Earth Shock"},
    {4, "Stoneskin Totem"}, {6, "Earthbind Totem"}, {8, "Lightning Shield"}, {10, "Flame Shock"},
    {10, "Flametongue Weapon"}, {10, "Searing Totem"}, {10, "Strength of Earth Totem"}, {12, "Purge"},
    {12, "Fire Nova"}, {18, "Tremor Totem"}, {20, "Ghost Wolf"}, {20, "Frost Shock"},
    {20, "Frostbrand Weapon"}, {20, "Lesser Healing Wave"}, {20, "Healing Stream Totem"},
    {20, "Totemic Recall"}, {20, "Call of the Elements"}, {22, "Totemic Projection"},
    {26, "Magma Totem"}, {26, "Mana Spring Totem"}, {30, "Windfury Weapon"}, {30, "Grounding Totem"},
    {32, "Chain Lightning"}, {32, "Windfury Totem"}, {40, "Chain Heal"}, {42, "Grace of Air Totem"},
  },
  -- Warcraft Tavern Forever Mage leveling guide (Cone of Cold: Classic level)
  MAGE = {
    {1, "Fireball"}, {1, "Frost Armor"}, {1, "Arcane Intellect"}, {4, "Frostbolt"}, {6, "Fire Blast"},
    {8, "Polymorph"}, {8, "Arcane Missiles"}, {10, "Frost Nova"}, {14, "Arcane Explosion"},
    {16, "Flamestrike"}, {20, "Blizzard"}, {20, "Mana Shield"}, {20, "Blink"}, {20, "Evocation"},
    {22, "Scorch"}, {24, "Counterspell"}, {26, "Cone of Cold"}, {30, "Ice Armor"}, {34, "Mage Armor"},
    {40, "Frostfire Bolt"},
  },
  -- Classic trainer levels; Curse of Agony is Bane of Agony in Forever
  WARLOCK = {
    {1, "Shadow Bolt"}, {1, "Demon Skin"}, {1, "Summon Imp"}, {4, "Immolate"}, {4, "Corruption"},
    {6, "Life Tap"}, {6, "Curse of Weakness"}, {8, "Bane of Agony"}, {8, "Fear"}, {10, "Drain Soul"},
    {10, "Summon Voidwalker"}, {12, "Health Funnel"}, {14, "Drain Life"}, {18, "Searing Pain"},
    {20, "Rain of Fire"}, {20, "Summon Succubus"}, {20, "Demon Armor"}, {30, "Hellfire"},
    {30, "Summon Felhunter"}, {32, "Curse of the Elements"}, {42, "Death Coil"}, {48, "Soul Fire"},
    {60, "Bane of Doom"},
  },
  -- Classic trainer levels plus Blizzard's Forever deep dive (Revive 12,
  -- Omen of Clarity 20, Lacerate 42, Faerie Fire (Feral) baseline with forms)
  DRUID = {
    {1, "Wrath"}, {1, "Healing Touch"}, {1, "Mark of the Wild"}, {4, "Moonfire"}, {4, "Rejuvenation"},
    {6, "Thorns"}, {8, "Entangling Roots"}, {10, "Bear Form"}, {10, "Maul"}, {10, "Growl"},
    {10, "Demoralizing Roar"}, {10, "Nature's Grasp"}, {10, "Faerie Fire (Feral)"}, {12, "Regrowth"},
    {12, "Enrage"}, {14, "Bash"}, {16, "Swipe"}, {18, "Faerie Fire"}, {18, "Hibernate"},
    {20, "Cat Form"}, {20, "Claw"}, {20, "Rip"}, {20, "Starfire"}, {20, "Omen of Clarity"},
    {22, "Shred"}, {24, "Rake"}, {26, "Dash"}, {30, "Tranquility"}, {32, "Ferocious Bite"},
    {36, "Frenzied Regeneration"}, {40, "Dire Bear Form"}, {40, "Hurricane"}, {42, "Lacerate"}, {44, "Barkskin"},
  },
}

-- spec -> { {level, talent spell}, ... }  (talent points start at 10)
D.TALENTS = {
  arms = { {30, "Sweeping Strikes"}, {40, "Mortal Strike"} },
  fury = { {40, "Bloodthirst"} },
  prot = { {30, "Last Stand"}, {40, "Shield Slam"}, {30, "Concussion Blow"} },
  ret = { {20, "Seal of Command"}, {25, "Sacred Arbiter"}, {30, "Repentance"}, {40, "Twist of Light"} },
  protpal = { {20, "Improved Seal of Fury"}, {25, "Swift Judgement"}, {30, "Templar's Bulwark"}, {35, "Holy Shield"} },
  holypal = { {20, "Voice of Truth"}, {25, "Divine Favor"}, {30, "Holy Shock"}, {40, "Light's Vigil"} },
  -- talent tiers: T1 = level 10, T2 = 15, ... T7 = 40
  bm = { {25, "Summon Hawk"}, {30, "Intimidation"}, {40, "Bestial Wrath"} },
  mm = { {20, "Lone Wolf"}, {25, "Trueshot Aura"}, {30, "Scatter Shot"}, {40, "Sniper Shot"} },
  sv = { {20, "Deterrence"}, {25, "Counterattack"}, {30, "Strider Kick"}, {30, "Expose Prey"}, {40, "Lacerating Strikes"} },
  assa = { {25, "Cold Blood"}, {30, "Venom"}, {35, "Seal Fate"}, {40, "Mutilate"} },
  combat = { {20, "Riposte"}, {30, "Blade Flurry"}, {40, "Adrenaline Rush"} },
  sub = { {20, "Premeditation"}, {25, "Ghostly Strike"}, {30, "Preparation"}, {30, "Hemorrhage"}, {40, "Death Mark"} },
  shadow = { {20, "Mind Flay"}, {25, "Vampiric Embrace"}, {30, "Silence"}, {40, "Shadowform"} },
  disc = { {30, "Penance"} },
  holypri = { {20, "Holy Nova"}, {25, "Binding Heal"}, {40, "Prayer of Mending"} },
  ele = { {15, "Elemental Alacrity"}, {25, "Call of Thunder"}, {30, "Earthbound"}, {30, "Lightning Overload"}, {40, "Lava Burst"} },
  enh = { {20, "Shamanistic Focus"}, {25, "Stormstrike"}, {35, "Maelstrom Weapon"}, {40, "Rage of the Farseer"} },
  resto = { {20, "Water Shield"}, {25, "Mana Tide Totem"}, {40, "Riptide"} },
  frost = { {20, "Ice Lance"}, {25, "Ice Block"}, {30, "Cold Snap"}, {30, "Fingers of Frost"}, {40, "Ice Barrier"} },
  fire = { {20, "Pyroblast"}, {25, "Heating Up"}, {30, "Blast Wave"}, {40, "Combustion"} },
  arcane = { {15, "Missile Barrage"}, {20, "Arcane Blast"}, {25, "Arcane Wrath"}, {30, "Presence of Mind"}, {40, "Arcane Power"} },
  affli = { {30, "Siphon Life"}, {40, "Wrack"} },
  demo = { {20, "Fel Domination"}, {30, "Demonic Sacrifice"}, {40, "Demonic Pact"} },
  destro = { {20, "Shadowburn"}, {30, "Conflagrate"}, {30, "Bane of Havoc"}, {40, "Incinerate"} },
  cat = { {20, "Feral Charge"}, {25, "Shifting Power"}, {40, "Berserk"} },
  bear = { {20, "Feral Charge"}, {25, "Primal Bite"}, {35, "Natural Reaction"}, {40, "Berserk"} },
  balance = { {25, "Insect Swarm"}, {30, "Eclipse"}, {40, "Moonkin Form"} },
  restodru = { {25, "Swiftmend"}, {40, "Wild Growth"} },
}

-- rotation name -> spec key
D.SPEC_OF = {
  ["Warrior - Arms"] = "arms", ["Warrior - Fury"] = "fury", ["Warrior - Protection"] = "prot",
  ["Paladin - Retribution"] = "ret", ["Paladin - Protection"] = "protpal", ["Paladin - Holy"] = "holypal",
  ["Hunter - Beast Mastery"] = "bm", ["Hunter - Marksmanship"] = "mm", ["Hunter - Survival"] = "sv",
  ["Rogue - Combat"] = "combat", ["Rogue - Assassination"] = "assa", ["Rogue - Subtlety"] = "sub",
  ["Priest - Shadow"] = "shadow", ["Priest - Discipline"] = "disc", ["Priest - Holy"] = "holypri",
  ["Shaman - Enhancement"] = "enh", ["Shaman - Elemental"] = "ele", ["Shaman - Restoration"] = "resto",
  ["Mage - Frost"] = "frost", ["Mage - Fire"] = "fire", ["Mage - Arcane"] = "arcane",
  ["Warlock - Affliction"] = "affli", ["Warlock - Demonology"] = "demo", ["Warlock - Destruction"] = "destro",
  ["Druid - Feral (Cat)"] = "cat", ["Druid - Feral (Bear)"] = "bear", ["Druid - Balance"] = "balance",
  ["Druid - Restoration"] = "restodru",
}

-- Spells that only work in special situations (low target health, a proc,
-- a creature type, combo points...). A key step made only of these would
-- do nothing most of the time.
D.CONDITIONAL = {
  WARRIOR = { Execute = true, Overpower = true, Revenge = true, ["Victory Rush"] = true },
  PALADIN = { ["Hammer of Wrath"] = true, Exorcism = true, ["Holy Wrath"] = true },
  HUNTER = { ["Mongoose Bite"] = true, Counterattack = true },
  ROGUE = { Riposte = true, Eviscerate = true, ["Slice and Dice"] = true, Rupture = true, Venom = true,
    ["Kidney Shot"] = true, ["Expose Armor"] = true, Ambush = true, Garrote = true, ["Cheap Shot"] = true },
  SHAMAN = { ["Fire Nova"] = true },
  DRUID = { Rip = true, ["Ferocious Bite"] = true, Shred = true },
}

-- Buffs and debuffs checked by name that aren't spells of the same name.
D.BUFFS = {}

-- Pet abilities (cast through the pet, but usable from macros).
D.PET = {
  WARLOCK = { ["Spell Lock"] = true },
}

-- Names allowed in rotations without being class spells (items, wands, macros).
D.ANY_CLASS = { Shoot = true, ["Auto Shot"] = true, Attack = true }

return D
