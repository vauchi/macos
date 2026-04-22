// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// ScreenRendererView.swift
// Generic view that renders any ScreenModel from core
//
// macOS adaptation of ios/Vauchi/CoreUI/ScreenRendererView.swift.
// Uses macOS-native styling (NSColor, larger spacing for desktop).

import CoreUIModels
import SwiftUI
#if canImport(VauchiPlatform)
    import VauchiPlatform
#endif

/// Generic view that renders any core `ScreenModel`.
///
/// Given a screen description from core, this view renders:
/// - Progress indicator (if present)
/// - Title and subtitle
/// - All components via `ComponentView`
/// - Action buttons at the bottom
/// - Toast overlay for `ShowToast` components
///
/// User interactions are forwarded via `onAction`.
struct ScreenRendererView: View {
    let screen: ScreenModel
    let onAction: (UserAction) -> Void
    var onQrScanned: ((String) -> Void)?

    @Environment(\.designTokens) private var tokens
    @ObservedObject private var localizationService = LocalizationService.shared
    @State private var toastMessage: String?
    @State private var toastUndoActionId: String?

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // Progress bar
                if let progress = screen.progress {
                    ProgressView(
                        value: Double(progress.currentStep),
                        total: Double(progress.totalSteps)
                    )
                    .tint(.cyan)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .accessibilityLabel(localizationService.t(
                        "a11y.step_of",
                        args: [
                            "current": String(progress.currentStep),
                            "total": String(progress.totalSteps),
                        ]
                    ))
                    .accessibilityValue(progress.label ?? "\(progress.currentStep) of \(progress.totalSteps)")
                }

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text(screen.title)
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)

                            if let subtitle = screen.subtitle {
                                Text(subtitle)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 24)

                        // Components
                        ForEach(Array(screen.components.enumerated()), id: \.offset) { _, component in
                            ComponentView(component: component, onAction: onAction, onQrScanned: onQrScanned)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    ForEach(screen.actions) { action in
                        ActionButton(action: action) {
                            onAction(.actionPressed(actionId: action.id))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            // Toast overlay
            if let message = toastMessage {
                ToastOverlayView(
                    message: message,
                    undoActionId: toastUndoActionId,
                    onAction: onAction,
                    onDismiss: {
                        withAnimation {
                            toastMessage = nil
                            toastUndoActionId = nil
                        }
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
                .padding(.horizontal, 24)
                .zIndex(100)
            }
        }
        .onChange(of: screen.screenId) { _ in
            checkForToastComponent()
        }
        .onChange(of: screen.components.count) { _ in
            checkForToastComponent()
        }
        .onAppear {
            checkForToastComponent()
        }
        .environment(\.designTokens, screen.tokens)
    }

    private func checkForToastComponent() {
        for component in screen.components {
            if case let .showToast(toast) = component {
                let message = toast.message
                withAnimation {
                    toastMessage = message
                    toastUndoActionId = toast.undoActionId
                }
                let dismissDelay = Double(toast.durationMs) / 1000.0
                DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay) {
                    // Only dismiss if this is still the same toast
                    if self.toastMessage == message {
                        withAnimation {
                            self.toastMessage = nil
                            self.toastUndoActionId = nil
                        }
                    }
                }
                break
            }
        }
    }
}

/// Toast overlay view shown at the top of the screen.
struct ToastOverlayView: View {
    let message: String
    let undoActionId: String?
    let onAction: (UserAction) -> Void
    let onDismiss: () -> Void

    @Environment(\.designTokens) private var tokens
    @ObservedObject private var localizationService = LocalizationService.shared
    @EnvironmentObject private var themeService: ThemeService

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(2)

            if let undoId = undoActionId {
                Button(localizationService.t("action.undo")) {
                    onAction(.undoPressed(actionId: undoId))
                    onDismiss()
                }
                .font(.subheadline.bold())
                .foregroundColor(themeService.accent)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, CGFloat(tokens.borderRadius.mdLg))
        .background(
            RoundedRectangle(cornerRadius: CGFloat(tokens.borderRadius.mdLg))
                .fill(Color.black.opacity(0.85))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localizationService.t(
            "a11y.toast_prefix",
            args: ["message": message]
        ))
    }
}

/// Renders a `ScreenAction` as a styled button.
struct ActionButton: View {
    let action: ScreenAction
    let onTap: () -> Void

    @Environment(\.designTokens) private var tokens

    var body: some View {
        Button(action: onTap) {
            Text(action.label)
                .font(isPrimary ? .headline : .subheadline)
                .frame(maxWidth: isPrimary ? .infinity : nil)
                .padding(isPrimary ? CGFloat(tokens.spacing.md) : CGFloat(tokens.spacing.sm))
                .background(background)
                .foregroundColor(foregroundColor)
                .cornerRadius(CGFloat(tokens.borderRadius.mdLg))
        }
        .buttonStyle(.plain)
        .disabled(!action.enabled)
        .opacity(action.enabled ? 1.0 : 0.6)
        // `accessibilityIdentifier` is the stable handle for
        // XCUITest / Maestro / any a11y-driven test driver — the
        // SwiftUI counterpart of GTK widget name / Qt objectName /
        // Compose testTag. Not visible to the user; immune to
        // localization. Plan Task 3.1 /
        // _private/docs/problems/2026-04-20-screen-action-a11y-identifier-gap.
        .accessibilityIdentifier(action.id)
        // Core-provided a11y override: `a11y.label` replaces the
        // visible-text-derived screen-reader announcement;
        // `a11y.hint` surfaces as the VoiceOver hint string.
        // Absent → fall back to `action.label`.
        .accessibilityLabel(action.a11y?.label ?? action.label)
        .accessibilityHint(action.a11y?.hint ?? "")
    }

    private var isPrimary: Bool {
        action.style == .primary || action.style == .destructive
    }

    private var background: Color {
        switch action.style {
        case .primary: .cyan
        case .secondary: .clear
        case .destructive: .red
        }
    }

    private var foregroundColor: Color {
        switch action.style {
        case .primary: .white
        case .secondary: .cyan
        case .destructive: .white
        }
    }
}
