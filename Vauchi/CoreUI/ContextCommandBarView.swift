// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct ContextCommandBarView: View {
    let surfaceID: String
    let bar: PresentationContextBar?
    let reducedMotion: Bool
    let onEvent: (PresentationEvent) -> Void

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
            .help(role)
            .keyboardShortcut(shortcut(for: role))
        } else {
            Spacer(minLength: 44)
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
