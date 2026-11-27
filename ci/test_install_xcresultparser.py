#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
# SPDX-License-Identifier: GPL-3.0-or-later

import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class InstallXcresultparserTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.artifact = self.root / "artifact"
        self.destination = self.root / "xcresultparser"
        self.destination.write_bytes(b"previous tool\n")
        self.marker = self.root / "executed"
        self.url = self.root / "url"
        self.environment = dict(os.environ)
        self.environment.update(
            PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
            TEST_ARTIFACT=str(self.artifact),
            TEST_MARKER=str(self.marker),
            TEST_URL=str(self.url),
            TEST_CURL_STATUS="0",
        )
        self.write_command(
            "curl",
            """#!/bin/sh
set -eu
output=
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output) output=$2; shift ;;
        https:*) printf '%s' "$1" > "$TEST_URL" ;;
    esac
    shift
done
[ "$TEST_CURL_STATUS" = 0 ] || exit "$TEST_CURL_STATUS"
cp "$TEST_ARTIFACT" "$output"
""",
        )
        self.payload("3.0.0")

    def write_command(self, name, contents):
        path = self.bin / name
        path.write_text(contents)
        path.chmod(0o755)

    def payload(self, version):
        self.artifact.write_text(
            "#!/bin/sh\nprintf executed > \"$TEST_MARKER\"\n"
            + "printf '%s\\n' '" + version + "'\n"
        )
        return hashlib.sha256(self.artifact.read_bytes()).hexdigest()

    def run_installer(self, digest=None):
        if digest is None:
            digest = hashlib.sha256(self.artifact.read_bytes()).hexdigest()
        return subprocess.run(
            [
                "bash",
                str(Path(__file__).with_name("install-xcresultparser.sh")),
                "3.0.0",
                digest,
                str(self.destination),
            ],
            env=self.environment,
            capture_output=True,
            text=True,
        )

    def assert_preserved(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.destination.read_bytes(), b"previous tool\n")
        self.assertEqual(list(self.root.glob("xcresultparser.*")), [])

    def test_verified_release_replaces_tool_with_executable(self):
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.destination.read_bytes(), self.artifact.read_bytes())
        self.assertEqual(self.destination.stat().st_mode & 0o111, 0o111)
        self.assertEqual(self.marker.read_text(), "executed")
        self.assertEqual(
            self.url.read_text(),
            "https://github.com/a7ex/xcresultparser/releases/download/3.0.0/xcresultparser",
        )
        self.assertEqual(list(self.root.glob("xcresultparser.*")), [])

    def test_checksum_mismatch_preserves_tool_without_executing_download(self):
        self.assert_preserved(self.run_installer("0" * 64))
        self.assertFalse(self.marker.exists())

    def test_network_failure_preserves_tool_without_executing_download(self):
        self.environment["TEST_CURL_STATUS"] = "22"
        result = self.run_installer()
        self.assertEqual(result.returncode, 22, result.stdout + result.stderr)
        self.assert_preserved(result)
        self.assertFalse(self.marker.exists())

    def test_wrong_version_preserves_tool_after_checksum_verification(self):
        digest = self.payload("2.3.0")
        result = self.run_installer(digest)
        self.assert_preserved(result)
        self.assertIn("expected 3.0.0", result.stderr)
        self.assertEqual(self.marker.read_text(), "executed")

    def test_failed_replacement_preserves_previous_tool(self):
        self.write_command("mv", "#!/bin/sh\nexit 73\n")
        result = self.run_installer()
        self.assertEqual(result.returncode, 73, result.stdout + result.stderr)
        self.assert_preserved(result)
        self.assertEqual(self.marker.read_text(), "executed")


if __name__ == "__main__":
    unittest.main()
