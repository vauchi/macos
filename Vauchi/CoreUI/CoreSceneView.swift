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
        /// Core screen name to navigate to on appear (e.g. `"Settings"`).
        let screenName: String

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
                let json = try viewModel.appEngine.navigateToJson(
                    screenJson: "\"\(screenName)\""
                )
                guard let data = json.data(using: .utf8) else {
                    error = "Invalid JSON"
                    return
                }
                screen = try coreJSONDecoder.decode(ScreenModel.self, from: data)
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
            case .startBackupImport:
                // Phase 2B retired StartBackupImport emission on core
                // (backup-restore now flows through Onboarding's
                // `restore_backup` → FilePickFromUser path). The variant
                // remains in the enum as a chrome hint until Phase 4;
                // no-op so we stay forward-compatible with any straggler
                // emitter and don't open a deleted sheet.
                break
            case .startDeviceLink:
                // Sheet content (`CoreSheetView` for `"DeviceLinking"`)
                // navigates the engine on appear; `after_screen_transition`
                // creates the `MobileDeviceLinkSession` automatically.
                appState.viewModel?.showDeviceLinkSheet = true
            default:
                // Other results (alerts, urls, …) — reload the scene so
                // any side effect on the underlying screen is reflected.
                loadScreen()
            }
        }
    }
#endif
