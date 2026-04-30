// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// DeviceLinkSheet.swift
// Pair 5b of `_private/docs/problems/2026-04-28-pure-humble-ui-retire-native-screens`.
//
// Pure Humble UI shell — renders the device-link flow via the core
// `DeviceLinkingEngine`. The cycle-thread session lifecycle is owned
// by `PlatformAppEngine` (`after_screen_transition` auto-creates and
// cancels the `MobileDeviceLinkSession` on entry / exit of
// `AppScreen::DeviceLinking`).
//
// Per ADR-021/043 this view holds no domain state, no nav decisions,
// and references no domain types. It only:
//   1. Navigates the engine to `device_linking` on appear and renders
//      whatever screen core publishes (transport selection, QR display,
//      confirming-device, proximity verification, success/failed —
//      all driven by core).
//   2. Emits a `UserAction("cancel")` to core when SwiftUI dismisses
//      the sheet without core having routed away.

import CoreUIModels
import SwiftUI

#if canImport(VauchiPlatform)
    import VauchiPlatform

    struct DeviceLinkSheet: View {
        @ObservedObject var viewModel: AppViewModel
        @ObservedObject private var localizationService = LocalizationService.shared
        @Environment(\.designTokens) private var tokens

        @State private var screen: ScreenModel?
        @State private var error: String?

        var body: some View {
            Group {
                if let screen {
                    ScreenRendererView(screen: screen, onAction: handleAction)
                } else if let error {
                    Text(localizationService.t(
                        "device_link.failed_to_load",
                        args: ["error": error]
                    ))
                    .foregroundColor(.secondary)
                    .padding()
                } else {
                    ProgressView()
                        .padding()
                }
            }
            .padding(CGFloat(tokens.spacing.lg))
            .frame(width: 400)
            .frame(minHeight: 450)
            .onAppear { loadScreen() }
            .onDisappear { cancelIfStillLinking() }
        }

        // MARK: - Engine glue

        private func loadScreen() {
            do {
                let json = try viewModel.appEngine.navigateToJson(
                    screenJson: "\"DeviceLinking\""
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
                // Core ended the flow (success / cancel / done). Close sheet.
                viewModel.showDeviceLinkSheet = false
            default:
                // Other results don't apply to the device-link subtree.
                break
            }
        }

        /// Sheet dismissed without an explicit Cancel tap (e.g. system
        /// gesture). If core hasn't already routed away from the
        /// device-link subtree, send `cancel` so the engine ends the
        /// cycle thread and navigates back.
        private func cancelIfStillLinking() {
            guard screen?.screenId.hasPrefix("link_") == true else { return }
            do {
                let action = UserAction.actionPressed(actionId: "cancel")
                let actionData = try coreJSONEncoder.encode(action)
                guard let actionJson = String(data: actionData, encoding: .utf8)
                else { return }
                _ = try viewModel.appEngine.handleActionJson(
                    actionJson: actionJson
                )
            } catch {
                // Best-effort cleanup; engine state is consistent regardless.
            }
        }
    }
#endif
