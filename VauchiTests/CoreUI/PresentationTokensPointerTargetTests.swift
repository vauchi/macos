// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// A decoded `PresentationTokens` always carries `minimum_target_size`, but
// some chrome (the context command bar) can render before any surface —
// and its `PresentationTokens` — exists yet. This pins the resolver's two
// behaviors: read the token when one is available, and fall back to
// Android's floor (F4, 2026-09-09-cross-frontend-design-review-design.md)
// otherwise, rather than Apple's 44.

@testable import Vauchi
import XCTest

final class PresentationTokensPointerTargetTests: XCTestCase {
    private func tokens(minimumTargetSize: UInt16) -> PresentationTokens {
        PresentationTokens(
            spacingSmall: 4,
            spacingMedium: 8,
            spacingLarge: 16,
            cornerRadius: 8,
            minimumTargetSize: minimumTargetSize
        )
    }

    func testResolvesTheTokenValueWhenTokensArePresent() {
        XCTAssertEqual(
            PresentationTokens.minimumTargetSize(from: tokens(minimumTargetSize: 56)),
            56
        )
    }

    func testFallsBackTo48WhenNoTokensAreAvailable() {
        XCTAssertEqual(PresentationTokens.minimumTargetSize(from: nil), 48)
    }
}
