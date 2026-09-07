// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Resolves the platform-neutral `icon_token` Core attaches to a
/// `PresentationAction` into an SF Symbol name.
///
/// Core names its tokens after the SF Symbols core set, so most entries are
/// the identity mapping widened to the filled weight. The table is kept
/// explicit anyway: passing an arbitrary Core token straight to
/// `Image(systemName:)` would render a blank gap the moment Core names a
/// token this OS does not ship.
enum NavigationIconMap {
    /// Shown when Core sends a token this build does not know, so a new
    /// screen arrives with a marker instead of a hole in the row. An
    /// apps-grid glyph reads as "some section of this app" and stays
    /// truthful; reusing a concrete icon such as the house would put a
    /// confident lie next to a label that says something else.
    static let fallbackSymbol = "square.grid.2x2.fill"

    /// Filled weights throughout: outlines lose definition at the sizes a
    /// navigation row uses and are the first thing to disappear for
    /// low-vision users. Tokens whose symbol family ships no `.fill`
    /// (`qrcode`, `laptopcomputer`, `mappin.and.ellipse`) keep the base name.
    private static let symbolsByToken: [String: String] = [
        "person.crop.rectangle": "person.crop.rectangle.fill",
        "person.2": "person.2.fill",
        "qrcode": "qrcode",
        "folder": "folder.fill",
        "tag": "tag.fill",
        "mappin.and.ellipse": "mappin.and.ellipse",
        "person.badge.plus": "person.fill.badge.plus",
        "gearshape": "gearshape.fill",
        "questionmark.circle": "questionmark.circle.fill",
        "key.horizontal": "key.horizontal.fill",
        "laptopcomputer": "laptopcomputer",
        "externaldrive": "externaldrive.fill",
        "hand.raised": "hand.raised.fill",
        "bubble.left.and.bubble.right": "bubble.left.and.bubble.right.fill",
        "list.bullet.rectangle": "list.bullet.rectangle.fill",
        "house": "house.fill",
    ]

    /// Total over every token, present or not.
    static func systemImage(for token: String?) -> String {
        guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty
        else {
            return fallbackSymbol
        }
        return symbolsByToken[token] ?? fallbackSymbol
    }

    /// The navigation overlay is this shell's sidebar, so every row there
    /// gets an icon beside its label even when Core sent no token. Other
    /// overlays only show one where Core actually named an icon, so an
    /// action menu does not grow a column of meaningless markers.
    static func systemImage(
        forOverlayKind kind: PresentationOverlayKind,
        token: String?
    ) -> String? {
        guard kind == .navigation || token != nil else { return nil }
        return systemImage(for: token)
    }
}
