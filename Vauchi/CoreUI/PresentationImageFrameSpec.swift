// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Pure sizing decision behind `image(_:)`, extracted so it is
/// unit-testable without instantiating a view — same reasoning as
/// `AvatarFallbackSpec`.
struct PresentationImageFrameSpec: Equatable {
    let diameter: CGFloat
    /// True once Core names an explicit square (`size`): the frame caps
    /// at `diameter` and shrinks with the row instead of flooring and
    /// growing to fill it, the way every unsized avatar still does.
    let capsToAvailableWidth: Bool

    /// Core omits `size` for every avatar, where sizing stays the
    /// shell's call (`minimumTarget`); it names one only where it needs
    /// an exact square, currently just the onboarding mark.
    static func node(size: UInt16?, minimumTarget: CGFloat) -> PresentationImageFrameSpec {
        guard let size else {
            return PresentationImageFrameSpec(diameter: minimumTarget, capsToAvailableWidth: false)
        }
        return PresentationImageFrameSpec(diameter: CGFloat(size), capsToAvailableWidth: true)
    }
}
