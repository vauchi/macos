// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Pure sizing and clip rule behind `PresentationImageContent`, extracted
/// so it is unit-testable without instantiating a view. Generalizes
/// `PresentationRowView`'s row-avatar treatment to the standalone `Image`
/// node (F1, `2026-09-09-cross-frontend-design-review-design.md`): a
/// missing avatar must draw as an avatar-shaped placeholder, not as loose
/// text on the page.
struct AvatarFallbackSpec: Equatable {
    /// Matches `PresentationRowView`'s row-avatar fill exactly, so a
    /// standalone avatar and a list-row avatar read as the same element.
    static let fillOpacity: Double = 0.15

    let diameter: CGFloat
    let clipsToCircle: Bool

    /// The placeholder drawn when Core sent no image `data`. Always a
    /// circle regardless of `shape` — a corner-radius rectangle around
    /// centred initials would not read as a placeholder avatar.
    static func fallback(minimumTargetSize: CGFloat) -> AvatarFallbackSpec {
        AvatarFallbackSpec(diameter: minimumTargetSize, clipsToCircle: true)
    }

    /// The clip applied once real image data exists: Core's `shape` token
    /// decides, same as every other shape-aware surface in this shell.
    static func imageData(
        shape: PresentationImageShape,
        minimumTargetSize: CGFloat
    ) -> AvatarFallbackSpec {
        AvatarFallbackSpec(diameter: minimumTargetSize, clipsToCircle: shape == .circle)
    }
}
