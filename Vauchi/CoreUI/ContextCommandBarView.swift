// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Where Core's context-bar slots go, kept out of the view so
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

    /// On the desktop every role button already writes its word beside the
    /// icon; the back arrow keeps its word too, since there is room.
    static func showsLabel(_ slot: Slot) -> Bool {
        slot != .primary
    }

    /// The primary button sits in the middle; without one a gap keeps Back
    /// leading and the launchers trailing.
    static func needsFlexibleGap(slots: [Slot]) -> Bool {
        !slots.contains(.primary)
    }
}

/// Core's context bar as one row under the content, on the window's own
/// surface rather than a floating card.
struct ContextCommandBarView: View {
    let surfaceID: String
    let bar: PresentationContextBar?
    let tokens: PresentationTokens?
    let reducedMotion: Bool
    let focusedBinding: FocusState<String?>.Binding
    let navigationShown: Bool
    let onEvent: (PresentationEvent) -> Void

    private var minimumTarget: CGFloat {
        PresentationTokens.minimumTargetSize(from: tokens)
    }

    var body: some View {
        let slots = ContextCommandBarLayout.slots(bar: bar, navigationShown: navigationShown)
        if !slots.isEmpty {
            HStack(spacing: 8) {
                if let back = bar?.back {
                    roleButton(back, systemImage: "arrow.left", role: "Back")
                }
                if let navigation = bar?.navigation, slots.contains(.navigation) {
                    roleButton(navigation, systemImage: "line.3.horizontal", role: "Navigate")
                }
                if let primary = bar?.primary {
                    primaryButton(primary)
                }
                if ContextCommandBarLayout.needsFlexibleGap(slots: slots) {
                    Spacer(minLength: 0)
                }
                if let secondary = bar?.secondary {
                    roleButton(secondary, systemImage: "ellipsis", role: "More actions")
                }
                if let info = bar?.info {
                    roleButton(info, systemImage: "info.circle", role: "Info")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(.bar)
            .overlay(alignment: .top) {
                Divider()
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Contextual commands")
        }
    }

    private func primaryButton(_ primary: PresentationAction) -> some View {
        Button(primary.label) {
            activate(primary)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(minWidth: 140)
        .disabled(!primary.enabled)
        .accessibilityLabel(primary.accessibilityLabel)
        .accessibilityIdentifier("command.primary")
        .keyboardShortcut(
            primary.shortcut == .undo ? "z" : .return,
            modifiers: .command
        )
        .keyboardFocusRing(
            focusedBinding,
            equals: primary.interactionID,
            color: ThemeService.shared.focusRing
        )
    }

    private func roleButton(
        _ action: PresentationAction,
        systemImage: String,
        role: String
    ) -> some View {
        Button {
            activate(action)
        } label: {
            Label(action.label, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
        }
        .disabled(!action.enabled)
        .accessibilityLabel(action.accessibilityLabel)
        // Stable frontend a11y anchor for UI tests, matching the iOS
        // shell's `command.*` identifiers.
        .accessibilityIdentifier(identifier(for: role))
        .help(role)
        .keyboardShortcut(shortcut(for: role))
        .keyboardFocusRing(
            focusedBinding,
            equals: action.interactionID,
            color: ThemeService.shared.focusRing
        )
    }

    private func activate(_ action: PresentationAction) {
        withAnimation(reducedMotion ? nil : .easeOut(duration: 0.2)) {
            onEvent(
                .actionActivated(
                    surfaceID: surfaceID,
                    interactionID: action.interactionID
                )
            )
        }
    }

    private func identifier(for role: String) -> String {
        switch role {
        case "Back": "command.back"
        case "Navigate": "command.navigation"
        case "Info": "command.info"
        default: "command.secondary"
        }
    }

    private func shortcut(for role: String) -> KeyboardShortcut {
        switch role {
        case "Navigate":
            KeyboardShortcut("k", modifiers: .command)
        case "More actions":
            KeyboardShortcut(.downArrow, modifiers: .option)
        case "Info":
            KeyboardShortcut("?", modifiers: .command)
        default:
            KeyboardShortcut("[", modifiers: .command)
        }
    }
}
