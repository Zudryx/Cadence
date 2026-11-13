#!/usr/bin/env python3
# Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
# SPDX-License-Identifier: GPL-3.0-only
"""Write Tactara/SpellIDs.lua: the spell ID behind each English spell and
talent name Tactara uses, so it works on game clients in other languages.

  python3 tests/make_spell_ids.py

Spells come from tests/spell_ids/icy_veins.json (the spell links on the Icy
Veins WoW Forever class guides, one table per class, plus "_extra" for the
few found in their spell database by hand). Talents come from the real trees
in tests/talent_fixtures/<class>.lua. /tac probe locale checks every ID
against the game.
"""
import json, os, re

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLASSES = ["warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid"]
EXTRA_CLASS = {
    "Aspect of the Monkey": "hunter", "Call Pet": "hunter", "Aspect of the Wild": "hunter",
    "Scorpid Sting": "hunter", "Counterattack": "hunter",
    "Frenzied Regeneration": "druid", "Berserk": "druid", "Mangle": "druid",
    "Wound Poison": "rogue", "Mind-numbing Poison": "rogue",
    "Templar's Bulwark": "paladin",
}

# Corrections from /tac probe locale on a live game (November 2026). The Icy
# Veins pages link a few spells by an old ID or an old name; these win over
# the JSON, so refreshing it from the pages doesn't bring them back.
OVERRIDE = {
    # the talent itself is the charge in Forever (Cat and Bear); 16979 is the
    # old Bear-only spell, called "Feral Charge (Bear)" in the game
    "druid": {"Feral Charge": 1238122},
}
DROP = {
    "warrior": ["Raging Blows"],                # 1310315 is the talent Improved Whirlwind
    "rogue": ["Improved Sinister Strike"],      # 13732 is the talent Efficient Strikes
    "mage": ["Polymorph: Pig"],                 # 28285 teaches it; the pig spell is named "Polymorph"
    "paladin": ["Blessing of Light", "Blessing of Salvation"],   # not in WoW Forever
}

def q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

def talents(cls):
    path = os.path.join(root, "tests", "talent_fixtures", cls + ".lua")
    if not os.path.exists(path): return {}
    out = {}
    for name, spell in re.findall(r'name = "((?:[^"\\]|\\.)*)", spell = (\d+)', open(path, encoding="utf-8").read()):
        out.setdefault(name.replace('\\"', '"'), int(spell))
    return out

def render():
    data = json.load(open(os.path.join(root, "tests", "spell_ids", "icy_veins.json"), encoding="utf-8"))
    spells = {c: dict(data.get(c, {})) for c in CLASSES}
    for name, sid in data.get("_extra", {}).items():
        spells[EXTRA_CLASS[name]].setdefault(name, sid)
    for c, names in DROP.items():
        for name in names:
            spells[c].pop(name, None)
    for c, fixed in OVERRIDE.items():
        spells[c].update(fixed)
    L = [
        "-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.",
        "-- SPDX-License-Identifier: GPL-3.0-only",
        "",
        "-- Tactara: the spell ID behind each English spell and talent name it uses,",
        "-- so rotations and talent builds work on game clients in other languages.",
        "-- Made by tests/make_spell_ids.py; don't edit by hand.",
        "",
        "local ADDON, ns = ...",
        "",
        "ns.SPELL_IDS = {",
    ]
    for c in CLASSES:
        L.append("  %s = {" % c.upper())
        for name in sorted(spells[c]):
            L.append("    [%s] = %d," % (q(name), spells[c][name]))
        L.append("  },")
    L.append("}")
    L.append("")
    L.append("ns.TALENT_IDS = {")
    for c in CLASSES:
        t = talents(c)
        L.append("  %s = {" % c.upper())
        for name in sorted(t):
            L.append("    [%s] = %d," % (q(name), t[name]))
        L.append("  },")
    L.append("}")
    return "\n".join(L) + "\n"

if __name__ == "__main__":
    path = os.path.join(root, "Tactara", "SpellIDs.lua")
    open(path, "w", encoding="utf-8").write(render())
    print("wrote", path)
