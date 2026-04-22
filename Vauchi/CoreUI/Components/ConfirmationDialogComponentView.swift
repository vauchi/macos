// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// ConfirmationDialogComponentView.swift
// Renders a ConfirmationDialog component from core UI (macOS)

import CoreUIModels
import SwiftUI
#if canImport(VauchiPlatform)
    import VauchiPlatform
#endif

/// Renders a core `Component::ConfirmationDialog` as a title, message, and action buttons.
struct ConfirmationDialogComponentView: View {
    let component: ConfirmationDialogComponent
    let onAction: (UserAction) -> Void

    @Environment(\.designTokens) private var tokens
    @ObservedObject private var localizationService = LocalizationService.shared
    @EnvironmentObject private var themeService: ThemeService

    var body: some View {
        VStack(spacing: 16) {
            Text(component.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(component.message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button {
                    onAction(.actionPressed(actionId: "cancel"))
                } label: {
                    Text(localizationService.t("action.cancel"))
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CGFloat(tokens.borderRadius.mdLg))
                        .background(Color(nsColor: .quaternaryLabelColor))
                        .cornerRadius(CGFloat(tokens.borderRadius.mdLg))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizationService.t("action.cancel"))

                Button {
                    onAction(.actionPressed(actionId: "confirm"))
                } label: {
                    Text(component.confirmText)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CGFloat(tokens.borderRadius.mdLg))
                        .background(component.destructive ? themeService.error : themeService.accent)
                        .cornerRadius(CGFloat(tokens.borderRadius.mdLg))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(component.confirmText)
            }
        }
        .padding(CGFloat(tokens.spacing.md))
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(CGFloat(tokens.borderRadius.mdLg))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
