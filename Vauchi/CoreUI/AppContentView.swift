// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Authentication shell plus the generic Core-driven presentation host.

import SwiftUI

#if canImport(VauchiPlatform)
    import VauchiPlatform

    struct ContentView: View {
        @EnvironmentObject var appState: AppState

        var body: some View {
            Group {
                if appState.isAuthenticationRequired {
                    LockScreenView(onUnlock: { appState.authenticateAndRetry() })
                } else if let error = appState.error {
                    ErrorView(message: error)
                } else if let viewModel = appState.viewModel {
                    AppContentView(viewModel: viewModel)
                } else {
                    ProgressView(LocalizationService.shared.t("app.initializing"))
                }
            }
            // Zero-sized and invisible; it exists only to reach the
            // window's content container through AppKit. See
            // WindowContentAccessibility for why SwiftUI modifiers
            // cannot address that element without breaking window
            // resolution.
            .background(
                WindowContentAccessibility()
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            )
        }
    }

    struct AppContentView: View {
        @ObservedObject var viewModel: AppViewModel

        var body: some View {
            PresentationHostView(viewModel: viewModel)
                .onDisappear {
                    viewModel.cancelWakeupTimer()
                }
        }
    }
#endif
