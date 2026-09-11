// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI
@testable import Vauchi
import XCTest

/// Replays every entry of Core's screen catalog through the app's own
/// host composition (sidebar, surface, context bar) and writes one PNG
/// per screen and appearance. No engine and no UI automation: the
/// reducer and the SwiftUI views are the ones the app ships.
///
/// Set `VAUCHI_SCREEN_CATALOG` to the fixture path and
/// `VAUCHI_SCREENSHOT_DIR` to the output directory (falls back to
/// XCTest attachments, which CI exports from the xcresult because the
/// hosted test process cannot write outside its sandbox); the test
/// skips when the catalog is unset.
@MainActor
final class ScreenCatalogRenderTests: XCTestCase {
    private static let canvas = CGSize(width: 1440, height: 900)

    func testRendersEveryCatalogScreen() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let catalogPath = environment["VAUCHI_SCREEN_CATALOG"] else {
            throw XCTSkip("VAUCHI_SCREEN_CATALOG is unset")
        }
        let catalog = try ScreenCatalog.load(from: URL(fileURLWithPath: catalogPath))
        let sink = ScreenCatalogScreenshotSink(
            directory: environment["VAUCHI_SCREENSHOT_DIR"],
            test: self
        )

        var lightRenders: Set<Data> = []
        var failures: [String] = []
        for entry in catalog.screens {
            do {
                let state = try entry.reduce()
                for variant in ScreenCatalogRenderVariant.allCases {
                    let png = try render(state, variant: variant)
                    sink.store(png, name: entry.codeID + variant.fileSuffix)
                    if variant == .light {
                        lightRenders.insert(png)
                    }
                }
            } catch {
                failures.append("\(entry.codeID): \(error)")
            }
        }

        XCTAssertEqual(failures, [], "catalog entries that did not render")
        XCTAssertGreaterThanOrEqual(
            lightRenders.count, 3,
            "expected at least three distinct screens, catalog has \(catalog.screens.count)"
        )
        sink.finish()
    }

    /// Hosts the content in a window-sized `NSHostingView` and caches its
    /// display into a 2x bitmap. `ImageRenderer` is not used: it cannot
    /// draw the AppKit-backed `ScrollView` every `.scroll` surface sits
    /// in (the iOS twin came out blank that way).
    private func render(
        _ state: PresentationState,
        variant: ScreenCatalogRenderVariant
    ) throws -> Data {
        let content = PresentationHostContent(
            state: state,
            onEvent: { _, _ in },
            onDismissOverlay: {}
        )
        .frame(width: Self.canvas.width, height: Self.canvas.height)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.dynamicTypeSize, variant.dynamicTypeSize)
        let host = NSHostingView(rootView: content)
        host.frame = CGRect(origin: .zero, size: Self.canvas)
        host.appearance = NSAppearance(named: variant.appearance)
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
        // The NavigationSplitView sidebar is an AppKit table that only
        // populates once its window is on screen; an off-screen window
        // captured a blank column (job 16457814358).
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        defer { window.close() }

        let scale = 2
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(Self.canvas.width) * scale,
            pixelsHigh: Int(Self.canvas.height) * scale,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw ScreenCatalogRenderError.noImage(variant)
        }
        bitmap.size = Self.canvas
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenCatalogRenderError.noImage(variant)
        }
        return png
    }
}

enum ScreenCatalogRenderError: Error {
    case noImage(ScreenCatalogRenderVariant)
}

enum ScreenCatalogRenderVariant: CaseIterable {
    case light
    case dark
    case large

    var fileSuffix: String {
        switch self {
        case .light: ".png"
        case .dark: ".dark.png"
        case .large: ".large.png"
        }
    }

    var appearance: NSAppearance.Name {
        self == .dark ? .darkAqua : .aqua
    }

    var dynamicTypeSize: DynamicTypeSize {
        self == .large ? .accessibility1 : .large
    }
}

/// Writes PNG files to a directory when one is configured and writable; keeps
/// them as XCTest attachments otherwise so a sandboxed runner still
/// carries them out in the xcresult.
final class ScreenCatalogScreenshotSink {
    private let directory: URL?
    private unowned let test: XCTestCase
    private var attachments: [XCTAttachment] = []
    private(set) var written = 0

    init(directory: String?, test: XCTestCase) {
        self.directory = directory.map { URL(fileURLWithPath: $0, isDirectory: true) }
        self.test = test
    }

    func store(_ png: Data, name: String) {
        if let directory, write(png, to: directory.appendingPathComponent(name)) {
            written += 1
            return
        }
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        attachments.append(attachment)
    }

    func finish() {
        attachments.forEach(test.add)
        print("screen catalog: wrote \(written) PNG(s), attached \(attachments.count)")
    }

    private func write(_ png: Data, to url: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try png.write(to: url, options: .atomic)
            return true
        } catch {
            print("screen catalog: could not write \(url.path): \(error)")
            return false
        }
    }
}
