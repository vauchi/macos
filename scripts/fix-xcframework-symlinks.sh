#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Fix macOS versioned framework symlinks broken by zip -r (missing -y flag).
#
# The published XCFramework zip (v0.3.0) was built with `zip -r` which follows
# symlinks and stores duplicate files. macOS versioned framework bundles require
# symlinks (Versions/Current → A, Headers → Versions/Current/Headers, etc.).
# Without them, Xcode fails with "Couldn't resolve framework symlink".
#
# Root cause fix: core/scripts/package-xcframework.sh now uses `zip -ry`.
# See: https://gitlab.com/vauchi/core/-/merge_requests/259
#
# REMOVE THIS SCRIPT after the first core release built with `zip -ry` is
# consumed by vauchi-platform-swift (expected v0.3.1+). At that point the
# extracted framework will already have correct symlinks.
#
# Usage: ./scripts/fix-xcframework-symlinks.sh

set -euo pipefail

DD=$(ls -d ~/Library/Developer/Xcode/DerivedData/Vauchi-* 2>/dev/null | head -1)
if [ -z "$DD" ]; then
    echo "No Vauchi DerivedData found — skipping symlink fix"
    exit 0
fi

FIXED=0

while IFS= read -r fw; do
    # Only applies to versioned (macOS) framework bundles
    [ -d "$fw/Versions/A" ] || continue

    # Check if Versions/Current is a directory (broken) instead of a symlink
    if [ -d "$fw/Versions/Current" ] && [ ! -L "$fw/Versions/Current" ]; then
        echo "Fixing versioned framework symlinks: $fw"

        # Versions/Current → A
        rm -rf "$fw/Versions/Current"
        (cd "$fw/Versions" && ln -sf A Current)

        # Top-level convenience symlinks → Versions/Current/*
        for link in Headers Modules Resources; do
            if [ -e "$fw/$link" ] && [ ! -L "$fw/$link" ]; then
                rm -rf "$fw/$link"
            fi
            (cd "$fw" && ln -sf "Versions/Current/$link" "$link")
        done

        # Binary symlink
        if [ -e "$fw/VauchiPlatformFFI" ] && [ ! -L "$fw/VauchiPlatformFFI" ]; then
            rm -f "$fw/VauchiPlatformFFI"
        fi
        (cd "$fw" && ln -sf "Versions/Current/VauchiPlatformFFI" "VauchiPlatformFFI")

        FIXED=$((FIXED + 1))
    else
        echo "Framework symlinks OK: $fw"
    fi
done < <(find "$DD/SourcePackages/artifacts" \
    -path "*/macos-*/VauchiPlatformFFI.framework" \
    -type d 2>/dev/null)

if [ "$FIXED" -gt 0 ]; then
    echo "Fixed $FIXED framework bundle(s)"
fi
