#!/usr/bin/env python3
# Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
# SPDX-License-Identifier: GPL-3.0-only
"""Turn a /tac probe talents report into a test fixture.

  python3 tests/make_talent_fixture.py probe.txt
writes tests/talent_fixtures/<class>.lua with every talent the game reported
(id, x, y, rank, max, name, spell id, arrows to), exactly as the game gave
them, odd positions included.
"""
import os, re, sys

src = open(sys.argv[1], encoding="utf-8").read()
cls = re.search(r"interface \d+, (\w+) level (\d+)", src)
build = re.search(r"game [\d.]+ \((\d+)\)", src)
rows = re.findall(r"^n(\d+) sub(\d+) x(-?\d+) y(-?\d+) (\d+)/(\d+) type\d+ \[[^\]]*\] (.+?) spell(\d+|nil) cond\[[^\]]*\] ->\[([^\]]*)\]", src, re.M)
if not cls or not rows:
    sys.exit("That doesn't look like a /tac probe talents report.")
name = cls.group(1).lower()
out = [
    "-- The real %s talent tree from WoW Forever (game build %s), as read by" % (cls.group(1).title(), build.group(1) if build else "?"),
    "-- /tac probe talents on a level %s %s. Made by tests/make_talent_fixture.py." % (cls.group(2), cls.group(1).title()),
    "-- id, x, y, rank, max, name, spell id, arrows to.",
    "return {",
    '  class = "%s",' % cls.group(1),
]
for nid, sub, x, y, rank, mx, tname, spell, edges in rows:
    e = ", ".join(t for t in edges.split(",") if t)
    out.append('  { id = %s, x = %s, y = %s, rank = %s, max = %s, name = "%s", spell = %s, to = { %s } },'
               % (nid, x, y, rank, mx, tname.replace('"', '\\"'), spell if spell != "nil" else "nil", e))
out.append("}")
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "talent_fixtures", name + ".lua")
open(path, "w", encoding="utf-8").write("\n".join(out) + "\n")
print("%s: %d talents -> %s" % (cls.group(1), len(rows), path))
