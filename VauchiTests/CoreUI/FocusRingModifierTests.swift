// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// WCAG 2.2 SC 2.4.7/2.4.11 require a visible, sufficiently large focus
// indicator. Core's `themes/tokens.json` `focus` group names the exact
// numbers (`ring_width: 3`, `ring_offset: 2`) but is not yet bridged past
// UniFFI theme colors (F4,
// 2026-09-09-cross-frontend-design-review-design.md), so this shell
// hardcodes the same values rather than waiting on the bridge. This test
// is what keeps that hardcode honest against the token document.

@testable import Vauchi
import XCTest

final class FocusRingModifierTests: XCTestCase {
    func testRingWidthMatchesCoresFocusRingWidthToken() {
        XCTAssertEqual(FocusRingModifier.ringWidth, 3)
    }

    func testRingOffsetMatchesCoresFocusRingOffsetToken() {
        XCTAssertEqual(FocusRingModifier.ringOffset, 2)
    }
}
