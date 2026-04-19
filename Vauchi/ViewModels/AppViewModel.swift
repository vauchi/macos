// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// AppViewModel.swift
// Wraps PlatformAppEngine to drive ScreenRendererView for all screens

import Foundation
import SwiftUI
import UniformTypeIdentifiers

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
        @Published var showImportContactsSheet = false
        @Published var showDeviceLinkSheet = false
        @Published var deviceLinkState: DeviceLinkState = .idle
        @Published var availableScreens: [String] = []
        @Published var selectedScreen: String?
        let appEngine: PlatformAppEngine
        var vauchi: VauchiPlatform?

        /// Active device link initiator (holds session state for confirmation).
        private var currentInitiator: MobileDeviceLinkInitiator?
        private var currentSenderToken: String?

        /// Timer that drives animated-QR frame advancement (~10fps) while the
        /// "Share Your Code" screen is visible. Controlled by the view layer
        /// via `startQrFrameTimer` / `stopQrFrameTimer`.
        private var qrFrameTimer: Timer?

        /// Count of consecutive decode failures. When the count hits
        /// `maxConsecutiveQrDecodeFailures` the timer self-stops to avoid
        /// infinite retry on a persistent decode mismatch (e.g. core
        /// ScreenModel format drift); the frozen QR is itself the user signal.
        private var qrFrameDecodeFailures = 0
        private static let maxConsecutiveQrDecodeFailures = 10 // ~1s at 10 fps

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
                loadAvailableScreens()
                updateSelectedScreen()
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
                loadAvailableScreens()
                loadScreen()
            } catch {
                print("AppViewModel: failed to invalidate: \(error)")
            }
        }

        // MARK: - Animated QR Frame Cycling

        // NOTE: this block is duplicated in vauchi/ios at
        // `Vauchi/CoreUI/AppViewModel.swift`. Keep the two in sync until the
        // shared-module decision lands — see `_private/docs/problems/\
        // 2026-04-19-qr-frame-timer-ios-macos-duplication/`.

        /// Start a 10 fps timer that advances animated-QR frames on the ShowQr
        /// screen. Idempotent: calling while already running is a no-op. The
        /// view calls this when `screenId` becomes `exchange_show_qr`.
        func startQrFrameTimer() {
            guard qrFrameTimer == nil else { return }
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.advanceQrFrame()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            qrFrameTimer = timer
        }

        /// Stop the animated-QR timer if running. The view calls this when
        /// `screenId` leaves `exchange_show_qr` (or on disappear).
        func stopQrFrameTimer() {
            qrFrameTimer?.invalidate()
            qrFrameTimer = nil
        }

        /// Test-only accessor — true while the QR frame timer is active.
        /// Exposed at `internal` visibility so `@testable` imports can assert
        /// idempotent start/stop without reaching into the private Timer.
        var hasActiveQrFrameTimer: Bool {
            qrFrameTimer != nil
        }

        private func advanceQrFrame() {
            do {
                guard let frameJson = try appEngine.advanceQrFrameJson() else {
                    qrFrameDecodeFailures = 0
                    return
                }
                guard let data = frameJson.data(using: .utf8) else {
                    recordQrFrameFailure()
                    return
                }
                let frame = try coreJSONDecoder.decode(ScreenModel.self, from: data)
                currentScreen = frame
                qrFrameDecodeFailures = 0
            } catch {
                #if DEBUG
                    print("AppViewModel: failed to advance QR frame: \(error)")
                #endif
                recordQrFrameFailure()
            }
        }

        /// Record a decode failure and stop the timer once the consecutive-
        /// failure threshold is crossed. Prevents runaway retries when core's
        /// ScreenModel format drifts; the frozen QR is itself the visible signal.
        private func recordQrFrameFailure() {
            qrFrameDecodeFailures += 1
            if qrFrameDecodeFailures >= Self.maxConsecutiveQrDecodeFailures {
                stopQrFrameTimer()
                qrFrameDecodeFailures = 0
            }
        }

        /// Maps core screen_id prefixes to their AppScreen navigation name.
        /// Screen IDs like "exchange_show_qr" map to "Exchange" via prefix match.
        private static let screenIdPrefixToAppScreen: [(prefix: String, appScreen: String)] = [
            ("my_info", "MyInfo"),
            ("archived_contacts", "Contacts"),
            ("contact", "Contacts"),
            ("exchange", "Exchange"),
            ("groups", "Groups"),
            ("group_detail", "Groups"),
            ("device_replacement", "More"),
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
                currentScreen = screen
                validationErrors = [:]
            case let .navigateTo(screen):
                currentScreen = screen
                validationErrors = [:]
            case let .validationError(componentId, message):
                validationErrors[componentId] = message
            case .complete, .wipeComplete:
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
                // Reload screen — core may have navigated internally
                // (e.g. archive_contact intercept calls navigate_back()
                // before returning ShowToast).
                loadScreen()
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
                dispatchExchangeCommands(commands)
                loadScreen()
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

        // MARK: - Exchange Command Dispatch (ADR-031)

        /// BLE exchange service for CoreBluetooth commands.
        private lazy var bleService: BleExchangeService = {
            let service = BleExchangeService()
            service.activate { [weak self] event in
                DispatchQueue.main.async {
                    self?.sendHardwareEvent(event)
                }
            }
            return service
        }()

        /// TCP client for USB cable exchange (ADR-031).
        private lazy var directSendService: DirectSendService = {
            let service = DirectSendService()
            service.setEventCallback { [weak self] event in
                self?.sendHardwareEvent(event)
            }
            return service
        }()

        /// Dispatch exchange commands to platform hardware services.
        private func dispatchExchangeCommands(_ commands: [ExchangeCommandDTO]) {
            for command in commands {
                switch command {
                // QR — handled by view layer (screen model contains QR data)
                case .qrDisplay, .qrRequestScan:
                    break
                // BLE — delegate to CoreBluetooth service
                case let .bleStartScanning(serviceUuid):
                    bleService.startScanning(serviceUuid: serviceUuid)
                case .bleStopScanning:
                    bleService.stopScanning()
                case let .bleStartAdvertising(serviceUuid, payload):
                    bleService.startAdvertising(serviceUuid: serviceUuid, payload: Data(payload))
                case let .bleConnect(deviceId):
                    bleService.connect(deviceId: deviceId)
                case let .bleWriteCharacteristic(uuid, data):
                    bleService.writeCharacteristic(uuid: uuid, data: Data(data))
                case let .bleReadCharacteristic(uuid):
                    bleService.readCharacteristic(uuid: uuid)
                case .bleDisconnect:
                    bleService.disconnect()
                // Audio — delegate to helper (runs on background queue)
                case let .audioEmitChallenge(data):
                    dispatchAudioEmit(data: data)
                case let .audioListenForResponse(timeoutMs):
                    dispatchAudioListen(timeoutMs: timeoutMs)
                case .audioStop:
                    AudioProximityService.shared.stop()
                // DirectSend — TCP cable exchange
                case let .directSend(payload, isInitiator):
                    directSendService.exchange(
                        address: "127.0.0.1:\(DirectSendService.defaultPort)",
                        payload: payload,
                        isInitiator: isInitiator
                    )
                // NFC — not available on macOS
                case .nfcActivate, .nfcDeactivate:
                    sendHardwareUnavailable(transport: "NFC")
                // Image picking (ADR-042 avatar editor)
                case .imagePickFromFile:
                    presentFileImagePicker()
                case .imagePickFromLibrary:
                    sendHardwareUnavailable(transport: "PhotoLibrary")
                case .imageCaptureFromCamera:
                    sendHardwareUnavailable(transport: "Camera")
                case .unknown:
                    // ADR-031: report unsupported commands so core can handle fallback
                    sendHardwareUnavailable(transport: "unsupported-command")
                }
            }
        }

        /// Send a hardware event back to core and apply the result.
        private func dispatchAudioEmit(data: [UInt8]) {
            let samples = data.map { Float($0) / 255.0 }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let error = AudioProximityService.shared.emitSignal(samples: samples, sampleRate: 48000)
                if !error.isEmpty {
                    DispatchQueue.main.async { self?.sendHardwareUnavailable(transport: "Audio") }
                }
            }
        }

        private func dispatchAudioListen(timeoutMs: UInt64) {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let samples = AudioProximityService.shared.receiveSignal(timeoutMs: timeoutMs, sampleRate: 48000)
                DispatchQueue.main.async {
                    if samples.isEmpty {
                        self?.sendHardwareUnavailable(transport: "Audio")
                    } else {
                        let bytes = samples.map { UInt8(clamping: Int($0 * 255.0)) }
                        self?.sendHardwareEvent(.audioResponseReceived(data: Data(bytes)))
                    }
                }
            }
        }

        // MARK: - Image Picker (ADR-042)

        /// Present NSOpenPanel for image file selection.
        private func presentFileImagePicker() {
            let panel = NSOpenPanel()
            panel.title = "Select Image"
            panel.allowedContentTypes = [.image]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false

            panel.begin { [weak self] response in
                guard let self else { return }
                DispatchQueue.main.async {
                    if response == .OK, let url = panel.url,
                       let data = try? Data(contentsOf: url)
                    {
                        self.sendHardwareEvent(.imageReceived(data: data))
                    } else {
                        self.sendHardwareEvent(.imagePickCancelled)
                    }
                }
            }
        }

        /// ADR-031: Route QR scan data through the hardware event path.
        func handleQrScanned(data: String) {
            sendHardwareEvent(.qrScanned(data: data))
        }

        /// Send a hardware event back to core and apply the result.
        private func sendHardwareEvent(_ event: MobileExchangeHardwareEvent) {
            do {
                if let resultJson = try appEngine.handleHardwareEvent(event: event) {
                    guard let data = resultJson.data(using: .utf8) else { return }
                    let result = try coreJSONDecoder.decode(ActionResult.self, from: data)
                    applyResult(result)
                }
            } catch {
                print("AppViewModel: hardware event failed: \(error)")
            }
        }

        /// Report that a hardware transport is unavailable.
        private func sendHardwareUnavailable(transport: String) {
            sendHardwareEvent(.hardwareUnavailable(transport: transport))
        }
    }
#endif
