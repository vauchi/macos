#!/bin/bash
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copies the PNG attachments of an xcresult to <outdir>/<test>/<name>.png.
#
# The UI test runner on the macOS CI host is sandboxed and cannot write
# outside its container, so ScreenshotWalkUITests' direct writes fail
# there (job 16451601571). The attachments it keeps in the xcresult are
# the copy that survives; `xcresulttool export attachments` writes them
# under UUID names and lists the human names in manifest.json, which is
# what the rename below reads.
set -euo pipefail

xcresult="${1:?usage: $0 <xcresult> <outdir>}"
outdir="${2:?usage: $0 <xcresult> <outdir>}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

xcrun xcresulttool export attachments --path "$xcresult" --output-path "$tmp"

python3 - "$tmp" "$outdir" <<'PY'
import json
import os
import re
import shutil
import sys

src, out = sys.argv[1], sys.argv[2]
with open(os.path.join(src, "manifest.json"), encoding="utf-8") as handle:
    manifest = json.load(handle)

count = 0
for entry in manifest:
    # "ScreenshotWalkUITests/test1OnboardingFlow()" -> "onboarding-flow",
    # the same folder the test itself would have written to.
    method = entry["testIdentifier"].split("/")[-1].rstrip("()")
    stem = re.sub(r"^test[0-9]*", "", method)
    folder = re.sub(r"(?<!^)(?=[A-Z])", "-", stem).lower()
    for attachment in entry["attachments"]:
        # xcresulttool suffixes every name with `_<n>_<UUID>`.
        name = re.sub(
            r"_[0-9]+_[0-9A-F-]{36}(\.png)$",
            r"\1",
            attachment["suggestedHumanReadableName"],
        )
        if not name.endswith(".png"):
            continue
        dest = os.path.join(out, folder, name)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copyfile(os.path.join(src, attachment["exportedFileName"]), dest)
        count += 1
print(f"exported {count} screenshot attachment(s) to {out}")
PY
