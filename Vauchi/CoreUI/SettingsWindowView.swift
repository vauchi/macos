// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// SettingsWindowView.swift
// Renders the core Settings screen in the macOS Settings window (Cmd+,)

import SwiftUI

#if canImport(VauchiPlatform)
    import VauchiPlatform

    /// Renders the core-provided Settings screen inside the macOS Settings window.
    ///
    /// Navigates the AppEngine to Settings on appear, restores the main window's
    /// screen on disappear. Actions are handled locally to avoid clobbering the
    /// main window's view state.
    struct SettingsWindowView: View {
        @EnvironmentObject var appState: AppState
        @State private var settingsScreen: ScreenModel?
        @State private var error: String?

        var body: some View {
            Group {
                if let screen = settingsScreen {
                    ScreenRendererView(screen: screen, onAction: handleAction)
                } else if let error {
                    Text("Failed to load settings: \(error)")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ProgressView("Loading settings...")
                        .padding()
                }
            }
            .onAppear { loadSettingsScreen() }
            .onDisappear {
                // Restore the main window's screen state
                appState.viewModel?.loadScreen()
            }
        }

        private func loadSettingsScreen() {
            guard let viewModel = appState.viewModel else {
                error = "App not initialized"
                return
            }
            do {
                let json = try viewModel.appEngine.navigateToJson(screenJson: "\"Settings\"")
                guard let data = json.data(using: .utf8) else {
                    error = "Invalid JSON"
                    return
                }
                settingsScreen = try coreJSONDecoder.decode(ScreenModel.self, from: data)
            } catch {
                self.error = error.localizedDescription
            }
        }

        private func handleAction(_ action: UserAction) {
            guard let viewModel = appState.viewModel else { return }
            do {
                let actionData = try coreJSONEncoder.encode(action)
                guard let actionJson = String(data: actionData, encoding: .utf8) else { return }
                let resultJson = try viewModel.appEngine.handleActionJson(actionJson: actionJson)
                guard let resultData = resultJson.data(using: .utf8) else { return }
                let result = try coreJSONDecoder.decode(ActionResult.self, from: resultData)
                applyResult(result)
            } catch {
                print("SettingsWindowView: failed to handle action: \(error)")
            }
        }

        private func applyResult(_ result: ActionResult) {
            switch result {
            case let .updateScreen(screen), let .navigateTo(screen):
                settingsScreen = screen
            case .complete:
                // Setting changed — reload to reflect new state
                loadSettingsScreen()
            case .startBackupImport:
                appState.viewModel?.showImportBackupSheet = true
            case .startDeviceLink:
                // Delegate to the main view model to show the sheet
                if let viewModel = appState.viewModel {
                    viewModel.showDeviceLinkSheet = true
                    viewModel.startDeviceLink()
                }
            default:
                // Other results (alerts, urls, etc.) — reload settings
                loadSettingsScreen()
            }
        }
    }
#endif
