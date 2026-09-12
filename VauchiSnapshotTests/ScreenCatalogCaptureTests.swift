// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI
import XCTest

/// Pins that the screen-catalog capture shows the sidebar column of a
/// `NavigationSplitView`. On macOS 26 that column sits in a Liquid Glass
/// container that only the window server composites: a plain
/// `cacheDisplay` rasterised its backdrop as a black band and skipped the
/// content inside it (main pipeline 2842707598, job 16460767602).
@MainActor
final class ScreenCatalogCaptureTests: XCTestCase {
    private static let size = CGSize(width: 800, height: 600)

    func testSidebarColumnIsPaintedWithoutBlackBand() throws {
        // A shape, not text: the sidebar list restyles its rows' foreground.
        let content = NavigationSplitView {
            List { Color.red.frame(height: 20) }
        } detail: {
            Text("Detail")
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color(nsColor: .windowBackgroundColor))

        let png = try XCTUnwrap(
            ScreenCatalogCapture.png(of: content, size: Self.size, appearance: .aqua)
        )
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: png))
        XCTAssertEqual(bitmap.pixelsWide, Int(Self.size.width) * 2, "captures at 2x")

        let corner = try XCTUnwrap(bitmap.colorAt(x: 4, y: 4)?.usingColorSpace(.deviceRGB))
        XCTAssertFalse(Self.isOpaqueBlack(corner), "top-left pixel is the window background, not a black band")

        let sidebarColumn = CGRect(x: 0, y: 0, width: 500, height: 600)
        XCTAssertGreaterThan(
            bitmap.countPixels(in: sidebarColumn, stride: 2, where: Self.isRed), 0,
            "the red sidebar row is painted"
        )
    }

    private static func isOpaqueBlack(_ color: NSColor) -> Bool {
        color.alphaComponent > 0.5 && color.brightnessComponent < 0.2
    }

    private static func isRed(_ color: NSColor) -> Bool {
        color.redComponent > 0.6 && color.greenComponent < 0.4 && color.blueComponent < 0.4
    }
}

private extension NSBitmapImageRep {
    func countPixels(in rect: CGRect, stride step: Int, where matches: (NSColor) -> Bool) -> Int {
        var count = 0
        for row in stride(from: Int(rect.minY), to: Int(rect.maxY), by: step) {
            for column in stride(from: Int(rect.minX), to: Int(rect.maxX), by: step) {
                if let color = colorAt(x: column, y: row)?.usingColorSpace(.deviceRGB), matches(color) {
                    count += 1
                }
            }
        }
        return count
    }
}
