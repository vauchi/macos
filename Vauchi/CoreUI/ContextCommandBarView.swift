// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Where Core's context-bar slots go. Core still sends one `ContextBar`
/// per surface, but no shell draws it as a row of its own any more: Back
/// and Navigate sit at the leading end of `PresentationSurfaceView`'s
/// title row, Actions and Info at the trailing end, and Primary becomes a
/// full-width button at the bottom of the surface
/// (vauchi/private#479, #534). Kept out of the view so
/// `ContextCommandBarLayoutTests` can assert it without rendering.
enum ContextCommandBarLayout {
    enum Slot: Equatable {
        case back
        case navigation
        case primary
        case secondary
        case info
    }

    /// The slots Core filled, in drawing order. An absent action takes no
    /// space. While the sidebar is on screen the navigation launcher is left
    /// out: both open the same destinations (vauchi/private#479).
    static func slots(bar: PresentationContextBar?, navigationShown: Bool = false) -> [Slot] {
        guard let bar else { return [] }
        var slots: [Slot] = []
        if bar.back != nil {
            slots.append(.back)
        }
        if bar.navigation != nil, !navigationShown {
            slots.append(.navigation)
        }
        if bar.primary != nil {
            slots.append(.primary)
        }
        if bar.secondary != nil {
            slots.append(.secondary)
        }
        if bar.info != nil {
            slots.append(.info)
        }
        return slots
    }

    /// Back and Navigate, title-row leading end, in Core's slot order.
    static func leadingTitleSlots(bar: PresentationContextBar?, navigationShown: Bool = false) -> [Slot] {
        slots(bar: bar, navigationShown: navigationShown).filter { $0 == .back || $0 == .navigation }
    }

    /// Actions and Info, title-row trailing end, in Core's slot order.
    static func trailingTitleSlots(bar: PresentationContextBar?) -> [Slot] {
        slots(bar: bar).filter { $0 == .secondary || $0 == .info }
    }

    /// Stable frontend a11y anchor for UI tests, matching the iOS shell's
    /// `command.*` identifiers.
    static func accessibilityIdentifier(for slot: Slot) -> String {
        switch slot {
        case .back: "command.back"
        case .navigation: "command.navigation"
        case .primary: "command.primary"
        case .secondary: "command.secondary"
        case .info: "command.info"
        }
    }

    /// English fallback for the title row's icon-only buttons' tooltip;
    /// Core's own `accessibility_label` still drives VoiceOver.
    static func helpText(for slot: Slot) -> String {
        switch slot {
        case .back: "Back"
        case .navigation: "Navigate"
        case .primary: ""
        case .secondary: "More actions"
        case .info: "Info"
        }
    }

    static func keyboardShortcut(for slot: Slot) -> KeyboardShortcut {
        switch slot {
        case .navigation: KeyboardShortcut("k", modifiers: .command)
        case .secondary: KeyboardShortcut(.downArrow, modifiers: .option)
        case .info: KeyboardShortcut("?", modifiers: .command)
        case .back, .primary: KeyboardShortcut("[", modifiers: .command)
        }
    }
}
