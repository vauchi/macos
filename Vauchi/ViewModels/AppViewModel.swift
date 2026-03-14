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
        let appEngine: PlatformAppEngine
        var vauchi: VauchiPlatform?

        /// Active exchange session (created when user enters Exchange screen).
        private var exchangeSession: MobileExchangeSession?

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
            // Intercept QR paste to drive crypto session before forwarding to UI engine
            if case let .textChanged(componentId, value) = action,
               componentId == "scanned_data"
            {
                processScannedQr(value)
                return
            }

            forwardActionToEngine(action)
        }

        /// Forward an action directly to the core engine (no intercept).
        private func forwardActionToEngine(_ action: UserAction) {
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

        private func navigateToScreen(_ screenObject: [String: Any]) {
            do {
                let payload = try JSONSerialization.data(withJSONObject: screenObject)
                if let screenJson = String(data: payload, encoding: .utf8) {
                    navigateTo(screenJson: screenJson)
                }
            } catch {
                print("AppViewModel: failed to encode screen navigation: \(error)")
            }
        }

        private func applyResult(_ result: ActionResult) {
            switch result {
            case let .updateScreen(screen):
                applyExchangeScreen(screen)
            case let .navigateTo(screen):
                applyExchangeScreen(screen)
            case let .validationError(componentId, message):
                validationErrors[componentId] = message
            case .complete, .wipeComplete:
                exchangeSession = nil
                loadScreen()
            case let .openUrl(url):
                if let nsUrl = URL(string: url) { NSWorkspace.shared.open(nsUrl) }
            case let .showAlert(title, message):
                alertMessage = AlertMessage(title: title, message: message)
            case let .openContact(contactId):
                navigateToScreen(["ContactDetail": ["contact_id": contactId]])
            case let .editContact(contactId):
                navigateToScreen(["ContactEdit": ["contact_id": contactId]])
            case let .openEntryDetail(fieldId):
                navigateToScreen(["EntryDetail": ["field_id": fieldId]])
            case let .showToast(message, _):
                alertMessage = AlertMessage(title: "", message: message)
            case .requestCamera:
                // Load the scan screen — it has camera QR scanning with paste fallback
                loadScreen()
            case .startDeviceLink, .startBackupImport:
                break
            }
        }

        // MARK: - Exchange Session Management

        /// Apply screen update, creating exchange session when entering exchange flow.
        private func applyExchangeScreen(_ screen: ScreenModel) {
            if screen.screenId == "exchange_show_qr", exchangeSession == nil {
                startExchangeSession(screen: screen)
            } else {
                currentScreen = screen
                validationErrors = [:]
            }
        }

        /// Create exchange session and replace QR data with real exchange QR.
        private func startExchangeSession(screen: ScreenModel) {
            guard let vauchi else {
                currentScreen = screen
                validationErrors = [:]
                return
            }

            do {
                let session = try vauchi.createQrExchangeManual()
                let qrData = try session.generateQr()
                exchangeSession = session

                // Replace the public_id QR data with the real exchange QR
                let updatedComponents = screen.components.map { component -> Component in
                    if case let .qrCode(qr) = component, qr.mode == .display {
                        return .qrCode(QrCodeComponent(
                            id: qr.id, data: qrData, mode: qr.mode, label: qr.label
                        ))
                    }
                    return component
                }
                currentScreen = ScreenModel(
                    screenId: screen.screenId,
                    title: screen.title,
                    subtitle: screen.subtitle,
                    components: updatedComponents,
                    actions: screen.actions,
                    progress: screen.progress
                )
                validationErrors = [:]
            } catch {
                print("AppViewModel: failed to create exchange session: \(error)")
                currentScreen = screen
                validationErrors = [:]
            }
        }

        /// Process a pasted QR code from the peer.
        func processScannedQr(_ qrData: String) {
            guard let session = exchangeSession else {
                alertMessage = AlertMessage(
                    title: "Exchange Error",
                    message: "No exchange session active"
                )
                return
            }

            do {
                try session.processQr(qrData: qrData)
                try session.theyScannedOurQr()
                try session.confirmProximity()
                try session.performKeyAgreement()

                let peerName = session.peerDisplayName() ?? "Unknown"
                try session.completeCardExchange(theirCardName: peerName)

                if let vauchi {
                    let result = try vauchi.finalizeExchange(session: session)
                    if result.success {
                        // Tell core engine the exchange succeeded (bypass intercept)
                        forwardActionToEngine(.textChanged(componentId: "scanned_data", value: qrData))
                        // Mark success in the UI engine
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            self?.invalidateAll()
                        }
                    } else {
                        alertMessage = AlertMessage(
                            title: "Exchange Failed",
                            message: result.errorMessage ?? "Unknown error"
                        )
                    }
                }
                exchangeSession = nil
            } catch {
                alertMessage = AlertMessage(
                    title: "Exchange Failed",
                    message: "\(error)"
                )
                exchangeSession = nil
            }
        }
    }
#endif
