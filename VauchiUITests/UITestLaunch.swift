// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// AppKit restores the window state an earlier launch saved. On the CI
/// runner that state held no window, so every test found the app with a
/// menu bar and nothing else (vauchi/private#707). Each test starts from
/// the scene the app declares instead of from what a previous run left.
enum UITestLaunch {
    static func arguments(_ testing: String...) -> [String] {
        testing + ["-ApplePersistenceIgnoreState", "YES"]
    }
}
