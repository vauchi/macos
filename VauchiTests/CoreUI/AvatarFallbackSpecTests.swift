// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// `AvatarFallbackSpec` is the pure sizing/clip rule behind
// `PresentationImageContent` (F1,
// 2026-09-09-cross-frontend-design-review-design.md): a missing avatar
// must draw like `PresentationRowView`'s row avatar — a filled circle
// sized to the platform's minimum pointer target — rather than as loose
// text. Extracted so the rule is tested directly instead of through pixel
// sampling.

@testable import Vauchi
import XCTest

final class AvatarFallbackSpecTests: XCTestCase {
    func testFallbackClipsToACircleRegardlessOfCoresShapeToken() {
        XCTAssertTrue(AvatarFallbackSpec.fallback(minimumTargetSize: 48).clipsToCircle)
    }

    func testFallbackDiameterMatchesTheSurfacesMinimumTargetSize() {
        XCTAssertEqual(AvatarFallbackSpec.fallback(minimumTargetSize: 44).diameter, 44)
        XCTAssertEqual(AvatarFallbackSpec.fallback(minimumTargetSize: 56).diameter, 56)
    }

    func testImageDataClipsToACircleOnlyWhenCoreSendsTheCircleShape() {
        XCTAssertTrue(
            AvatarFallbackSpec.imageData(shape: .circle, minimumTargetSize: 48).clipsToCircle
        )
        XCTAssertFalse(
            AvatarFallbackSpec.imageData(shape: .natural, minimumTargetSize: 48).clipsToCircle
        )
    }

    func testImageDataDiameterAlsoMatchesTheMinimumTargetSize() {
        XCTAssertEqual(
            AvatarFallbackSpec.imageData(shape: .circle, minimumTargetSize: 48).diameter,
            48
        )
    }

    /// Matches `PresentationRowView`'s row-avatar fill exactly, so a
    /// standalone avatar and a list-row avatar read as the same element.
    func testFillOpacityMatchesTheRowAvatarTreatment() {
        XCTAssertEqual(AvatarFallbackSpec.fillOpacity, 0.15)
    }
}
