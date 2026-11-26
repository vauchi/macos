// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

extension XCUIElement {
    func isHittable(in scrollView: XCUIElement) -> Bool {
        // XCTest can report clipped SwiftUI rows as hittable.
        isHittable && (!scrollView.exists || scrollView.frame.contains(frame))
    }
}
