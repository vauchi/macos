// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct ContextCommandBarView: View {
    let surfaceID: String
    let bar: PresentationContextBar?
    let tokens: PresentationTokens?
    let reducedMotion: Bool
    let focusedBinding: FocusState<String?>.Binding
    let onEvent: (PresentationEvent) -> Void

    private var minimumTarget: CGFloat {
        PresentationTokens.minimumTargetSize(from: tokens)
    }

    var body: some View {
        HStack(spacing: 8) {
            roleButton(
                bar?.back,
                systemImage: "arrow.left",
                role: "Back"
            )
            roleButton(
                bar?.navigation,
                systemImage: "line.3.horizontal",
                role: "Navigate"
            )
            if let primary = bar?.primary {
                Button(primary.label) {
                    activate(primary)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(minWidth: 140)
                .disabled(!primary.enabled)
                .accessibilityLabel(primary.accessibilityLabel)
                .keyboardShortcut(
                    primary.shortcut == .undo ? "z" : .return,
                    modifiers: .command
                )
                .keyboardFocusRing(
                    focusedBinding,
                    equals: primary.interactionID,
                    color: ThemeService.shared.focusRing
                )
            } else {
                Spacer(minLength: 140)
            }
            roleButton(
                bar?.secondary,
                systemImage: "ellipsis",
                role: "More actions"
            )
        }
        .padding(8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.25))
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Contextual commands")
    }

    @ViewBuilder
    private func roleButton(
        _ action: PresentationAction?,
        systemImage: String,
        role: String
    ) -> some View {
        if let action {
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
        } else {
            Spacer(minLength: minimumTarget)
        }
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
        default: "command.secondary"
        }
    }

    private func shortcut(for role: String) -> KeyboardShortcut {
        switch role {
        case "Navigate":
            KeyboardShortcut("k", modifiers: .command)
        case "More actions":
            KeyboardShortcut(.downArrow, modifiers: .option)
        default:
            KeyboardShortcut("[", modifiers: .command)
        }
    }
}
