// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// The colours a surface paints with, from its `tokens.colors` (Core
/// 0.90.0, vauchi/private#814).
struct PresentationPalette: Equatable {
    let background: Color
    let surface: Color
    let surfaceInput: Color
    let surfaceMuted: Color
    let surfaceElevated: Color
    let text: Color
    let textMuted: Color
    let textOnAccent: Color
    let accent: Color
    let border: Color
    let focusRing: Color
    let success: Color
    let warning: Color
    let error: Color

    static let system = PresentationPalette(
        background: Color(nsColor: .windowBackgroundColor),
        surface: Color(nsColor: .controlBackgroundColor),
        surfaceInput: Color(nsColor: .controlBackgroundColor),
        surfaceMuted: Color(nsColor: .controlBackgroundColor),
        surfaceElevated: Color(nsColor: .controlBackgroundColor),
        text: Color(nsColor: .labelColor),
        textMuted: Color(nsColor: .secondaryLabelColor),
        textOnAccent: Color(nsColor: .alternateSelectedControlTextColor),
        accent: .accentColor,
        border: Color(nsColor: .separatorColor),
        focusRing: .accentColor,
        success: .green,
        warning: .orange,
        error: .red
    )
}

extension PresentationPalette {
    init(colors _: PresentationColors?) {
        self = .system
    }

    static func color(hex _: String) -> Color? {
        nil
    }
}

private struct PresentationPaletteKey: EnvironmentKey {
    static let defaultValue = PresentationPalette.system
}

extension EnvironmentValues {
    var presentationPalette: PresentationPalette {
        get { self[PresentationPaletteKey.self] }
        set { self[PresentationPaletteKey.self] = newValue }
    }
}
