// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreUIModels
import SwiftUI

/// Renders a core `Component::StatusIndicator` as a read-only status display.
struct StatusIndicatorComponentView: View {
    let component: StatusIndicatorComponent

    @Environment(\.designTokens) private var tokens
    @EnvironmentObject private var themeService: ThemeService

    var body: some View {
        HStack(spacing: 12) {
            if let icon = component.icon {
                Image(systemName: sfSymbolForCoreIcon(icon))
                    .font(.system(size: 24))
                    .foregroundColor(themeService.accent)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(component.title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primary)

                if let detail = component.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Circle()
                .fill(statusColor(for: component.status))
                .frame(width: 12, height: 12)
                .accessibilityLabel(component.statusLabel)
        }
        .padding(CGFloat(tokens.spacing.md))
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(CGFloat(tokens.borderRadius.mdLg))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(component.a11y?.label ?? component.title)
        .accessibilityValue(component.statusLabel)
        .accessibilityHint(component.a11y?.hint ?? "")
    }

    private func statusColor(for status: Status) -> Color {
        switch status {
        case .pending: .gray
        case .inProgress: themeService.accent
        case .success: themeService.success
        case .failed: themeService.error
        case .warning: themeService.warning
        }
    }
}
