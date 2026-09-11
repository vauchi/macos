// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI
@testable import Vauchi
import XCTest

/// Guards the shell's obligation to honour every `PresentationTextStyle`
/// Core defines (`core/vauchi-core/src/platform/presentation/surface/nodes.rs`)
/// and to render it with the bundled brand faces rather than the system font.
///
/// `textRoleStyle(for:)` is already exhaustive, so the compiler catches a
/// role that is never handled. It cannot catch a role handled *wrongly* —
/// falling back to a system font compiles clean and silently drops the
/// brand typeface. These tests are the part exhaustiveness cannot do.
final class TextRoleStyleTests: XCTestCase {
    private let allRoles: [PresentationTextStyle] = [
        .heading, .body, .caption, .monospace, .muted,
    ]

    func testEveryRoleResolvesToADistinctPresentation() {
        let resolved = allRoles.map(textRoleStyle(for:))

        for (offset, style) in resolved.enumerated() {
            let duplicate = resolved.enumerated().first {
                $0.offset != offset && $0.element == style
            }
            XCTAssertNil(
                duplicate,
                "\(allRoles[offset]) collides with \(duplicate.map { allRoles[$0.offset] }.debugDescription); "
                    + "a collision means one role was folded into another"
            )
        }
    }

    func testHeadingUsesBricolageGrotesqueBold() {
        let style = textRoleStyle(for: .heading)

        XCTAssertEqual(
            style.font,
            .custom("BricolageGrotesque-96ptExtraBold_Bold", size: 17, relativeTo: .title2)
        )
        XCTAssertFalse(style.muted)
    }

    func testBodyAndMutedUseHankenGroteskRegular() {
        let body = textRoleStyle(for: .body)
        let muted = textRoleStyle(for: .muted)
        let expectedFont = Font.custom("HankenGrotesk-Regular", size: 13, relativeTo: .body)

        XCTAssertEqual(body.font, expectedFont)
        XCTAssertFalse(body.muted, "body must stay full emphasis")
        XCTAssertEqual(
            muted.font, expectedFont,
            "muted differs from body by emphasis, not by font"
        )
        XCTAssertTrue(muted.muted, "muted must reduce emphasis")
    }

    func testCaptionUsesHankenGroteskRegular() {
        let style = textRoleStyle(for: .caption)

        XCTAssertEqual(
            style.font,
            .custom("HankenGrotesk-Regular", size: 10, relativeTo: .caption)
        )
        XCTAssertFalse(style.muted)
    }

    func testMonospaceUsesJetBrainsMonoRegular() {
        let style = textRoleStyle(for: .monospace)

        XCTAssertEqual(
            style.font,
            .custom("JetBrainsMono-Regular", size: 13, relativeTo: .body)
        )
        XCTAssertNotEqual(
            style.font, textRoleStyle(for: .body).font,
            "monospace must not fall back to the proportional body font"
        )
        XCTAssertFalse(style.muted)
    }

    /// The three brand families must actually be registered in the process
    /// hosting these tests (`ATSApplicationFontsPath` in `Vauchi/Info.plist`),
    /// not merely present on disk under `Vauchi/Resources/Fonts` — a missing
    /// `Copy Bundle Resources` entry or a wrong `ATSApplicationFontsPath`
    /// value both fail silently at the `Font.custom` call site, falling
    /// back to the system font instead of erroring.
    func testBrandFontFamiliesAreRegistered() {
        let families = Set(NSFontManager.shared.availableFontFamilies)

        for family in ["Bricolage Grotesque", "Hanken Grotesk", "JetBrains Mono"] {
            XCTAssertTrue(
                families.contains(family),
                "\(family) is not registered; check ATSApplicationFontsPath and the Fonts folder reference"
            )
        }
    }

    /// Complements `testBrandFontFamiliesAreRegistered`: the family being
    /// registered does not prove the specific PostScript name each role
    /// resolves to actually loads — a typo in the instance suffix (e.g.
    /// `_Bold` vs `_bold`) still leaves the family present but silently
    /// substitutes the system font for that one role.
    func testEveryRolePostScriptNameLoadsAsARealFont() {
        let postScriptNames = [
            "BricolageGrotesque-96ptExtraBold_Bold",
            "HankenGrotesk-Regular",
            "JetBrainsMono-Regular",
        ]

        for name in postScriptNames {
            XCTAssertNotNil(
                NSFont(name: name, size: 13),
                "\(name) did not resolve to a registered font"
            )
        }
    }

    func testUnknownWireValueFallsBackToBody() throws {
        // A style this shell does not know (here "title", the retired
        // variant Core now projects as "heading") must not fail the whole
        // command batch: a Core-main screen catalog replayed through an
        // older shell renders it as body copy instead.
        let payload = Data(#""title""#.utf8)

        XCTAssertEqual(
            try JSONDecoder().decode(PresentationTextStyle.self, from: payload),
            .body
        )
    }
}
