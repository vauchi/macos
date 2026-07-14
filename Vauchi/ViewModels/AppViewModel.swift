// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Wraps PlatformAppEngine to drive ScreenRendererView for all screens

import CoreUIModels
import Foundation
import SwiftUI
import UniformTypeIdentifiers

#if canImport(VauchiPlatform)
    import VauchiHardware
    import VauchiPlatform

    @MainActor
    class AppViewModel: ObservableObject {
        @Published var currentScreen: ScreenModel?
        @Published var validationErrors: [String: String] = [:]
        @Published var alertMessage: AlertMessage?
        @Published var toastMessage: String?
        @Published var toastUndoActionId: String?
        @Published var toastUndoLabel: String?
        @Published var showDeviceLinkSheet = false
        /// Core-owned top-level sidebar entries. Each element carries
        /// the screen_id (snake_case), a locale-resolved label, the
        /// SF Symbol icon name, and a badge count. 14 entries
        /// post-identity, 1 (Onboarding) before.
        @Published var sidebarItems: [MobileTabInfo] = []
        @Published var selectedScreen: String?
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
            loadSidebarItems()
            loadScreen()
        }

        /// Loads the sidebar entries from core. Labels + the top-level
        /// screen set are core-owned (§6 of the pure-renderer audit);
        /// macOS only contributes the native SF Symbol icon (see
        /// `sidebarIcon(forScreenId:)` in VauchiApp.swift).
        func loadSidebarItems() {
            do {
                let locale = LocalizationService.shared.currentLocale
                sidebarItems = try appEngine.navItems(layout: .desktop, locale: locale)
            } catch {
                print("AppViewModel: failed to load sidebar items: \(error)")
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

                // Phase 2b: handleActionJson now returns
                // `{"action_result": <ActionResult>, "commands": [<CommandDTO>]}`.
                let envelope = try coreJSONDecoder.decode(
                    ActionResultEnvelope.self,
                    from: resultData
                )
                applyResult(envelope.actionResult)
                if !envelope.commands.isEmpty {
                    dispatchExchangeCommands(envelope.commands)
                }
            } catch {
                print("AppViewModel: failed to handle action: \(error)")
            }
        }

        // `navigateTo(screenJson:)` (the `appEngine.navigateToJson` wrapper)
        // was retired with core's `navigate_to_json` UniFFI surface
        // (ADR-043 Am4 "dispatch inversion", core 0.51.35). Every macOS
        // top-level / sidebar / menu destination now reaches core via the
        // typed `navigateToTab(actionId:)` path; parameterized destinations
        // (contact detail, edit, entry) are core-driven — `AppEngine.
        // route_result` re-emits `OpenContact`/`EditContact`/`OpenEntryDetail`
        // as `NavigateTo`, so the frontend only renders the engine's current
        // screen and never constructs a navigation target.

        /// Forward a sidebar / menu destination tap as
        /// `UserAction::NavigateToTab { action_id }`.
        ///
        /// `actionId` is the opaque token core minted on
        /// `MobileTabInfo.actionId` (== the snake_case `screen_id`, e.g.
        /// "settings", "exchange"); core resolves it to the canonical screen
        /// and returns `NavigateTo`. The frontend never parses or constructs
        /// the domain variant — that is the zero-domain-vocab contract
        /// (ADR-043 Am4). Dispatched through the typed `handleAction(_:)`
        /// path (encode → `handleActionJson` → apply result + lifecycle
        /// commands), then refreshes the sidebar + selection.
        ///
        /// Requires the `UserAction.navigateToTab` case from
        /// vauchi-platform-swift (added in vauchi-platform-swift!59).
        func navigateToTab(actionId: String) {
            handleAction(.navigateToTab(actionId: actionId))
            loadSidebarItems()
            updateSelectedScreen()
        }

        /// Navigate back in the history stack.
        ///
        /// Forwards `UserAction.navigateBack` unconditionally; core decides
        /// whether to pop (`NavigateTo`/`UpdateScreen`) or tell the frontend
        /// to perform native back (`ActionResult.performNativeBack`). The
        /// frontend never gates on `can_go_back` (ADR-044 Amendment 2a).
        func navigateBack() {
            handleAction(.navigateBack)
        }

        /// Invalidate cached engines after domain mutations.
        func invalidateAll() {
            do {
                try appEngine.invalidateAll()
                loadSidebarItems()
                loadScreen()
            } catch {
                print("AppViewModel: failed to invalidate: \(error)")
            }
        }

        // MARK: - Core-Scheduled Wakeup (ADR-044 Am2a Option C)

        /// Arm a desktop timer from a `CommandDTO.scheduleWakeup`. Idempotent:
        /// re-arming cancels any pending previous wakeup. The timer fires
        /// after `earliestSecs` (capped at `deadlineSecs`) and dispatches
        /// `onWakeup()`; `minIntervalSecs` is honoured by simply not re-arming
        /// more frequently than requested.
        func armWakeupTimer(earliestSecs: UInt32, deadlineSecs: UInt32, minIntervalSecs: UInt32) {
            wakeupTimer?.invalidate()
            let fireDelay = min(TimeInterval(earliestSecs), TimeInterval(deadlineSecs))
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
            } catch {
                print("AppViewModel: onWakeup failed: \(error)")
            }
        }

        /// Syncs `selectedScreen` from the rendered screen's core-provided tab.
        ///
        /// `ScreenModel.navTabId` is the opaque snake_case `screen_id` of the
        /// sidebar entry the active screen belongs to (e.g. "contacts" for
        /// `contact_detail`), matching the `id` / `actionId` carried by
        /// `sidebarItems`. `nil` means the screen has no tab chrome
        /// (transient/pre-auth). Replaces both frontend tab-id inference and
        /// the `currentTabId(layout:)` UniFFI call (ADR-044 Am2a).
        private func updateSelectedScreen() {
            selectedScreen = currentScreen?.navTabId
        }

        // MARK: - Private

        // TODO(HUMBLE): W — exhaustively names ignored ActionResult domain
        // variants (see _private problem record
        // 2026-07-06-desktop-tui-web-domain-shell-violations).
        private func applyResult(_ result: ActionResult) {
            switch result {
            case let .updateScreen(screen):
                currentScreen = screen
                validationErrors = [:]
            case let .navigateTo(screen):
                currentScreen = screen
                validationErrors = [:]
            case .performNativeBack:
                // Back gesture reached a back-stopping root. macOS native
                // default: terminate the app (the shell keeps running in the
                // menu bar; terminating the active app process is the desktop
                // equivalent of Android/iOS native back).
                NSApp.terminate(nil)
            case let .validationError(componentId, message):
                validationErrors[componentId] = message
            case .complete, .wipeComplete:
                loadScreen()
            case .onboardingComplete:
                // Core has finished onboarding and navigated to the chosen
                // destination. Refresh the sidebar so it switches from the
                // single Onboarding entry to the full post-identity set, and
                // reload the current screen
                // (`2026-07-06-mobile-domain-shell-violations` I7).
                loadSidebarItems()
                loadScreen()
            case .completeWith, .openContact, .editContact, .openEntryDetail:
                // Resolved to NavigateTo by AppEngine.route_result in core —
                // frontends never observe these raw (ADR-043 Am4). CompleteWith
                // is kept for backward compatibility; OpenContact /
                // EditContact / OpenEntryDetail re-emit the contact / edit /
                // entry screens. The frontend renders the engine's current
                // screen and never constructs a navigation target.
                break
            case let .openUrl(url):
                if let nsUrl = URL(string: url) { NSWorkspace.shared.open(nsUrl) }
            case let .showAlert(title, message):
                alertMessage = AlertMessage(title: title, message: message)
            case let .showToast(message, undoActionId, undoLabel):
                // Reload screen — core may have navigated internally
                // (e.g. archive_contact intercept calls navigate_back()
                // before returning ShowToast).
                loadScreen()
                showToast(message, undoActionId: undoActionId, undoLabel: undoLabel)
            case .requestCamera:
                // Load the scan screen — it has camera QR scanning with paste fallback
                loadScreen()
            case .startDeviceLink:
                // Sheet content (`CoreSheetView` for `"DeviceLinking"`)
                // navigates the engine on appear; `after_screen_transition`
                // creates the `MobileDeviceLinkSession` automatically.
                showDeviceLinkSheet = true
            case let .commands(commands):
                dispatchExchangeCommands(commands)
                loadScreen()
            case .showFormDialog, .previewAs:
                // Form dialog + preview-as are iOS/mobile flows.
                // Desktop (macOS) has no UI for them yet; ignore to stay
                // forward-compatible with cross-platform ActionResult.
                break
            case .biometricUnlockOutcome:
                // ADR-031 biometric-unlock duress flow is a mobile
                // concern; macOS has no biometric-unlock UI. No-op for
                // switch exhaustiveness.
                break
            case .unknown:
                // Unknown action result from newer core — ignore
                break
            }
        }

        // MARK: - Toast

        /// Show a toast overlay that auto-dismisses after the given duration.
        func showToast(
            _ message: String,
            undoActionId: String? = nil,
            undoLabel: String? = nil,
            durationMs: UInt32 = 3000
        ) {
            withAnimation {
                toastMessage = message
                toastUndoActionId = undoActionId
                toastUndoLabel = undoLabel
            }
            let duration = max(Double(durationMs) / 1000.0, 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                guard let self, self.toastMessage == message else { return }
                withAnimation {
                    self.toastMessage = nil
                    self.toastUndoActionId = nil
                    self.toastUndoLabel = nil
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
            guard case let .scheduleWakeup(earliestSecs, deadlineSecs, minIntervalSecs) = command else { return }
            armWakeupTimer(
                earliestSecs: earliestSecs,
                deadlineSecs: deadlineSecs,
                minIntervalSecs: minIntervalSecs
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

        /// ADR-031: Route QR scan data through the hardware event path.
        func handleQrScanned(data: String) {
            sendHardwareEvent(.qrScanned(data: data))
        }

        /// Send a hardware event back to core and apply the result.
        private func sendHardwareEvent(_ event: MobileEvent) {
            do {
                let resultJson = try appEngine.handleHardwareEvent(event: event)
                guard let data = resultJson.data(using: .utf8) else { return }
                // core 0.51.44+: handleHardwareEvent returns
                // `{"action_result": <ActionResult>|null, "commands": [<CommandDTO>]}`
                // so hardware events deliver the Commands they produce (previously
                // stranded). action_result is null when the event only advanced an
                // engine-held machine.
                let envelope = try coreJSONDecoder.decode(HardwareEventEnvelope.self, from: data)
                if let result = envelope.actionResult {
                    applyResult(result)
                }
                if !envelope.commands.isEmpty {
                    dispatchExchangeCommands(envelope.commands)
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

    /// Envelope returned by `PlatformAppEngine.handleHardwareEvent` (core 0.51.44+):
    /// `{"action_result": <ActionResult>|null, "commands": [<CommandDTO>]}`.
    /// `actionResult` is nil when the event only advanced an engine-held machine;
    /// `commands` carries every `Command` the event produced for execution.
    struct HardwareEventEnvelope: Decodable {
        let actionResult: ActionResult?
        let commands: [CommandDTO]

        enum CodingKeys: String, CodingKey {
            case actionResult = "action_result"
            case commands
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
#endif
