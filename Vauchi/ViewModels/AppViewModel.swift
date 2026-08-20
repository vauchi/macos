// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Generic presentation host plus native hardware-effect adapters.

import CoreUIModels
import Foundation
import SwiftUI
import UniformTypeIdentifiers

#if canImport(VauchiPlatform)
    import VauchiHardware
    import VauchiPlatform

    @MainActor
    class AppViewModel: ObservableObject {
        @Published var presentationState = PresentationState()
        @Published var alertMessage: AlertMessage?
        @Published var toastMessage: String?
        let appEngine: PlatformAppEngine

        /// Core-scheduled wakeup timer (ADR-044 Am2a Option C). When a
        /// `CommandDTO.scheduleWakeup` fires, the frontend arms a single
        /// desktop interval; on fire it calls `appEngine.onWakeup()` and
        /// dispatches the returned commands/notifications.
        private var wakeupTimer: Timer?

        struct AlertMessage: Identifiable {
            let id = UUID()
            let title: String
            let message: String
        }

        init(appEngine: PlatformAppEngine) {
            self.appEngine = appEngine
            loadInitialPresentation()
        }

        func loadInitialPresentation() {
            do {
                try applyPresentationEnvelope(
                    appEngine.initialCommandsJson()
                )
            } catch {
                alertMessage = AlertMessage(
                    title: "Presentation error",
                    message: String(describing: error)
                )
            }
        }

        func dispatchPresentation(_ event: PresentationEvent) {
            do {
                let data = try JSONEncoder().encode(event)
                guard let eventJSON = String(data: data, encoding: .utf8) else {
                    throw PresentationDispatchError.invalidUTF8
                }
                try applyPresentationEnvelope(
                    appEngine.dispatchJson(eventJson: eventJSON)
                )
            } catch {
                alertMessage = AlertMessage(
                    title: "Presentation error",
                    message: String(describing: error)
                )
            }
        }

        func activateAndDispatch(
            surfaceID: String,
            event: PresentationEvent
        ) {
            dispatchPresentation(.surfaceActivated(surfaceID: surfaceID))
            dispatchPresentation(event)
        }

        func dismissPresentationOverlay() {
            guard let overlay = presentationState.activeOverlay else { return }
            var next = presentationState
            next.dismissOverlay()
            presentationState = next
            dispatchPresentation(
                .overlayDismissed(
                    surfaceID: overlay.surfaceID,
                    kind: overlay.overlay.kind
                )
            )
        }

        private func applyPresentationEnvelope(_ json: String) throws {
            let data = Data(json.utf8)
            let envelope = try JSONDecoder().decode(
                PresentationCommandEnvelope.self,
                from: data
            )
            var next = presentationState
            let effects = try next.apply(envelope.commands)
            presentationState = next
            for effect in effects {
                handlePresentationEffect(effect)
            }
            try dispatchNativeEffects(from: data)
        }

        private func handlePresentationEffect(_ command: PresentationCommand) {
            switch command {
            case let .presentAlert(alert):
                alertMessage = AlertMessage(
                    title: alert.title,
                    message: alert.message
                )
            case let .showToast(toast):
                showToast(toast.message)
            case let .openExternalURL(value):
                if let url = URL(string: value) {
                    NSWorkspace.shared.open(url)
                }
            case let .exportFile(file):
                presentExport(file)
            case .performNativeBack:
                break
            case .resetApplication:
                loadInitialPresentation()
            case .postNotification, .platformEffect:
                break
            default:
                break
            }
        }

        private func presentExport(_ file: PresentationExportFile) {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = file.suggestedName
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                do {
                    try Data(file.data).write(to: url, options: .atomic)
                } catch {
                    Task { @MainActor [weak self] in
                        self?.alertMessage = AlertMessage(
                            title: "Export failed",
                            message: String(describing: error)
                        )
                    }
                }
            }
        }

        private struct NativeEffectEnvelope: Decodable {
            let commands: [CommandDTO]
        }

        private func dispatchNativeEffects(from data: Data) throws {
            guard var root = try JSONSerialization.jsonObject(with: data)
                as? [String: Any],
                let commands = root["commands"] as? [Any]
            else { return }
            let presentationVariants: Set = [
                "ReplaceSurface",
                "SetContextBar",
                "PresentOverlay",
                "SetPresentationProfile",
                "PresentAlert",
                "ShowToast",
                "OpenExternalUrl",
                "ExportFile",
                "PerformNativeBack",
                "ResetApplication",
                "PostNotification",
            ]
            root["commands"] = commands.filter { command in
                if let variant = command as? String {
                    return !presentationVariants.contains(variant)
                }
                guard let object = command as? [String: Any],
                      let variant = object.keys.first
                else { return false }
                return !presentationVariants.contains(variant)
            }
            guard let hardwareCommands = root["commands"] as? [Any],
                  !hardwareCommands.isEmpty
            else { return }
            let filtered = try JSONSerialization.data(withJSONObject: root)
            let envelope = try coreJSONDecoder.decode(
                NativeEffectEnvelope.self,
                from: filtered
            )
            dispatchExchangeCommands(envelope.commands)
        }

        /// Invalidate cached engines after domain mutations.
        func invalidateAll() {
            dispatchPresentation(.presentationInvalidated)
        }

        // MARK: - Core-Scheduled Wakeup (ADR-044 Am2a Option C)

        /// Arm a desktop timer from a `CommandDTO.scheduleWakeup`. Idempotent:
        /// re-arming cancels any pending previous wakeup. The timer fires
        /// after `earliestSecs` (capped at `deadlineSecs`) and dispatches
        /// `onWakeup()`; `minIntervalSecs` is honoured by simply not re-arming
        /// more frequently than requested.
        func armWakeupTimer(
            earliestSecs: UInt32,
            deadlineSecs: UInt32,
            minIntervalSecs: UInt32,
            earliestMillis: UInt32? = nil
        ) {
            wakeupTimer?.invalidate()
            // Whole seconds cannot express the frame dwell of a live QR
            // exchange, whose display advances from this timer. Android read
            // only the seconds field and ran at 1013 ms against a ~300 ms
            // design (2026-08-18-hover-transfer-stalls-on-the-last-chunk).
            let earliest = earliestMillis.map { TimeInterval($0) / 1000.0 }
                ?? TimeInterval(earliestSecs)
            let fireDelay = min(earliest, TimeInterval(deadlineSecs))
            let timer = Timer(timeInterval: fireDelay, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.onWakeup()
                    // Honour min interval: if another schedule hasn't arrived,
                    // leave the timer nil so the next command re-arms cleanly.
                    self?.wakeupTimer = nil
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            wakeupTimer = timer

            // Remember the minimum interval so future `armWakeupTimer` calls
            // can be throttled if needed. For now we rely on core only emitting
            // a new schedule when it wants one.
            _ = minIntervalSecs
        }

        /// Cancel any pending core-scheduled wakeup.
        func cancelWakeupTimer() {
            wakeupTimer?.invalidate()
            wakeupTimer = nil
        }

        /// Test-only accessor — true while a wakeup timer is armed.
        var hasActiveWakeupTimer: Bool {
            wakeupTimer != nil
        }

        /// The platform wakeup fired. Ask core what to do and dispatch the
        /// returned commands + notifications. JSON envelope:
        /// `{"notifications": [...], "commands": [...]}`.
        func onWakeup() {
            do {
                let json = try appEngine.onWakeup()
                guard let data = json.data(using: .utf8) else {
                    print("AppViewModel: failed to convert onWakeup JSON to Data")
                    return
                }
                let envelope = try coreJSONDecoder.decode(WakeupEnvelope.self, from: data)
                if !envelope.commands.isEmpty {
                    dispatchExchangeCommands(envelope.commands)
                }
                for notification in envelope.notifications {
                    NotificationService.shared.showNotification(notification.toMobilePendingNotification())
                }
                loadInitialPresentation()
            } catch {
                print("AppViewModel: onWakeup failed: \(error)")
            }
        }

        // MARK: - Toast

        /// Show a transient, informational platform toast.
        func showToast(
            _ message: String,
            durationMs: UInt32 = 3000
        ) {
            withAnimation {
                toastMessage = message
            }
            let duration = max(Double(durationMs) / 1000.0, 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                guard let self, self.toastMessage == message else { return }
                withAnimation {
                    self.toastMessage = nil
                }
            }
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

        /// One-shot location capture for the exchange "where we met"
        /// annotation (ADR-051).
        private lazy var locationService = LocationService()

        /// Start a one-shot location fix and report the resulting
        /// `MobileEvent` back to core.
        private func dispatchLocationRequest(timeoutMs: UInt32) {
            locationService.requestOneShot(timeoutMs: timeoutMs) { [weak self] event in
                DispatchQueue.main.async {
                    self?.sendHardwareEvent(event)
                }
            }
        }

        /// Dispatch exchange commands to platform hardware services.
        private func dispatchExchangeCommands(_ commands: [CommandDTO]) {
            for command in commands {
                switch command {
                // QR — handled by view layer (screen model contains QR data)
                case .qrDisplay, .qrRequestScan:
                    break
                // BLE — delegate to CoreBluetooth service via helper
                // (`dispatchBleCommand` does the typed re-switch).
                case .bleStartScanning, .bleStopScanning, .bleStartAdvertising,
                     .bleConnect, .bleWriteCharacteristic, .bleReadCharacteristic,
                     .bleDisconnect:
                    dispatchBleCommand(command)
                // Audio — delegate to helper (runs on background queue)
                case let .audioEmitChallenge(samples, sampleRate):
                    dispatchAudioEmit(samples: samples, sampleRate: sampleRate)
                case let .audioListenForResponse(timeoutMs, sampleRate):
                    dispatchAudioListen(timeoutMs: timeoutMs, sampleRate: sampleRate)
                case .audioStop:
                    AudioProximityService.shared.stop()
                // DirectSend / DirectSendCard — TCP cable exchange.
                case .directSend, .directSendCard:
                    dispatchDirectSendCommand(command)
                // Location — one-shot CLLocationManager fix for the exchange
                // "where we met" annotation (ADR-051 capture-at-exchange).
                case let .locationRequest(timeoutMs):
                    dispatchLocationRequest(timeoutMs: timeoutMs)
                // Image picking (ADR-042 avatar editor)
                case .imagePickFromFile:
                    presentFileImagePicker()
                // File picker (ADR-031, Phase 3 of
                // 2026-05-03-core-file-picker-command). Delegates to
                // NSOpenPanel; replaces the prior `filePickCancelledByUser`
                // stub and the bespoke .fileImporter inside
                // ImportContactsSheet / ImportBackupSheet (those sheets
                // are retired in a follow-up commit).
                case .filePickFromUser:
                    dispatchFilePickerCommand(command)
                // Core-scheduled wakeup (ADR-044 Am2a Option C). Translate
                // the relative seconds into a desktop one-shot timer.
                case .scheduleWakeup:
                    dispatchWakeupCommand(command)
                // Platform-unavailable on macOS (NFC, photo library,
                // camera, Phase 2b lifecycle, unsupported). Reported so
                // core can pick its fallback path per ADR-031.
                case .nfcActivate, .nfcDeactivate, .nfcSendApdu,
                     .imagePickFromLibrary,
                     .imageCaptureFromCamera, .setScreenBrightness,
                     .setIdleTimerDisabled, .setOrientationLock,
                     .switchCamera, .showShareSheet,
                     .accelerometerStart, .accelerometerStop,
                     .celebrate,
                     .unknown:
                    dispatchUnavailableCommand(command)
                }
            }
        }

        /// Re-dispatch BLE-shaped commands to `bleService`.
        private func dispatchBleCommand(_ command: CommandDTO) {
            switch command {
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
            default:
                break
            }
        }

        /// Map platform-unavailable commands to the transport label core
        /// uses to pick its fallback. Display sleep is OS-managed; the
        /// front/back camera distinction doesn't apply on desktop;
        /// ShareSheet would map to NSSharingServicePicker but is unwired
        /// pending a UI host.
        private func macOSUnavailableLabel(_ command: CommandDTO) -> String {
            switch command {
            case .nfcActivate, .nfcDeactivate, .nfcSendApdu: return "NFC"
            case .imagePickFromLibrary: return "PhotoLibrary"
            case .imageCaptureFromCamera, .switchCamera: return "Camera"
            case .setScreenBrightness: return "ScreenBrightness"
            case .setIdleTimerDisabled: return "IdleTimer"
            case .setOrientationLock: return "OrientationLock"
            case .showShareSheet: return "ShareSheet"
            case .accelerometerStart, .accelerometerStop: return "Accelerometer"
            case .locationRequest: return "Location"
            default: return "unsupported-command"
            }
        }

        /// Report platform-unavailable commands back to core so it can pick
        /// a fallback path (ADR-031). Display sleep, camera orientation, and
        /// ShareSheet are all OS-managed or unwired on desktop.
        private func dispatchUnavailableCommand(_ command: CommandDTO) {
            sendHardwareUnavailable(transport: macOSUnavailableLabel(command))
        }

        /// DirectSend / DirectSendCard — TCP cable exchange. The card variant
        /// is the USB card-exchange second leg (a fresh TCP connection swaps
        /// the encrypted cards; core decrypts the peer's and completes).
        private func dispatchDirectSendCommand(_ command: CommandDTO) {
            switch command {
            case let .directSend(payload, isInitiator):
                directSendService.exchange(
                    address: "127.0.0.1:\(DirectSendService.defaultPort)",
                    payload: payload,
                    isInitiator: isInitiator
                )
            case let .directSendCard(ciphertext, isInitiator):
                directSendService.exchange(
                    address: "127.0.0.1:\(DirectSendService.defaultPort)",
                    payload: ciphertext,
                    isInitiator: isInitiator,
                    cardLeg: true
                )
            default:
                break
            }
        }

        /// File picker (ADR-031, Phase 3 of 2026-05-03-core-file-picker-command).
        /// Delegates to NSOpenPanel; replaces the prior `filePickCancelledByUser`
        /// stub and the bespoke .fileImporter inside ImportContactsSheet /
        /// ImportBackupSheet (those sheets are retired in a follow-up commit).
        private func dispatchFilePickerCommand(_ command: CommandDTO) {
            guard case let .filePickFromUser(acceptedMimeTypes, purpose) = command else { return }
            presentFilePickFromUser(
                acceptedMimeTypes: acceptedMimeTypes,
                purpose: purpose
            )
        }

        /// Core-scheduled wakeup (ADR-044 Am2a Option C). Translate the
        /// relative seconds into a desktop one-shot timer.
        private func dispatchWakeupCommand(_ command: CommandDTO) {
            guard case let .scheduleWakeup(
                earliestSecs,
                deadlineSecs,
                minIntervalSecs,
                earliestMillis
            ) = command else { return }
            armWakeupTimer(
                earliestSecs: earliestSecs,
                deadlineSecs: deadlineSecs,
                minIntervalSecs: minIntervalSecs,
                earliestMillis: earliestMillis
            )
        }

        /// Send a hardware event back to core and apply the result.
        private func dispatchAudioEmit(samples: [Float], sampleRate: UInt32) {
            // Core sends real f32 PCM samples + the rate it synthesised them at
            // (`AudioEmitChallenge { samples, sample_rate }`); play them as-is.
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let error = AudioProximityService.shared.emitSignal(samples: samples, sampleRate: sampleRate)
                if !error.isEmpty {
                    DispatchQueue.main.async { self?.sendHardwareUnavailable(transport: "Audio") }
                }
            }
        }

        private func dispatchAudioListen(timeoutMs: UInt64, sampleRate: UInt32) {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let samples = AudioProximityService.shared.receiveSignal(timeoutMs: timeoutMs, sampleRate: sampleRate)
                DispatchQueue.main.async {
                    if samples.isEmpty {
                        self?.sendHardwareUnavailable(transport: "Audio")
                    } else {
                        self?.sendHardwareEvent(.audioSamplesRecorded(samples: samples, sampleRate: sampleRate))
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

        /// Present NSOpenPanel for the ADR-031 file-picker protocol. The
        /// returned bytes are forwarded as
        /// `MobileEvent::FilePickedFromUser`; cancel /
        /// read-failure paths surface as
        /// `MobileEvent::FilePickCancelledByUser` so core
        /// never sits waiting for a hardware event.
        private func presentFilePickFromUser(
            acceptedMimeTypes: [String],
            purpose: FilePickPurpose
        ) {
            let panel = NSOpenPanel()
            panel.title = filePickPanelTitle(for: purpose)
            panel.allowedContentTypes = filePickContentTypes(from: acceptedMimeTypes)
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false

            panel.begin { [weak self] response in
                guard let self else { return }
                DispatchQueue.main.async {
                    if response == .OK, let url = panel.url {
                        // Hold security-scoped access while we read the
                        // file — sandboxed builds raise EACCES otherwise.
                        let didStart = url.startAccessingSecurityScopedResource()
                        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
                        if let data = try? Data(contentsOf: url) {
                            self.sendHardwareEvent(.filePickedFromUser(
                                bytes: data,
                                filename: url.lastPathComponent
                            ))
                            return
                        }
                    }
                    self.sendHardwareEvent(.filePickCancelledByUser)
                }
            }
        }

        /// Map a `FilePickPurpose` to a localized panel title. Falls back
        /// to a generic "Select File" so any future purpose still opens
        /// the picker (advisory per ADR-031).
        private func filePickPanelTitle(for purpose: FilePickPurpose) -> String {
            switch purpose {
            case .importContacts: return "Import Contacts"
            case .importBackup: return "Import Backup"
            default: return "Select File"
            }
        }

        /// Translate core's advisory MIME types into UTTypes for
        /// NSOpenPanel. Falls back to `.data` (any file) so unfamiliar
        /// MIME strings still let the panel open.
        private func filePickContentTypes(from mimeTypes: [String]) -> [UTType] {
            let types = mimeTypes.compactMap { UTType(mimeType: $0) }
            return types.isEmpty ? [.data] : types
        }

        /// Send a hardware event back to Core, execute its native effects,
        /// then refresh presentation state through the reducer boundary.
        private func sendHardwareEvent(_ event: MobileEvent) {
            do {
                let resultJson = try appEngine.handleHardwareEvent(event: event)
                try applyPresentationEnvelope(resultJson)
            } catch {
                print("AppViewModel: hardware event failed: \(error)")
            }
        }

        /// Report that a hardware transport is unavailable.
        private func sendHardwareUnavailable(transport: String) {
            sendHardwareEvent(.hardwareUnavailable(transport: transport))
        }
    }

    /// Envelope returned by `PlatformAppEngine.onWakeup` (ADR-044 Am2a):
    /// `{"notifications": [...], "commands": [...]}`. Decodes into a
    /// JSON-friendly DTO first, then maps to the UniFFI
    /// `MobilePendingNotification` type used by `NotificationService`.
    struct WakeupEnvelope: Decodable {
        let notifications: [WakeupNotification]
        let commands: [CommandDTO]
    }

    /// JSON DTO for a pending OS notification returned by `onWakeup`.
    /// Mirrors `MobilePendingNotification` without requiring the UniFFI
    /// type to conform to `Decodable`.
    struct WakeupNotification: Decodable {
        let eventKey: String
        let category: String
        let title: String
        let body: String
        let contactId: String
        let deepLinkUri: String?
        let osCategoryId: String?
        let osChannelId: String?
        let priority: String?
        let osCategoryOptions: [String]?

        /// Map the JSON DTO to the UniFFI `MobilePendingNotification` type
        /// used by `NotificationService.showNotification`.
        func toMobilePendingNotification() -> MobilePendingNotification {
            MobilePendingNotification(
                eventKey: eventKey,
                category: MobileNotificationCategory.fromWire(category),
                title: title,
                body: body,
                contactId: contactId,
                deepLinkUri: deepLinkUri,
                osCategoryId: osCategoryId ?? "",
                osChannelId: osChannelId ?? "",
                priority: MobileNotificationPriority.fromWire(priority ?? "default"),
                osCategoryOptions: osCategoryOptions ?? []
            )
        }
    }

    /// Wire-string helpers for UniFFI notification enums that do not
    /// conform to `Decodable`.
    extension MobileNotificationCategory {
        static func fromWire(_ value: String) -> MobileNotificationCategory {
            switch value {
            case "emergency_alert", "EmergencyAlert": return .emergencyAlert
            case "duress_alert", "DuressAlert": return .duressAlert
            case "contact_added", "ContactAdded": return .contactAdded
            case "card_update", "CardUpdate": return .cardUpdate
            default: return .contactAdded
            }
        }
    }

    extension MobileNotificationPriority {
        static func fromWire(_ value: String) -> MobileNotificationPriority {
            switch value {
            case "urgent", "Urgent": return .urgent
            case "high", "High": return .high
            case "default", "Default": return .default
            default: return .default
            }
        }
    }

    private enum PresentationDispatchError: Error {
        case invalidUTF8
    }
#endif
