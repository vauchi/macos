// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// DeviceCapabilitiesPusherTests.swift
// Pins the JSON wire shape that `DeviceCapabilitiesPusher` sends to
// core's `setDeviceCapabilitiesJson` on macOS. The string must
// deserialize into core's `DeviceCapabilities` (serde, snake_case keys,
// bare-string enum variants) with `platform` = `"Desktop"`. A silent
// key/casing drift here would re-introduce the all-false
// `DeviceCapabilities::default()` bug that
// `2026-05-23-exchange-capabilities-frontend-gap` was filed for.
//
// Hardware detection (`detectDeviceHardware`) is not unit-tested: it
// reads host hardware and has no deterministic output. The contract
// that matters — the wire shape — lives in the pure
// `buildDeviceCapabilitiesJson` builder, fully covered here.

@testable import Vauchi
import XCTest

final class DeviceCapabilitiesPusherTests: XCTestCase {
    /// Parse the builder output back into a dictionary so assertions do
    /// not depend on key ordering.
    private func parse(_ json: String) -> [String: Any] {
        let data = Data(json.utf8)
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: Any]
        else {
            XCTFail("builder produced invalid JSON: \(json)")
            return [:]
        }
        return dict
    }

    /// A Touch ID MacBook with camera and Secure Enclave.
    func test_touch_id_mac_serializes_every_field_with_desktop_platform() {
        let hardware = DeviceHardware(
            hasNfc: false,
            hasBle: true,
            hasCamera: true,
            audio: .full,
            hasBiometrics: true,
            biometricType: .fingerprint,
            hasSecureEnclave: true,
            hasAccelerometer: false,
            hasInternet: true,
            hasUsbPort: false
        )

        let dict = parse(buildDeviceCapabilitiesJson(hardware))

        XCTAssertEqual(dict["has_nfc"] as? Bool, false)
        XCTAssertEqual(dict["has_ble"] as? Bool, true)
        XCTAssertEqual(dict["has_camera"] as? Bool, true)
        XCTAssertEqual(dict["audio"] as? String, "Full")
        XCTAssertEqual(dict["has_biometrics"] as? Bool, true)
        XCTAssertEqual(dict["biometric_type"] as? String, "Fingerprint")
        XCTAssertEqual(dict["has_secure_enclave"] as? Bool, true)
        XCTAssertEqual(dict["platform"] as? String, "Desktop")
        XCTAssertEqual(dict["has_accelerometer"] as? Bool, false)
        XCTAssertEqual(dict["has_internet"] as? Bool, true)
        XCTAssertEqual(dict["has_usb_port"] as? Bool, false)
    }

    /// A headless / pre-T2 Mac: no camera, no biometrics, no Secure
    /// Enclave. `biometric_type` must be present-as-null.
    func test_mac_without_biometrics_or_secure_enclave() {
        let hardware = DeviceHardware(
            hasNfc: false,
            hasBle: true,
            hasCamera: false,
            audio: .full,
            hasBiometrics: false,
            biometricType: nil,
            hasSecureEnclave: false,
            hasAccelerometer: false,
            hasInternet: true,
            hasUsbPort: false
        )

        let json = buildDeviceCapabilitiesJson(hardware)
        let dict = parse(json)

        XCTAssertTrue(
            json.contains("\"biometric_type\":null"),
            "nil biometricType must serialize as JSON null, got: \(json)"
        )
        // JSON `null` decodes to NSNull (key present, value null) — exactly
        // what serde's `Option<BiometricType>` accepts for the `None` case.
        XCTAssertTrue(
            dict["biometric_type"] is NSNull,
            "biometric_type must be present as JSON null"
        )
        XCTAssertEqual(dict["has_biometrics"] as? Bool, false)
        XCTAssertEqual(dict["has_secure_enclave"] as? Bool, false)
        XCTAssertEqual(dict["has_camera"] as? Bool, false)
        XCTAssertEqual(dict["platform"] as? String, "Desktop")
    }

    /// Every `DeviceAudioCapability` rawValue matches a core variant.
    func test_audio_capability_raw_values_match_core_variants() {
        XCTAssertEqual(DeviceAudioCapability.full.rawValue, "Full")
        XCTAssertEqual(DeviceAudioCapability.emitOnly.rawValue, "EmitOnly")
        XCTAssertEqual(DeviceAudioCapability.receiveOnly.rawValue, "ReceiveOnly")
        XCTAssertEqual(DeviceAudioCapability.none.rawValue, "None")
    }

    /// Touch ID maps to `Fingerprint`; `.none` maps to nil.
    func test_biometry_type_mapping() {
        XCTAssertEqual(mapBiometryType(.touchID), .fingerprint)
        XCTAssertNil(mapBiometryType(.none))
    }
}
