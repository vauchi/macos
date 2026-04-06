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
        @Published var toastMessage: String?
        @Published var toastUndoActionId: String?
        @Published var showImportBackupSheet = false
        @Published var showDeviceLinkSheet = false
        @Published var deviceLinkState: DeviceLinkState = .idle
        @Published var availableScreens: [String] = []
        @Published var selectedScreen: String?
        let appEngine: PlatformAppEngine
        var vauchi: VauchiPlatform?

        /// Active exchange session (created when user enters Exchange screen).
        private var exchangeSession: MobileExchangeSession?

        /// ADR-031 command handler — dispatches hardware commands from the session.
        private var exchangeCommandHandler: ExchangeCommandHandler?

        /// Active device link initiator (holds session state for confirmation).
        private var currentInitiator: MobileDeviceLinkInitiator?
        private var currentSenderToken: String?

        // MARK: - Device Link State

        enum DeviceLinkState {
            case idle
            case generatingQR
            case waitingForRequest(qrData: String)
            case confirmingDevice(
                name: String, code: String, challenge: Data
            )
            case completing
            case success
            case failed(String)
        }

        struct AlertMessage: Identifiable {
            let id = UUID()
            let title: String
            let message: String
        }

        init(appEngine: PlatformAppEngine) {
            self.appEngine = appEngine
            loadAvailableScreens()
            loadScreen()
        }

        /// Loads available navigation screens from core.
        func loadAvailableScreens() {
            do {
                let json = try appEngine.availableScreensJson()
                guard let data = json.data(using: .utf8) else { return }
                availableScreens = try JSONDecoder().decode([String].self, from: data)
            } catch {
                print("AppViewModel: failed to load available screens: \(error)")
            }
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
                updateSelectedScreen()
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
            teardownExchange()
            do {
                let json = try appEngine.navigateToJson(screenJson: screenJson)
                guard let data = json.data(using: .utf8) else { return }
                currentScreen = try coreJSONDecoder.decode(ScreenModel.self, from: data)
                validationErrors = [:]
                loadAvailableScreens()
                updateSelectedScreen()
            } catch {
                print("AppViewModel: failed to navigate: \(error)")
            }
        }

        /// Navigate back in the history stack.
        func navigateBack() {
            teardownExchange()
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
                loadAvailableScreens()
                loadScreen()
            } catch {
                print("AppViewModel: failed to invalidate: \(error)")
            }
        }

        /// Maps core screen_id prefixes to their AppScreen navigation name.
        /// Screen IDs like "exchange_show_qr" map to "Exchange" via prefix match.
        private static let screenIdPrefixToAppScreen: [(prefix: String, appScreen: String)] = [
            ("my_info", "MyInfo"),
            ("contact", "Contacts"),
            ("exchange", "Exchange"),
            ("groups", "Groups"),
            ("group_detail", "Groups"),
            ("more", "More"),
        ]

        /// Syncs `selectedScreen` from the core's current screen ID.
        private func updateSelectedScreen() {
            guard let screenId = currentScreen?.screenId else { return }
            for mapping in Self.screenIdPrefixToAppScreen where screenId.hasPrefix(mapping.prefix) {
                selectedScreen = mapping.appScreen
                return
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
                teardownExchange()
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
            case let .showToast(message, undoActionId):
                // ActionResult.showToast is triggered by core in response to user actions
                // (e.g. "Field deleted" with undo). Show as overlay toast, not a blocking alert.
                showToast(message, undoActionId: undoActionId)
            case .requestCamera:
                // Load the scan screen — it has camera QR scanning with paste fallback
                loadScreen()
            case .startDeviceLink:
                showDeviceLinkSheet = true
                startDeviceLink()
            case .startBackupImport:
                showImportBackupSheet = true
            case let .exchangeCommands(commands):
                if let handler = exchangeCommandHandler {
                    for command in commands {
                        handler.dispatchDTO(command)
                    }
                }
            case .unknown:
                // Unknown action result from newer core — ignore
                break
            }
        }

        // MARK: - Toast

        /// Show a toast overlay that auto-dismisses after the given duration.
        func showToast(_ message: String, undoActionId: String? = nil, durationMs: UInt32 = 3000) {
            withAnimation {
                toastMessage = message
                toastUndoActionId = undoActionId
            }
            let duration = max(Double(durationMs) / 1000.0, 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                guard let self, self.toastMessage == message else { return }
                withAnimation {
                    self.toastMessage = nil
                    self.toastUndoActionId = nil
                }
            }
        }

        // MARK: - Device Link

        /// Start the device link initiator flow.
        func startDeviceLink() {
            guard let vauchi else {
                deviceLinkState = .failed("App not initialized")
                return
            }

            deviceLinkState = .generatingQR
            Task {
                do {
                    let initiator = try vauchi.startDeviceLink()
                    currentInitiator = initiator
                    let qrData = initiator.qrData()
                    deviceLinkState = .waitingForRequest(
                        qrData: qrData
                    )
                    try await listenForDeviceLinkRequest()
                } catch {
                    deviceLinkState = .failed("\(error)")
                }
            }
        }

        /// Listen for a device link request (blocking relay call).
        private func listenForDeviceLinkRequest() async throws {
            guard let vauchi,
                  let initiator = currentInitiator
            else { return }

            let request = try vauchi.listenForDeviceLinkRequest(
                timeoutSecs: 300
            )
            currentSenderToken = request.senderToken
            let confirmation = try initiator.prepareConfirmation(
                encryptedRequest: request.encryptedPayload
            )
            let challenge = initiator.proximityChallenge()

            deviceLinkState = .confirmingDevice(
                name: confirmation.deviceName,
                code: confirmation.confirmationCode,
                challenge: challenge
            )
        }

        /// Approve the device link with manual confirmation.
        func approveDeviceLink() {
            guard let vauchi,
                  let initiator = currentInitiator,
                  let senderToken = currentSenderToken
            else {
                deviceLinkState = .failed("No active link session")
                return
            }

            guard case let .confirmingDevice(_, code, _) = deviceLinkState
            else { return }

            deviceLinkState = .completing
            Task {
                do {
                    let now = UInt64(Date().timeIntervalSince1970)
                    let result = try initiator.confirmLinkManual(
                        confirmationCode: code,
                        confirmedAt: now
                    )
                    if let response = result.encryptedResponse {
                        try vauchi.sendDeviceLinkResponse(
                            senderToken: senderToken,
                            encryptedResponse: response
                        )
                    }
                    deviceLinkState = .success
                    currentInitiator = nil
                    currentSenderToken = nil
                } catch {
                    deviceLinkState = .failed("\(error)")
                }
            }
        }

        /// Cancel the device link flow and reset state.
        func cancelDeviceLink() {
            deviceLinkState = .idle
            currentInitiator = nil
            currentSenderToken = nil
            showDeviceLinkSheet = false
        }

        // MARK: - Exchange Session Management

        /// Stop hardware services and release the exchange session and handler.
        private func teardownExchange() {
            exchangeCommandHandler?.stop()
            exchangeCommandHandler = nil
            exchangeSession = nil
        }

        /// Apply screen update, creating exchange session when entering exchange flow.
        private func applyExchangeScreen(_ screen: ScreenModel) {
            if screen.screenId == "exchange_show_qr", exchangeSession == nil {
                startExchangeSession(screen: screen)
            } else {
                currentScreen = screen
                validationErrors = [:]
            }
        }

        /// Audio proximity service for ultrasonic verification.
        private let audioService = AudioProximityService.shared

        /// Create the exchange session via core.
        /// Uses proximity-verified exchange when audio hardware is available,
        /// falls back to manual confirmation otherwise.
        func createSession(vauchi: VauchiPlatform) throws -> MobileExchangeSession {
            let capability = audioService.checkCapability()
            if capability == "full" || capability == "emit_only" {
                let handler = AudioProximityHandler(audioService: audioService)
                return try vauchi.createQrExchange(proximity: handler)
            }
            return try vauchi.createQrExchangeManual()
        }

        /// Create exchange session and replace QR data with real exchange QR.
        private func startExchangeSession(screen: ScreenModel) {
            guard let vauchi else {
                currentScreen = screen
                validationErrors = [:]
                return
            }

            do {
                let session = try createSession(vauchi: vauchi)
                let handler = ExchangeCommandHandler(session: session)
                let qrData = try session.generateQr()
                handler.drainAndDispatch()
                exchangeSession = session
                exchangeCommandHandler = handler

                // Replace the public_id QR data with the real exchange QR
                let updatedComponents = screen.components.map { component -> Component in
                    if case let .qrCode(qrComponent) = component, qrComponent.mode == .display {
                        return .qrCode(QrCodeComponent(
                            id: qrComponent.id, data: qrData, mode: qrComponent.mode, label: qrComponent.label
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
                alertMessage = AlertMessage(
                    title: "Exchange Error",
                    message: "Could not start exchange session. Please try again."
                )
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
                exchangeCommandHandler?.drainAndDispatch()
                try session.theyScannedOurQr()
                exchangeCommandHandler?.drainAndDispatch()
                try session.confirmProximity()
                exchangeCommandHandler?.drainAndDispatch()
                try session.performKeyAgreement()
                exchangeCommandHandler?.drainAndDispatch()

                let peerName = session.peerDisplayName() ?? "Unknown"
                try session.completeCardExchange(theirCardName: peerName)
                exchangeCommandHandler?.drainAndDispatch()

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
                teardownExchange()
            } catch {
                alertMessage = AlertMessage(
                    title: "Exchange Failed",
                    message: "\(error)"
                )
                teardownExchange()
            }
        }
    }
#endif
