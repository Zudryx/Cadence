#!/usr/bin/env python3
# Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
# SPDX-License-Identifier: GPL-3.0-only
"""Copy the newest CHANGELOG.md sections into Tactara/WhatsNew.lua.

  python3 tests/make_whats_new.py

The "what's new" window in the game reads WhatsNew.lua (an addon can't read
CHANGELOG.md). Run this after editing the changelog; the tests fail when the
two don't match.
"""
import os, re

KEEP = 3   # sections in the game: this version and the two before it
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def sections(text):
    out, cur = [], None
    for line in text.splitlines():
        m = re.match(r"^## (\d+\.\d+\.\d+)\s*$", line)
        if m:
            cur = (m.group(1), [])
            out.append(cur)
        elif cur is not None and line.strip():
            cur[1].append(line.rstrip())
    return out

def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

def render():
    secs = sections(open(os.path.join(root, "CHANGELOG.md"), encoding="utf-8").read())[:KEEP]
    L = [
        "-- Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.",
        "-- SPDX-License-Identifier: GPL-3.0-only",
        "",
        "-- Tactara: the newest changelog sections, for the \"what's new\" window.",
        "-- Made from CHANGELOG.md by tests/make_whats_new.py: edit the changelog,",
        "-- then run that script. Don't edit this file by hand.",
        "",
        "local ADDON, ns = ...",
        "",
        "ns.WHATS_NEW = {",
    ]
    for version, lines in secs:
        L.append("  { version = %s, lines = {" % lua_string(version))
        for line in lines:
            L.append("    %s," % lua_string(line))
        L.append("  } },")
    L.append("}")
    return "\n".join(L) + "\n"

if __name__ == "__main__":
    path = os.path.join(root, "Tactara", "WhatsNew.lua")
    open(path, "w", encoding="utf-8").write(render())
    print("wrote", path)
