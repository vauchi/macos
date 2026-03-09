// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// StatusIndicatorComponentView.swift
// Renders a StatusIndicator component from core UI (macOS)

import SwiftUI

/// Renders a core `Component::StatusIndicator` as a read-only status display.
struct StatusIndicatorComponentView: View {
    let component: StatusIndicatorComponent

    var body: some View {
        HStack(spacing: 12) {
            if let icon = component.icon {
                Image(systemName: sfSymbolForCoreIcon(icon))
                    .font(.system(size: 24))
                    .foregroundColor(.cyan)
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
                .accessibilityLabel(statusLabel(for: component.status))
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .accessibilityElement(children: .combine)
    }

    private func statusColor(for status: Status) -> Color {
        switch status {
        case .pending: .gray
        case .inProgress: .blue
        case .success: .green
        case .failed: .red
        case .warning: .orange
        }
    }

    private func statusLabel(for status: Status) -> String {
        switch status {
        case .pending: "Pending"
        case .inProgress: "In progress"
        case .success: "Success"
        case .failed: "Failed"
        case .warning: "Warning"
        }
    }
}
