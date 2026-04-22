// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// InlineConfirmComponentView.swift
// Renders an InlineConfirm component from core UI (macOS)

import CoreUIModels
import SwiftUI

/// Renders a core `Component::InlineConfirm` as an inline warning with confirm/cancel buttons.
struct InlineConfirmComponentView: View {
    let component: InlineConfirmComponent
    let onAction: (UserAction) -> Void

    @Environment(\.designTokens) private var tokens
    @EnvironmentObject private var themeService: ThemeService

    var body: some View {
        VStack(spacing: 12) {
            Text(component.warning)
                .font(.callout)
                .foregroundColor(component.destructive ? themeService.error : .primary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    onAction(.actionPressed(actionId: "\(component.id):cancel"))
                } label: {
                    Text(component.cancelText)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CGFloat(tokens.spacing.sm))
                        .background(Color(nsColor: .quaternaryLabelColor))
                        .cornerRadius(CGFloat(tokens.borderRadius.md))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(component.cancelText)

                Button {
                    onAction(.actionPressed(actionId: "\(component.id):confirm"))
                } label: {
                    Text(component.confirmText)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CGFloat(tokens.spacing.sm))
                        .background(component.destructive ? themeService.error : themeService.accent)
                        .cornerRadius(CGFloat(tokens.borderRadius.md))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(component.confirmText)
            }
        }
        .padding(CGFloat(tokens.borderRadius.mdLg))
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(CGFloat(tokens.borderRadius.mdLg))
        .accessibilityLabel(component.a11y?.label ?? component.warning)
        .accessibilityHint(component.a11y?.hint ?? "")
    }
}
