// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Detects this Mac's exchange-relevant hardware and pushes it to core's
// `DeviceCapabilities` via `setDeviceCapabilitiesJson`. Mirrors iOS's
// `DeviceCapabilitiesPusher.swift` (and `RenderContextPusher.swift`):
// a pure JSON builder + a thin side-effecting push that does the
// hardware queries.
//
// macOS leg (G2) of `2026-05-23-exchange-capabilities-frontend-gap`:
// the 2026-04-01 exchange-modes-tier1 plan shipped the core surface
// but no frontend reported its hardware, so the Exchange mode picker
// rendered against `DeviceCapabilities::default()` (all-false).
//
// macOS differs from iOS: no NFC, no accelerometer, `platform` is
// `Desktop`, and Secure Enclave genuinely varies (Intel Macs without
// a T2 chip lack it) so it is detected rather than assumed.

import AVFoundation
import CryptoKit
import Foundation
import LocalAuthentication

/// Ultrasonic audio capability — `rawValue`s match core's
/// `AudioCapability` serde variant names (`core/vauchi-core/src/types.rs`).
enum DeviceAudioCapability: String {
    case full = "Full"
    case emitOnly = "EmitOnly"
    case receiveOnly = "ReceiveOnly"
    case none = "None"
}

/// Biometric hardware kind — `rawValue`s match core's `BiometricType`
/// serde variant names. Macs only ever report `.fingerprint` (Touch ID);
/// there is no Face ID on macOS.
enum DeviceBiometricType: String {
    case fingerprint = "Fingerprint"
    case faceId = "FaceId"
    case iris = "Iris"
}

/// Plain value type holding the detected hardware flags. Separated from
/// detection so the JSON serialization is unit-testable without
/// hardware.
struct DeviceHardware {
    var hasNfc: Bool
    var hasBle: Bool
    var hasCamera: Bool
    var audio: DeviceAudioCapability
    var hasBiometrics: Bool
    var biometricType: DeviceBiometricType?
    var hasSecureEnclave: Bool
    var hasAccelerometer: Bool
    var hasInternet: Bool
    var hasUsbPort: Bool
}

/// Build the JSON object core's `DeviceCapabilities` deserializes
/// (`serde`, snake_case, every field `#[serde(default)]`). `platform`
/// is always `"Desktop"` from this pusher. Pure — no hardware access.
func buildDeviceCapabilitiesJson(_ hardware: DeviceHardware) -> String {
    var parts: [String] = [
        "\"has_nfc\":\(jsonBool(hardware.hasNfc))",
        "\"has_ble\":\(jsonBool(hardware.hasBle))",
        "\"has_camera\":\(jsonBool(hardware.hasCamera))",
        "\"audio\":\"\(hardware.audio.rawValue)\"",
        "\"has_biometrics\":\(jsonBool(hardware.hasBiometrics))",
    ]
    if let biometricType = hardware.biometricType {
        parts.append("\"biometric_type\":\"\(biometricType.rawValue)\"")
    } else {
        parts.append("\"biometric_type\":null")
    }
    parts.append("\"has_secure_enclave\":\(jsonBool(hardware.hasSecureEnclave))")
    parts.append("\"platform\":\"Desktop\"")
    parts.append("\"has_accelerometer\":\(jsonBool(hardware.hasAccelerometer))")
    parts.append("\"has_internet\":\(jsonBool(hardware.hasInternet))")
    parts.append("\"has_usb_port\":\(jsonBool(hardware.hasUsbPort))")
    return "{" + parts.joined(separator: ",") + "}"
}

private func jsonBool(_ value: Bool) -> String {
    value ? "true" : "false"
}

/// Query macOS hardware APIs for the exchange-relevant capabilities.
///
/// Conservative choices:
/// - `hasNfc` / `hasAccelerometer` are `false`: no Mac ships either.
/// - `hasBle` / `hasInternet` are `true` for every Vauchi-supported Mac.
/// - `hasSecureEnclave` is detected via `SecureEnclave.isAvailable`
///   (Apple Silicon + T2 Macs have it; pre-T2 Intel Macs do not).
/// - `hasUsbPort` is `false`: Vauchi's Cable exchange is not a desktop
///   path, so we do not advertise a mode the Mac cannot perform.
/// - `audio` is `.full`: every Mac has a speaker and microphone.
func detectDeviceHardware() -> DeviceHardware {
    let laContext = LAContext()
    var laError: NSError?
    let hasBiometrics = laContext.canEvaluatePolicy(
        .deviceOwnerAuthenticationWithBiometrics,
        error: &laError
    )
    // `biometryType` is only populated after `canEvaluatePolicy` runs.
    let biometricType: DeviceBiometricType? = hasBiometrics
        ? mapBiometryType(laContext.biometryType)
        : nil

    return DeviceHardware(
        hasNfc: false,
        hasBle: true,
        hasCamera: AVCaptureDevice.default(for: .video) != nil,
        audio: .full,
        hasBiometrics: hasBiometrics,
        biometricType: biometricType,
        hasSecureEnclave: SecureEnclave.isAvailable,
        hasAccelerometer: false,
        hasInternet: true,
        hasUsbPort: false
    )
}

/// Map `LABiometryType` to core's biometric kind. macOS only ever
/// reports Touch ID; `.faceID` is handled defensively for forward
/// compatibility. `.none` (and any future unmapped type) → nil.
func mapBiometryType(_ type: LABiometryType) -> DeviceBiometricType? {
    switch type {
    case .touchID: return .fingerprint
    case .faceID: return .faceId
    default: return nil
    }
}

#if canImport(VauchiPlatform)
    import VauchiPlatform

    /// Detect this Mac's hardware and push it to core's
    /// `DeviceCapabilities`. Call once at boot, before the first
    /// navigation to the Exchange screen. Idempotent at the core level —
    /// a later call simply overwrites the stored capabilities.
    func pushDeviceCapabilities(engine: PlatformAppEngine?) {
        guard let engine else { return }
        let json = buildDeviceCapabilitiesJson(detectDeviceHardware())
        do {
            try engine.setDeviceCapabilitiesJson(capabilitiesJson: json)
        } catch {
            NSLog("[DeviceCapabilitiesPusher] Failed: \(type(of: error))")
        }
    }
#endif
