// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// The Mac's light/dark setting, read from the application rather than the
/// view environment: the window takes the active theme's style
/// (`PresentationPalette.appearance`), so its own `colorScheme` stops
/// saying what the OS is set to, and Core needs the OS value for
/// "follow system" (vauchi/private#814).
@MainActor
final class SystemAppearance: ObservableObject {
    @Published private(set) var colorScheme: PresentationColorScheme
    private var observation: NSKeyValueObservation?

    init(application: NSApplication = .shared) {
        colorScheme = Self.scheme(of: application.effectiveAppearance)
        observation = application.observe(\.effectiveAppearance) { [weak self] application, _ in
            let scheme = Self.scheme(of: application.effectiveAppearance)
            Task { @MainActor in self?.colorScheme = scheme }
        }
    }

    nonisolated static func scheme(of appearance: NSAppearance) -> PresentationColorScheme {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
    }
}
