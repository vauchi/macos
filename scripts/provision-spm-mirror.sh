#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Point xcodebuild at the correct-version file:// vauchi-platform-swift mirror
# and resolve into the project-local .spm-packages, under the host-wide config
# lock — for the read-only test jobs (test:snapshots, test:unit,
# test:snapshots:record).
#
# WHY THIS EXISTS
# --------------
# xcodebuild reads the USER-LEVEL
# ~/Library/org.swift.swiftpm/configuration/mirrors.json — NOT the project-local
# .swiftpm/configuration/mirrors.json (verified; see build:debug §6 in
# .gitlab-ci.yml). That user-level file is shared mutable state across every
# pipeline on the runner. build:debug writes it + resolves under CFGLOCK, but
# the .gitlab-ci.yml comment assumed the read-only test jobs (which pass
# -disableAutomaticPackageResolution) "never read the user-level config" — they
# do. A concurrent ios/macos bump pipeline on a *different* version repoints the
# shared file, and the next test job reads the wrong version and fails
# "Could not resolve package dependencies" (observed: macos on 0.51.55 reading a
# concurrent ios 0.51.58 mirror left in the user-level config).
#
# THE FIX: do what build:debug does — write the correct-version config and
# resolve from the file:// mirror under CFGLOCK, so .spm-packages is populated
# correctly and the subsequent -disableAutomaticPackageResolution test commands
# never depend on whatever version another pipeline last left in the shared
# config. The mirror itself is built by build:debug (a host cache); here we only
# require it to exist.

set -euo pipefail

# Version the project pins (xcodegen reads project.yml).
V=$(grep -A3 'VauchiPlatform:' project.yml | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [ -z "$V" ]; then
    echo "ERROR: could not derive VauchiPlatform version from project.yml" >&2
    exit 1
fi
MIRROR="$HOME/.cache/vauchi-platform-swift-mirror/v$V"
if [ ! -d "$MIRROR" ]; then
    echo "ERROR: mirror $MIRROR missing — build:debug should have built it first" >&2
    exit 1
fi
echo "── provision-spm-mirror: v$V (file://$MIRROR) ──"

MIRROR_JSON=$(printf '%s\n' \
    '{' \
    '  "version": 1,' \
    '  "object": [{' \
    '    "original": "https://gitlab.com/vauchi/vauchi-platform-swift.git",' \
    "    \"mirror\": \"file://$MIRROR\"" \
    '  }]' \
    '}')

# Host-wide config lock — POSIX-atomic mkdir (no flock on macOS). Same path
# build:debug §6 and ios ci-spm-provision.sh use, so the three serialise their
# write→resolve windows: no other pipeline can repoint the shared user-level
# config between our write and our resolve.
CFGLOCK="$HOME/.cache/vauchi-platform-swift-mirror/.cfg-lock"
mkdir -p "$(dirname "$CFGLOCK")"
CFG_WAIT=0
while ! mkdir "$CFGLOCK" 2>/dev/null; do
    if [ "$CFG_WAIT" -ge 600 ]; then
        echo "  Config lock held >600s — treating as stale and reclaiming."
        rmdir "$CFGLOCK" 2>/dev/null || true
        continue
    fi
    echo "  Waiting for config lock at $CFGLOCK (${CFG_WAIT}s)…"
    sleep 5
    CFG_WAIT=$((CFG_WAIT + 5))
done
trap 'rmdir "$CFGLOCK" 2>/dev/null || true' EXIT

# Write both the user-level (the one xcodebuild reads) and project-local config,
# then resolve from the mirror while still holding the lock.
mkdir -p ~/Library/org.swift.swiftpm/configuration .swiftpm/configuration
printf '%s' "$MIRROR_JSON" > ~/Library/org.swift.swiftpm/configuration/mirrors.json
printf '%s' "$MIRROR_JSON" > .swiftpm/configuration/mirrors.json

xcodebuild -project Vauchi.xcodeproj -scheme Vauchi \
    -clonedSourcePackagesDirPath .spm-packages \
    -derivedDataPath .derived-data \
    -resolvePackageDependencies

rmdir "$CFGLOCK" 2>/dev/null || true
trap - EXIT
echo "  provision-spm-mirror: resolved v$V from file:// mirror, .spm-packages ready"
