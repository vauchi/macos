// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// StateViews.swift
// Native error / loading state views surfaced by `ContentView` while
// `AppState` is initializing or a startup error is present. Both are
// pure presentation — no state, no logic.

import SwiftUI

#if canImport(VauchiPlatform)
    struct ErrorView: View {
        let message: String

        @Environment(\.designTokens) private var tokens

        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)

                Text(LocalizationService.shared.t("app.failed_to_start"))
                    .font(.title2.bold())

                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(CGFloat(tokens.spacing.xl))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    struct LoadingView: View {
        var body: some View {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)

                Text(LocalizationService.shared.t("app.loading"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
#endif
