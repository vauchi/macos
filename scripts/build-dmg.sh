#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Build a DMG installer from the Xcode archive.
# Usage: ./build-dmg.sh <version> <archive-path>

set -euo pipefail

VERSION="${1:?Usage: $0 <version> <archive-path>}"
ARCHIVE="${2:?Usage: $0 <version> <archive-path>}"
DMG_NAME="Vauchi-${VERSION}.dmg"
STAGING="dmg-staging"

if [ ! -d "${ARCHIVE}" ]; then
  echo "✗ Archive not found: ${ARCHIVE}" >&2
  exit 1
fi

APP_PATH="${ARCHIVE}/Products/Applications/Vauchi.app"
if [ ! -d "${APP_PATH}" ]; then
  echo "✗ Vauchi.app not found in archive" >&2
  exit 1
fi

rm -rf "${STAGING}"
mkdir -p "${STAGING}"
cp -R "${APP_PATH}" "${STAGING}/"

ln -s /Applications "${STAGING}/Applications"

hdiutil create -volname "Vauchi ${VERSION}" \
  -srcfolder "${STAGING}" \
  -ov -format UDZO \
  "${DMG_NAME}"

rm -rf "${STAGING}"

echo "✓ Built ${DMG_NAME}"
ls -lh "${DMG_NAME}"
