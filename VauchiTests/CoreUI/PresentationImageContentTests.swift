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
        shape: PresentationImageShape,
        brightness: Float = 0
    ) -> PresentationImageNode {
        PresentationImageNode(
            id: nil,
            data: data,
            fallbackText: fallbackText,
            shape: shape,
            brightness: brightness,
            activation: nil,
            accessibility: PresentationAccessibility(label: "Avatar", description: nil)
        )
    }

    /// Renders on a transparent ground and returns the alpha at `point`.
    /// Transparent matters: against an opaque ground every pixel comes back
    /// opaque and the test proves nothing.
    private func alpha(of node: PresentationImageNode, at point: CGPoint) throws -> CGFloat {
        try color(of: node, at: point).alphaComponent
    }

    private func color(of node: PresentationImageNode, at point: CGPoint) throws -> NSColor {
        let host = NSHostingView(
            rootView: PresentationImageContent(value: node, minimumTarget: side)
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
        return try XCTUnwrap(sampled.usingColorSpace(.sRGB))
    }

    /// Filled through `CGContext`: `NSBitmapImageRep.setColor(.white, …)` on a
    /// device-RGB rep writes nothing (`.white` is a grey colour), which left
    /// this fixture transparent and failed the test below for the wrong
    /// reason in CI (macos!407).
    private func solidWhitePNG() throws -> [UInt8] {
        let context = try XCTUnwrap(
            CGContext(
                data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let rep = try NSBitmapImageRep(cgImage: XCTUnwrap(context.makeImage()))
        return try [UInt8](XCTUnwrap(rep.representation(using: .png, properties: [:])))
    }

    /// Core's `brightness` is an offset where 0 means unchanged (the avatar
    /// editor slider runs -0.3...0.3). Reading it as a multiplier turned
    /// every picture Core sends at 0, avatars and the onboarding mark, black.
    func testAPictureAtNeutralBrightnessKeepsItsColour() throws {
        let node = try imageNode(data: solidWhitePNG(), fallbackText: nil, shape: .natural)
        let renderer = ImageRenderer(
            content: PresentationImageContent(value: node, minimumTarget: side)
                .frame(width: side, height: side)
        )
        renderer.scale = 1
        let cgImage = try XCTUnwrap(renderer.cgImage, "ImageRenderer produced no bitmap")
        let rep = NSBitmapImageRep(cgImage: cgImage)

        let sampled = try XCTUnwrap(
            rep.colorAt(x: Int(side / 2), y: Int(side / 2))?.usingColorSpace(.sRGB)
        )

        XCTAssertGreaterThan(sampled.alphaComponent, 0.8, "the picture was not drawn at all")
        XCTAssertGreaterThan(
            sampled.redComponent, 0.8, "a white picture at brightness 0 rendered as \(sampled)"
        )
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
