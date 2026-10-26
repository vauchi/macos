// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Core's opaque restorable state (vauchi/private#814).
struct RestorableStateStore {
    let defaults: UserDefaults

    static var standard: RestorableStateStore {
        RestorableStateStore(defaults: .standard)
    }

    func keep(_: String) {}

    var state: String? {
        nil
    }
}
