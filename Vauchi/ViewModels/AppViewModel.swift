// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// AppViewModel.swift
// Wraps PlatformAppEngine to drive ScreenRendererView for all screens

import Foundation
import SwiftUI

#if canImport(VauchiPlatform)
    import VauchiPlatform

    @MainActor
    class AppViewModel: ObservableObject {
        @Published var currentScreen: ScreenModel?
        @Published var validationErrors: [String: String] = [:]
        @Published var alertMessage: AlertMessage?

        private let appEngine: PlatformAppEngine

        struct AlertMessage: Identifiable {
            let id = UUID()
            let title: String
            let message: String
        }

        init(appEngine: PlatformAppEngine) {
            self.appEngine = appEngine
            loadScreen()
        }

        /// Loads the current screen from the core engine.
        func loadScreen() {
            do {
                let json = try appEngine.currentScreenJson()
                guard let data = json.data(using: .utf8) else {
                    print("AppViewModel: failed to convert JSON to Data")
                    return
                }
                currentScreen = try coreJSONDecoder.decode(ScreenModel.self, from: data)
                validationErrors = [:]
            } catch {
                print("AppViewModel: failed to load screen: \(error)")
            }
        }

        /// Handles a user action by forwarding it to the core engine.
        func handleAction(_ action: UserAction) {
            do {
                let actionData = try coreJSONEncoder.encode(action)
                guard let actionJson = String(data: actionData, encoding: .utf8) else {
                    print("AppViewModel: failed to encode action to JSON string")
                    return
                }

                let resultJson = try appEngine.handleActionJson(actionJson: actionJson)
                guard let resultData = resultJson.data(using: .utf8) else {
                    print("AppViewModel: failed to convert result JSON to Data")
                    return
                }

                let result = try coreJSONDecoder.decode(ActionResult.self, from: resultData)
                applyResult(result)
            } catch {
                print("AppViewModel: failed to handle action: \(error)")
            }
        }

        /// Navigate to a specific screen.
        func navigateTo(screenJson: String) {
            do {
                let json = try appEngine.navigateToJson(screenJson: screenJson)
                guard let data = json.data(using: .utf8) else { return }
                currentScreen = try coreJSONDecoder.decode(ScreenModel.self, from: data)
                validationErrors = [:]
            } catch {
                print("AppViewModel: failed to navigate: \(error)")
            }
        }

        /// Navigate back in the history stack.
        func navigateBack() {
            do {
                let json = try appEngine.navigateBackJson()
                guard let data = json.data(using: .utf8) else { return }
                currentScreen = try coreJSONDecoder.decode(ScreenModel.self, from: data)
                validationErrors = [:]
            } catch {
                print("AppViewModel: failed to navigate back: \(error)")
            }
        }

        /// Invalidate cached engines after VauchiPlatform mutations.
        func invalidateAll() {
            do {
                try appEngine.invalidateAll()
                loadScreen()
            } catch {
                print("AppViewModel: failed to invalidate: \(error)")
            }
        }

        // MARK: - Private

        private func applyResult(_ result: ActionResult) {
            switch result {
            case let .updateScreen(screen):
                currentScreen = screen
                validationErrors = [:]

            case let .navigateTo(screen):
                currentScreen = screen
                validationErrors = [:]

            case let .validationError(componentId, message):
                validationErrors[componentId] = message

            case .complete:
                // Onboarding complete or form submitted — reload screen
                loadScreen()

            case let .openUrl(url):
                if let nsUrl = URL(string: url) {
                    NSWorkspace.shared.open(nsUrl)
                }

            case let .showAlert(title, message):
                alertMessage = AlertMessage(title: title, message: message)

            case let .openContact(contactId):
                do {
                    let payload = try JSONSerialization.data(
                        withJSONObject: ["ContactDetail": ["contact_id": contactId]]
                    )
                    if let screenJson = String(data: payload, encoding: .utf8) {
                        navigateTo(screenJson: screenJson)
                    }
                } catch {
                    print("AppViewModel: failed to encode ContactDetail: \(error)")
                }

            case let .editContact(contactId):
                do {
                    let payload = try JSONSerialization.data(
                        withJSONObject: ["ContactEdit": ["contact_id": contactId]]
                    )
                    if let screenJson = String(data: payload, encoding: .utf8) {
                        navigateTo(screenJson: screenJson)
                    }
                } catch {
                    print("AppViewModel: failed to encode ContactEdit: \(error)")
                }

            case let .openEntryDetail(fieldId):
                do {
                    let payload = try JSONSerialization.data(
                        withJSONObject: ["EntryDetail": ["field_id": fieldId]]
                    )
                    if let screenJson = String(data: payload, encoding: .utf8) {
                        navigateTo(screenJson: screenJson)
                    }
                } catch {
                    print("AppViewModel: failed to encode EntryDetail: \(error)")
                }

            case let .showToast(message, _):
                // TODO: Implement proper toast UI; for now show as alert
                alertMessage = AlertMessage(title: "", message: message)

            case .wipeComplete:
                loadScreen()

            case .requestCamera:
                alertMessage = AlertMessage(
                    title: "Camera Not Available",
                    message: "QR scanning is not available on macOS. Use another device to scan."
                )

            case .startDeviceLink, .startBackupImport:
                // These require platform-specific flows — handled by VauchiRepository
                break
            }
        }
    }
#endif
