// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// CoreSceneView.swift
// Generic SwiftUI shell that drives the core engine through a named
// screen subtree, isolated from the main window's `currentScreen`.
// Used inside SwiftUI `Scene`s (Settings window, future About panel)
// where the lifecycle differs from a sheet: navigate on appear,
// restore the main window's screen on disappear, reload (not close)
// on `complete`.
//
// Per ADR-021/043, this shell holds no domain state, no nav decisions,
// and references no domain types. The screen-id is a parameter so
// the same component renders any core scene; the previous
// `SettingsWindowView` hardcoded `"Settings"`.

import CoreUIModels
import SwiftUI

#if canImport(VauchiPlatform)
    import VauchiPlatform

    /// Renders a core-provided screen inside a SwiftUI `Scene`
    /// (e.g. the macOS Settings window, future About panel).
    ///
    /// Navigates the AppEngine to `screenName` on appear, restores the
    /// main window's screen on disappear. Action results are applied
    /// locally so the main window's state is not clobbered.
    struct CoreSceneView: View {
        /// Opaque navigation token for the screen subtree to enter on
        /// appear (the snake_case `screen_id`, e.g. `"settings"`).
        /// Forwarded verbatim via `UserAction::NavigateToTab` — never a
        /// domain screen-name (ADR-043 Am4).
        let actionId: String

        @EnvironmentObject var appState: AppState
        @ObservedObject private var localizationService = LocalizationService.shared
        @State private var screen: ScreenModel?
        @State private var error: String?

        var body: some View {
            Group {
                if let screen {
                    ScreenRendererView(screen: screen, onAction: handleAction)
                } else if let error {
                    Text(localizationService.t(
                        "settings.failed_to_load",
                        args: ["error": error]
                    ))
                    .foregroundColor(.secondary)
                    .padding()
                } else {
                    ProgressView(localizationService.t("settings.loading"))
                        .padding()
                }
            }
            .onAppear { loadScreen() }
            .onDisappear {
                // Restore the main window's screen state — the scene
                // navigated the engine away; bring it back.
                appState.viewModel?.loadScreen()
            }
        }

        // MARK: - Engine glue

        private func loadScreen() {
            guard let viewModel = appState.viewModel else {
                error = "App not initialized"
                return
            }
            do {
                // Enter the subtree via the typed `NavigateToTab` path
                // (the `navigate_to_json` UniFFI surface was retired,
                // ADR-043 Am4 / core 0.51.35). Core resolves `actionId`
                // to the target screen and returns it as a `navigateTo`
                // result; we render it locally so the main window's
                // state is not clobbered.
                let action = UserAction.navigateToTab(actionId: actionId)
                let actionData = try coreJSONEncoder.encode(action)
                guard let actionJson = String(data: actionData, encoding: .utf8)
                else {
                    error = "Invalid JSON"
                    return
                }
                let resultJson = try viewModel.appEngine.handleActionJson(
                    actionJson: actionJson
                )
                guard let resultData = resultJson.data(using: .utf8) else {
                    error = "Invalid JSON"
                    return
                }
                let envelope = try coreJSONDecoder.decode(
                    ActionResultEnvelope.self, from: resultData
                )
                applyResult(envelope.actionResult)
            } catch {
                self.error = error.localizedDescription
            }
        }

        private func handleAction(_ action: UserAction) {
            guard let viewModel = appState.viewModel else { return }
            do {
                let actionData = try coreJSONEncoder.encode(action)
                guard let actionJson = String(data: actionData, encoding: .utf8)
                else { return }
                let resultJson = try viewModel.appEngine.handleActionJson(
                    actionJson: actionJson
                )
                guard let resultData = resultJson.data(using: .utf8) else { return }
                let result = try coreJSONDecoder.decode(
                    ActionResult.self, from: resultData
                )
                applyResult(result)
            } catch {
                self.error = error.localizedDescription
            }
        }

        private func applyResult(_ result: ActionResult) {
            switch result {
            case let .updateScreen(screen), let .navigateTo(screen):
                self.screen = screen
            case .complete:
                // Setting changed — reload to reflect new state. Scenes
                // (unlike sheets) stay open after `.complete`.
                loadScreen()
            case .startDeviceLink:
                // Sheet content (`CoreSheetView` for `"DeviceLinking"`)
                // navigates the engine on appear; core's
                // `after_screen_transition` hook owns the orchestrator
                // session lifecycle, so the view just flips the sheet flag.
                appState.viewModel?.showDeviceLinkSheet = true
            default:
                // Other results (alerts, urls, …) — reload the scene so
                // any side effect on the underlying screen is reflected.
                loadScreen()
            }
        }
    }
#endif
