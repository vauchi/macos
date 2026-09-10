// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// How a `PresentationTextStyle` role is presented natively.
///
/// Font and emphasis travel together because they are not independent:
/// `.muted` shares `.body`'s font and differs only in foreground, so
/// neither value identifies a role on its own.
struct TextRoleStyle: Equatable {
    let font: Font
    let muted: Bool
}

/// Resolve Core's semantic text role to native SwiftUI styling using the
/// brand faces bundled at `Vauchi/Resources/Fonts` and registered via
/// `ATSApplicationFontsPath` in `Vauchi/Info.plist`.
///
/// Core sends a role rather than a size so the shell can pick a native
/// text style and inherit Dynamic Type (ADR-021, ADR-066).
///
/// Deliberately has no `default` branch: a role added to Core must break
/// this build rather than fall back silently. Note that exhaustiveness
/// alone is not sufficient — it proves a role was handled, never that it
/// resolved correctly — which is what `TextRoleStyleTests` covers.
func textRoleStyle(for style: PresentationTextStyle) -> TextRoleStyle {
    switch style {
    case .heading: TextRoleStyle(font: headingFont, muted: false)
    case .body: TextRoleStyle(font: bodyFont, muted: false)
    case .caption: TextRoleStyle(font: captionFont, muted: false)
    case .monospace: TextRoleStyle(font: monospaceFont, muted: false)
    case .muted: TextRoleStyle(font: bodyFont, muted: true)
    }
}

/// Bricolage Grotesque's default named instance is its heaviest weight
/// (wght 800, "96pt ExtraBold"); CoreText derives every other named
/// instance's PostScript name from that default rather than from the
/// family name, so the 700-weight instance this heading uses registers as
/// `BricolageGrotesque-96ptExtraBold_Bold`, not `BricolageGrotesque-Bold`.
/// Confirmed empirically via `NSFontManager.availableMembers(ofFontFamily:)`
/// — `TextRoleStyleTests` pins it so an upstream font rebuild that shifts
/// the default instance is caught instead of silently falling back to the
/// system font.
private let headingFont = Font.custom(
    "BricolageGrotesque-96ptExtraBold_Bold", size: 17, relativeTo: .title2
)
private let bodyFont = Font.custom("HankenGrotesk-Regular", size: 13, relativeTo: .body)
private let captionFont = Font.custom("HankenGrotesk-Regular", size: 10, relativeTo: .caption)
private let monospaceFont = Font.custom("JetBrainsMono-Regular", size: 13, relativeTo: .body)
