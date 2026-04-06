// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import VauchiPlatform

/// Dispatches ADR-031 exchange commands from core to platform hardware.
///
/// After each state-advancing call on `MobileExchangeSession`, drain pending
/// commands and pass them here. Results are reported back via
/// `applyHardwareEvent()` on the session.
final class ExchangeCommandHandler {
    private weak var session: MobileExchangeSession?
    private lazy var bleService: BleExchangeService = {
        let service = BleExchangeService()
        service.activate { [weak self] event in
            guard let self, let session else { return }
            try? session.applyHardwareEvent(event: event)
            drainAndDispatch()
        }
        return service
    }()

    init(session: MobileExchangeSession) {
        self.session = session
    }

    /// Process all pending commands from the session.
    ///
    /// Call after `generateQr()`, `processQr()`, `performKeyAgreement()`, etc.
    func drainAndDispatch() {
        guard let session else { return }
        let commands = session.drainPendingCommands()
        for command in commands {
            dispatch(command)
        }
    }

    /// Dispatch a single exchange command to the appropriate platform service.
    private func dispatch(_ command: MobileExchangeCommand) {
        switch command {
        // ── QR ──────────────────────────────────────────────────────
        case .qrDisplay:
            // QR display is handled by the view layer (FaceToFaceExchangeView)
            // — no platform action needed.
            break

        case .qrRequestScan:
            // Camera scanning is handled by HeadlessQrScanner in the view layer.
            break

        // ── Audio (ultrasonic proximity) ────────────────────────────
        case let .audioEmitChallenge(data):
            emitAudioChallenge(data: data)

        case let .audioListenForResponse(timeoutMs):
            listenForAudioResponse(timeoutMs: timeoutMs)

        case .audioStop:
            // Audio operations are one-shot — no persistent state to stop.
            break

        // ── BLE (CoreBluetooth) ─────────────────────────────────────
        case let .bleStartScanning(serviceUuid):
            bleService.startScanning(serviceUuid: serviceUuid)

        case let .bleStartAdvertising(serviceUuid, payload):
            bleService.startAdvertising(serviceUuid: serviceUuid, payload: payload)

        case let .bleConnect(deviceId):
            bleService.connect(deviceId: deviceId)

        case let .bleWriteCharacteristic(uuid, data):
            bleService.writeCharacteristic(uuid: uuid, data: data)

        case let .bleReadCharacteristic(uuid):
            bleService.readCharacteristic(uuid: uuid)

        case .bleDisconnect:
            bleService.disconnect()

        // ── NFC ─────────────────────────────────────────────────────
        case .nfcActivate:
            // NFC is handled separately via NFCExchangeService (ISO7816 APDU).
            // The command/event path isn't used for NFC on iOS — the NFC
            // reader session drives the protocol directly.
            reportUnavailable(transport: "NFC-command")

        case .nfcDeactivate:
            break

        // ── Accelerometer (proximity shake) ────────────────────────
        case .accelerometerStart:
            reportUnavailable(transport: "accelerometer")

        case .accelerometerStop:
            break

        // ── Relay Escrow (link-mode exchange) ──────────────────────
        case .relayEscrowDeposit:
            reportUnavailable(transport: "relay-escrow")

        case .relayEscrowCheck:
            reportUnavailable(transport: "relay-escrow")

        case .relayEscrowRetrieve:
            reportUnavailable(transport: "relay-escrow")

        // ── Share Sheet ────────────────────────────────────────────
        case .showShareSheet:
            reportUnavailable(transport: "share-sheet")
        }
    }

    // MARK: - DTO Dispatch (ActionResult path)

    /// Dispatch an `ExchangeCommandDTO` from `ActionResult.exchangeCommands`.
    ///
    /// The JSON engine path sends commands as DTOs rather than UniFFI types.
    /// This mirrors `dispatch(_:)` for that path.
    func dispatchDTO(_ command: ExchangeCommandDTO) {
        switch command {
        case .qrDisplay, .qrRequestScan:
            break
        case let .audioEmitChallenge(data):
            emitAudioChallenge(data: Data(data))
        case let .audioListenForResponse(timeoutMs):
            listenForAudioResponse(timeoutMs: timeoutMs)
        case .audioStop:
            break
        case let .bleStartScanning(serviceUuid):
            bleService.startScanning(serviceUuid: serviceUuid)
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
        case .nfcActivate:
            reportUnavailable(transport: "NFC-command")
        case .nfcDeactivate:
            break
        case .unknown:
            break
        }
    }

    /// Stop all hardware operations and release resources.
    func stop() {
        bleService.disconnect()
    }

    // MARK: - Audio

    private func emitAudioChallenge(data _: Data) {
        // Audio proximity uses MobileProximityVerifier path, not command protocol.
        reportUnavailable(transport: "audio-command")
    }

    private func listenForAudioResponse(timeoutMs _: UInt64) {
        // Audio proximity uses MobileProximityVerifier path, not command protocol.
        reportUnavailable(transport: "audio-command")
    }

    // MARK: - Feedback

    private func reportUnavailable(transport: String) {
        guard let session else { return }
        try? session.applyHardwareEvent(
            event: .hardwareUnavailable(transport: transport)
        )
        drainAndDispatch()
    }

    private func reportError(transport: String, error: String) {
        guard let session else { return }
        try? session.applyHardwareEvent(
            event: .hardwareError(transport: transport, error: error)
        )
        drainAndDispatch()
    }
}
