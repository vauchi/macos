// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// CoreSheetView.swift
// Generic SwiftUI Sheet shell that drives the core engine through a
// named screen subtree, isolated from the main window's
// `currentScreen`. macOS counterpart of iOS's `CoreScreenView`,
// adapted for the macOS sheet lifecycle: navigate on appear, render
// via `ScreenRendererView`, dispatch actions through the shared
// `PlatformAppEngine`, apply local `ActionResult`s, and emit a
// `cancel` `UserAction` on user-initiated dismiss when the sheet
// flow is still active.
//
// Per ADR-021/043, the sheet holds no domain state, no nav decisions,
// and references no domain types. All flow state lives in core's
// engine; the sheet is a renderer.
//
// Replaces the per-sheet engine glue (loadScreen / handleAction /
// applyResult / cancelIfStillLinking) that each sheet previously
// duplicated — see the retired `DeviceLinkSheet` for the prior
// pattern.

import CoreUIModels
import SwiftUI

#if canImport(VauchiPlatform)
    import VauchiPlatform

    struct CoreSheetView: View {
        /// Opaque navigation token for the screen subtree to enter on
        /// appear (the snake_case `screen_id`, e.g. `"device_linking"`).
        /// Forwarded verbatim via `UserAction::NavigateToTab` — never a
        /// domain screen-name (ADR-043 Am4).
        let actionId: String

        /// Shared `AppViewModel` whose `appEngine` drives the flow.
        @ObservedObject var viewModel: AppViewModel

        /// Called when core emits `ActionResult.complete` (or
        /// `wipeComplete`). The caller closes the sheet.
        let onComplete: () -> Void

        /// Predicate over the current screen ID; if true on `onDisappear`,
        /// emit `UserAction.actionPressed("cancel")` so core ends the flow.
        /// Default: never cancel (caller opts in).
        var cancelIfScreenMatches: (String) -> Bool = { _ in false }

        @State private var screen: ScreenModel?
        @State private var error: String?

        var body: some View {
            Group {
                if let screen {
                    ScreenRendererView(screen: screen, onAction: handleAction)
                } else if let error {
                    Text(error)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ProgressView()
                        .padding()
                }
            }
            .onAppear { loadScreen() }
            .onDisappear { cancelIfStillActive() }
        }

        // MARK: - Engine glue

        private func loadScreen() {
            do {
                // Enter the subtree via the typed `NavigateToTab` path
                // (the `navigate_to_json` UniFFI surface was retired,
                // ADR-043 Am4 / core 0.51.35). Core resolves `actionId`
                // to the target screen and returns it as a `navigateTo`
                // result; we render it locally, isolated from the main
                // window's `currentScreen`.
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
            case .complete, .wipeComplete:
                onComplete()
            default:
                // Other variants (showAlert, openContact, …) belong to
                // the main window's flow, not the sheet subtree.
                break
            }
        }

        /// Sheet was dismissed (system gesture, button outside the
        /// flow, etc.). If core hasn't already routed away from the
        /// sheet's screen subtree, send `cancel` so the engine ends
        /// the flow cleanly.
        private func cancelIfStillActive() {
            guard let id = screen?.screenId, cancelIfScreenMatches(id) else {
                return
            }
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
