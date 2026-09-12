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
        return bitmap.representation(using: .png, properties: [:])
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
