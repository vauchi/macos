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
            // The window's content container is otherwise anonymous, which
            // `testAccessibilityAudit` flags as an element with no
            // description. Named here rather than at the `WindowGroup` call
            // site: applied there it lands on the window itself and replaces
            // the identifier XCUITest resolves windows by, which broke
            // `app.windows` lookups (job 16440006443 — three previously
            // green tests failed and the audit's scope escaped to the menu
            // bar).
            //
            // An identifier is not user-facing copy — VoiceOver never speaks
            // it — so this names a structural container without putting
            // accessibility copy in the frontend, which ADR-038/ADR-066 keep
            // in Core.
            .accessibilityIdentifier("vauchi.window.content")
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
