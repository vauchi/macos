// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Renders Component::Indicator — chrome-positioned status chip (macOS).
// Distinct from StatusIndicatorComponentView (body-positioned).
// Ported from ios/Vauchi/CoreUI/Components/IndicatorView.swift; only the
// iOS-only `tertiarySystemBackground` UIColor is swapped for the macOS
// `controlBackgroundColor` (see StatusIndicatorComponentView).

import CoreUIModels
import SwiftUI

/// Renders a core `Component::Indicator` as a compact native chip
/// conveying ongoing status. Tappable when `actionId` is non-nil — the
/// core-injected sync chrome uses this to forward `sync_now`.
struct IndicatorComponentView: View {
    let component: IndicatorComponent
    let onAction: (UserAction) -> Void
    @Environment(\.designTokens) private var tokens

    var body: some View {
        Group {
            if let actionId = component.actionId {
                Button(action: { onAction(.actionPressed(actionId: actionId)) }, label: { chip })
                    .buttonStyle(.plain)
            } else {
                chip
            }
        }
        .accessibilityLabel(component.a11y?.label ?? component.label)
        .accessibilityHint(component.a11y?.hint ?? "")
    }

    private var chip: some View {
        HStack(spacing: 6) {
            iconForKind
            Text(component.label)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundColor(textColor)
        .background(backgroundColor)
        .cornerRadius(CGFloat(tokens.borderRadius.sm))
    }

    @ViewBuilder
    private var iconForKind: some View {
        switch component.kind {
        case .active:
            Image(systemName: "checkmark.circle.fill")
                .imageScale(.small)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .imageScale(.small)
        case .neutral:
            Image(systemName: "circle")
                .imageScale(.small)
        case .busy:
            ProgressView()
                .controlSize(.mini)
        }
    }

    private var textColor: Color {
        switch component.kind {
        case .active: .green
        case .error: .orange
        case .neutral: .secondary
        case .busy: .primary
        }
    }

    private var backgroundColor: Color {
        switch component.kind {
        case .active: Color.green.opacity(0.12)
        case .error: Color.orange.opacity(0.12)
        case .neutral: Color(nsColor: .controlBackgroundColor)
        case .busy: Color(nsColor: .controlBackgroundColor)
        }
    }
}
