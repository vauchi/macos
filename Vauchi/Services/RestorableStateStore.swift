// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Core's opaque restorable state (vauchi/private#814), kept per device in
/// UserDefaults, outside the vault, so a language or theme pick applies
/// before storage opens. The shell never reads the value; Core validates
/// whatever comes back.
struct RestorableStateStore {
    /// Core caps the value far below this; the bound only stops a damaged
    /// preference from being handed back whole.
    static let maxBytes = 4096
    private static let key = "vauchi.restorableState"

    let defaults: UserDefaults

    static var standard: RestorableStateStore {
        RestorableStateStore(defaults: .standard)
    }

    func keep(_ state: String) {
        defaults.set(state, forKey: Self.key)
    }

    var state: String? {
        guard let state = defaults.string(forKey: Self.key),
              state.utf8.count <= Self.maxBytes
        else { return nil }
        return state
    }
}
