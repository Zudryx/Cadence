#!/usr/bin/env python3
# Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
# SPDX-License-Identifier: GPL-3.0-only
"""Upload a Tactara release zip to CurseForge.

Used by .github/workflows/release.yml. Needs the CF_API_KEY environment
variable (a CurseForge API token, stored as a GitHub secret).

The game version is worked out from "## Interface:" in the .toc file:
16001 -> 1.60.1, matched against CurseForge's WoW Forever versions.

  python3 curseforge_upload.py --toc Tactara/Tactara.toc \
      --file Tactara-1.2.3.zip --version 1.2.3 --changelog notes.md

--dry-run with --versions-json/--types-json checks everything except the
upload, using saved copies of the API's answers (for testing).
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

API = os.environ.get("CF_API_URL", "https://wow.curseforge.com/api")   # override only for tests
FOREVER_TYPE_ID = 88568          # CurseForge's "WoW Forever" version type


def toc_value(toc_text, key):
    m = re.search(r"^##\s*" + re.escape(key) + r"\s*:\s*(.+?)\s*$", toc_text, re.M)
    return m.group(1) if m else None


def interface_to_version(interface):
    """16001 -> "1.60.1", 110207 -> "11.2.7"."""
    n = int(interface)
    return "%d.%d.%d" % (n // 10000, (n // 100) % 100, n % 100)


def get_json(path, token):
    req = urllib.request.Request(API + path, headers={"X-Api-Token": token, "User-Agent": "Tactara-release"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def forever_type_ids(types):
    ids = {FOREVER_TYPE_ID}
    for t in types or []:
        label = (str(t.get("name", "")) + " " + str(t.get("slug", ""))).lower()
        if "forever" in label or "camelot" in label:
            ids.add(t["id"])
    return ids


def pick_versions(wanted_names, versions, type_ids):
    """CurseForge version ids for the wanted names, Forever types only.
    Falls back to the newest Forever version if a name isn't listed yet."""
    forever = [v for v in versions if v.get("gameVersionTypeID") in type_ids]
    if not forever:
        raise SystemExit("CurseForge lists no WoW Forever game versions (version type %s)." % sorted(type_ids))
    ids, notes = [], []
    for name in wanted_names:
        match = [v for v in forever if v.get("name") == name]
        if match:
            ids.append(match[0]["id"])
        else:
            newest = max(forever, key=lambda v: v["id"])
            ids.append(newest["id"])
            notes.append("Game version %s isn't on CurseForge yet; using the newest Forever version, %s."
                         % (name, newest.get("name")))
    return sorted(set(ids)), notes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--toc", required=True)
    ap.add_argument("--file", required=True)
    ap.add_argument("--version", required=True)
    ap.add_argument("--changelog", required=True)
    ap.add_argument("--project", help="defaults to ## X-Curse-Project-ID in the .toc")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--versions-json")
    ap.add_argument("--types-json")
    a = ap.parse_args()

    toc = open(a.toc, encoding="utf-8-sig").read()
    project = a.project or toc_value(toc, "X-Curse-Project-ID")
    if not project or not project.strip().isdigit():
        raise SystemExit("No CurseForge project id (## X-Curse-Project-ID in the .toc).")
    interfaces = [s.strip() for s in (toc_value(toc, "Interface") or "").split(",") if s.strip()]
    if not interfaces:
        raise SystemExit("No ## Interface line in the .toc.")
    wanted = [interface_to_version(i) for i in interfaces]

    token = os.environ.get("CF_API_KEY", "")
    if a.versions_json:
        versions = json.load(open(a.versions_json))
        types = json.load(open(a.types_json)) if a.types_json else []
    else:
        if not token:
            raise SystemExit("CF_API_KEY isn't set.")
        try:
            versions = get_json("/game/versions", token)
        except urllib.error.HTTPError as e:
            hint = " Check the CF_API_KEY secret." if e.code in (401, 403) else ""
            raise SystemExit("CurseForge refused the game version list (HTTP %d).%s" % (e.code, hint))
        except urllib.error.URLError as e:
            raise SystemExit("Couldn't reach CurseForge: %s" % e.reason)
        try:
            types = get_json("/game/version-types", token)
        except Exception as e:             # the version list alone is enough
            print("Couldn't read version types (%s); using type %d." % (e, FOREVER_TYPE_ID))
            types = []

    ids, notes = pick_versions(wanted, versions, forever_type_ids(types))
    for n in notes:
        print("::warning::" + n)

    changelog = open(a.changelog, encoding="utf-8").read().strip() or ("Tactara " + a.version)
    metadata = {
        "changelog": changelog,
        "changelogType": "markdown",
        "displayName": "Tactara " + a.version,
        "gameVersions": ids,
        "releaseType": "release",
    }
    print("CurseForge project %s, game versions %s (%s), file %s"
          % (project, ids, ", ".join(wanted), os.path.basename(a.file)))
    if a.dry_run:
        print(json.dumps(metadata, indent=2))
        return 0

    if not os.path.isfile(a.file):
        raise SystemExit("Missing file: " + a.file)
    # token goes in a header file, not on the command line
    with tempfile.NamedTemporaryFile("w", delete=False) as hf:
        hf.write("X-Api-Token: %s\n" % token)
        header_file = hf.name
    try:
        out = subprocess.run(
            ["curl", "-sS", "-o", "cf_response.json", "-w", "%{http_code}",
             "-H", "@" + header_file,
             "--form-string", "metadata=" + json.dumps(metadata),
             "-F", "file=@" + a.file,
             "%s/projects/%s/upload-file" % (API, project.strip())],
            capture_output=True, text=True)
    finally:
        os.unlink(header_file)
    status = out.stdout.strip()
    body = open("cf_response.json").read() if os.path.exists("cf_response.json") else out.stderr
    if status != "200":
        raise SystemExit("CurseForge upload failed (HTTP %s): %s" % (status or "?", body[:500]))
    print("Uploaded to CurseForge: file id %s" % json.loads(body).get("id"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
