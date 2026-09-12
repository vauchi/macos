// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// Rasterises a SwiftUI view into a PNG the way the screen catalog needs
/// it: hosted in a window-sized `NSHostingView` and cached into a 2x
/// bitmap. `ImageRenderer` is not used: it cannot draw the AppKit-backed
/// `ScrollView` every `.scroll` surface sits in (the iOS twin came out
/// blank that way).
@MainActor
enum ScreenCatalogCapture {
    static func png(
        of content: some View,
        size: CGSize,
        appearance: NSAppearance.Name,
        scale: Int = 2
    ) -> Data? {
        let host = NSHostingView(rootView: content)
        host.frame = CGRect(origin: .zero, size: size)
        host.appearance = NSAppearance(named: appearance)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        // A programmatic NSWindow releases itself on close; ARC then
        // releases this reference again and the test process dies after
        // the run (macos!401 job 16457814358: 9 PNG files written, then
        // "Restarting after unexpected exit").
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        defer { window.close() }

        guard let bitmap = bitmap(size: size, scale: scale) else { return nil }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        paintGlassColumns(of: host, into: bitmap, scale: scale)
        return bitmap.representation(using: .png, properties: [:])
    }

    /// On macOS 26 `NavigationSplitView` hosts the sidebar column in a
    /// Liquid Glass container that only the window server composites:
    /// under `cacheDisplay` its backdrop rasterises as a black gradient
    /// and the content it hosts is skipped (job 16460767602). Painting
    /// the column's background and caching the hosted content on its own
    /// puts a flat sidebar where the glass one would be.
    private static func paintGlassColumns(of host: NSView, into bitmap: NSBitmapImageRep, scale: Int) {
        guard #available(macOS 26.0, *) else { return }
        let glassViews = host.descendants.compactMap { $0 as? NSGlassEffectView }
        guard !glassViews.isEmpty, let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        defer { NSGraphicsContext.restoreGraphicsState() }
        for glass in glassViews {
            if let column = glass.superview {
                NSColor.windowBackgroundColor.setFill()
                column.convert(column.bounds, to: host).fill()
            }
            guard let content = glass.contentView,
                  let contentBitmap = self.bitmap(size: content.bounds.size, scale: scale)
            else { continue }
            content.cacheDisplay(in: content.bounds, to: contentBitmap)
            contentBitmap.draw(in: content.convert(content.bounds, to: host))
        }
    }

    private static func bitmap(size: CGSize, scale: Int) -> NSBitmapImageRep? {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width) * scale,
            pixelsHigh: Int(size.height) * scale,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        bitmap?.size = size
        return bitmap
    }
}

private extension NSView {
    var descendants: [NSView] {
        subviews.flatMap { [$0] + $0.descendants }
    }
}
