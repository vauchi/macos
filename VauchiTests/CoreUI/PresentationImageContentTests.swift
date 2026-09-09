// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Core sends an avatar as `Image { data, fallback_text, shape }`. With no
// picture the shell draws `fallback_text`, and the question here is whether
// those initials are drawn *as an avatar* or as loose text on the page.
//
// The node's wrapper already applies `.frame(minWidth: minimumTarget,
// minHeight: minimumTarget)`, so an accessibility query reports a 44 x 44
// element whether or not anything is painted inside it. The defect is a
// missing fill, so the assertion has to be on pixels: render the view and
// sample a point inside the avatar and clear of the centred glyph.
//
// Mirrors `ios/VauchiTests/CoreUI/PresentationImageContentTests.swift`;
// this shell shares the same view and had the same defect.

import SwiftUI
@testable import Vauchi
import XCTest

@MainActor
final class PresentationImageContentTests: XCTestCase {
    /// Side of the square the view is rendered into.
    private let side: CGFloat = 96

    /// The fill is a low-opacity secondary grey — enough to read as an
    /// avatar without competing with the initials — so it lands well under
    /// full opacity. Anything above this is paint; an unfilled view
    /// measures 0.
    private let opaqueEnoughToRead: CGFloat = 0.04

    /// A point inside the drawn avatar and clear of the centred glyph. A
    /// quarter in from the left at mid-height sits inside the shape, and
    /// the two initials occupy about the middle third.
    private var insideTheAvatarOutsideTheGlyph: CGPoint {
        CGPoint(x: side / 4, y: side / 2)
    }

    private func imageNode(
        data: [UInt8]?,
        fallbackText: String?,
        shape: PresentationImageShape
    ) -> PresentationImageNode {
        PresentationImageNode(
            id: nil,
            data: data,
            fallbackText: fallbackText,
            shape: shape,
            brightness: 1,
            activation: nil,
            accessibility: PresentationAccessibility(label: "Avatar", description: nil)
        )
    }

    /// Renders on a transparent ground and returns the alpha at `point`.
    /// Transparent matters: against an opaque ground every pixel comes back
    /// opaque and the test proves nothing.
    private func alpha(of node: PresentationImageNode, at point: CGPoint) throws -> CGFloat {
        let host = NSHostingView(
            rootView: PresentationImageContent(value: node)
                .frame(width: side, height: side)
        )
        host.frame = CGRect(x: 0, y: 0, width: side, height: side)
        host.layoutSubtreeIfNeeded()

        let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        rep.size = host.bounds.size
        host.cacheDisplay(in: host.bounds, to: rep)

        // AppKit's bitmap origin is bottom-left; the sample point is stated
        // in top-left coordinates to match the iOS twin of this file.
        let sampled = try XCTUnwrap(
            rep.colorAt(x: Int(point.x), y: Int(side - point.y))
        )
        return sampled.alphaComponent
    }

    func testCircularFallbackInitialsAreDrawnOnAFilledShape() throws {
        let node = imageNode(data: nil, fallbackText: "TU", shape: .circle)

        let sampled = try alpha(of: node, at: insideTheAvatarOutsideTheGlyph)

        XCTAssertGreaterThan(
            sampled,
            opaqueEnoughToRead,
            """
            The avatar has no fill: initials render as loose text on the page \
            rather than inside a circle. Sampled alpha \(sampled) at \
            \(insideTheAvatarOutsideTheGlyph).
            """
        )
    }

    func testNaturalFallbackInitialsAreDrawnOnAFilledShape() throws {
        let node = imageNode(data: nil, fallbackText: "TU", shape: .natural)

        let sampled = try alpha(of: node, at: insideTheAvatarOutsideTheGlyph)

        XCTAssertGreaterThan(sampled, opaqueEnoughToRead, "natural-shaped fallback has no fill")
    }

    /// Guards the sampler: with nothing to draw the point must read clear,
    /// or the two assertions above would pass against any view at all.
    func testTheSampledPointIsTransparentWhenThereIsNothingToDraw() throws {
        let node = imageNode(data: nil, fallbackText: nil, shape: .natural)

        let sampled = try alpha(of: node, at: insideTheAvatarOutsideTheGlyph)

        XCTAssertLessThan(
            sampled,
            opaqueEnoughToRead,
            "the sampler reports paint where the view draws none"
        )
    }
}
