// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// AppKit restores the window state an earlier launch saved. On the CI
/// runner that state held no window, so every test found the app with a
/// menu bar and nothing else (vauchi/private#707). Each test starts from
/// the scene the app declares instead of from what a previous run left.
///
/// The pair goes first: the argument domain reads `-key value`, so after a
/// `--reset-for-testing` it would be taken as that flag's value and ignored.
enum UITestLaunch {
    static func arguments(_ testing: String...) -> [String] {
        ["-ApplePersistenceIgnoreState", "YES"] + testing
    }
}
