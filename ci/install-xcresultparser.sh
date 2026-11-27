#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Usage: install-xcresultparser.sh VERSION SHA256 [DESTINATION]

set -euo pipefail

version="${1:?expected release version}"
digest="${2:?expected release SHA256}"
destination="${3:-/opt/homebrew/bin/xcresultparser}"
download=$(mktemp "${destination}.XXXXXX")
trap 'rm -f "$download"' EXIT
trap 'exit 1' HUP INT TERM

curl -fsSL --retry 3 --output "$download" \
    "https://github.com/a7ex/xcresultparser/releases/download/${version}/xcresultparser"
printf '%s  %s\n' "$digest" "$download" | shasum -a 256 -c -
chmod 755 "$download"
actual=$("$download" --version)
if [ "$actual" != "$version" ]; then
    printf 'ERROR: xcresultparser expected %s, got %s\n' "$version" "$actual" >&2
    exit 1
fi
mv -f "$download" "$destination"
printf 'Installed xcresultparser %s\n' "$actual"
