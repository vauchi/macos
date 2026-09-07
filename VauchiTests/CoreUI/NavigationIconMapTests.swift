// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
@testable import Vauchi
import XCTest

final class NavigationIconMapTests: XCTestCase {
    /// The icon tokens Core attaches to navigation items, mirroring
    /// `tab_metadata` in `vauchi-app/src/ui/app_engine/navigation.rs`.
    /// Core owns the list; this copy exists so the map can be proven
    /// total over everything Core ships today.
    private static let coreNavigationTokens = [
        "person.crop.rectangle",
        "person.2",
        "qrcode",
        "folder",
        "tag",
        "mappin.and.ellipse",
        "person.badge.plus",
        "gearshape",
        "questionmark.circle",
        "key.horizontal",
        "laptopcomputer",
        "externaldrive",
        "hand.raised",
        "bubble.left.and.bubble.right",
        "list.bullet.rectangle",
        "house",
    ]

    private func symbolExists(_ name: String) -> Bool {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }

    /// A name the system cannot resolve renders as a blank gap next to the
    /// label, so every mapped name has to be a symbol this OS actually ships.
    func testEveryCoreNavigationTokenResolvesToAnInstalledSymbol() {
        for token in Self.coreNavigationTokens {
            let symbol = NavigationIconMap.systemImage(for: token)
            XCTAssertTrue(
                symbolExists(symbol),
                "token \(token) mapped to unknown SF Symbol \(symbol)"
            )
        }
    }

    /// Outlines lose definition at sidebar sizes and for low-vision users, so
    /// the map takes the filled weight wherever the symbol family offers one.
    /// Expressed as "no fuller variant remains" so a symbol family that gains
    /// a fill in a later OS is caught rather than silently left thin.
    func testMappedSymbolsPreferFilledVariants() {
        for token in Self.coreNavigationTokens {
            let symbol = NavigationIconMap.systemImage(for: token)
            XCTAssertFalse(
                symbolExists(symbol + ".fill"),
                "token \(token) mapped to \(symbol) but \(symbol).fill exists"
            )
        }
    }

    /// Core may add a screen before this shell learns its token; an unmapped
    /// token must still put something beside the label.
    func testUnknownTokenFallsBackToTheDefaultSymbol() {
        XCTAssertEqual(
            NavigationIconMap.systemImage(for: "sparkles.rectangle.not.a.symbol"),
            NavigationIconMap.fallbackSymbol
        )
    }

    /// `icon_token` is optional in the presentation protocol.
    func testMissingTokenFallsBackToTheDefaultSymbol() {
        XCTAssertEqual(
            NavigationIconMap.systemImage(for: nil),
            NavigationIconMap.fallbackSymbol
        )
        XCTAssertEqual(
            NavigationIconMap.systemImage(for: "   "),
            NavigationIconMap.fallbackSymbol
        )
    }

    func testFallbackSymbolIsAnInstalledFilledSymbol() {
        XCTAssertTrue(symbolExists(NavigationIconMap.fallbackSymbol))
        XCTAssertFalse(symbolExists(NavigationIconMap.fallbackSymbol + ".fill"))
    }

    /// The navigation palette is the shell's sidebar: every entry carries an
    /// icon, including ones Core sent no token for. Other overlays keep their
    /// plain-text rows, so an action menu does not sprout meaningless dots.
    func testNavigationOverlayIconsEveryItemAndActionMenuOnlyTokenedOnes() {
        XCTAssertNotNil(
            NavigationIconMap.systemImage(forOverlayKind: .navigation, token: nil)
        )
        XCTAssertNil(
            NavigationIconMap.systemImage(forOverlayKind: .actionMenu, token: nil)
        )
        XCTAssertEqual(
            NavigationIconMap.systemImage(forOverlayKind: .actionMenu, token: "house"),
            NavigationIconMap.systemImage(for: "house")
        )
    }
}
