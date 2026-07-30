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
