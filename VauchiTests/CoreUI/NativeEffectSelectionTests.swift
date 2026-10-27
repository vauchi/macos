// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

@testable import Vauchi
import XCTest

/// A presentation command that reaches the hardware dispatcher decodes as
/// `.unknown` and is answered with HardwareUnavailable; Core's reply carries
/// the same command again, and the app overflowed its stack at launch
/// (vauchi/private#707).
final class NativeEffectSelectionTests: XCTestCase {
    private func selectedVariants(_ json: String) throws -> [String] {
        guard let selected = try NativeEffectSelection.platformEffectsJSON(in: Data(json.utf8)) else {
            return []
        }
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: selected) as? [String: Any])
        let commands = try XCTUnwrap(root["commands"] as? [Any])
        return commands.map { command in
            (command as? String) ?? ((command as? [String: Any])?.keys.first ?? "")
        }
    }

    func testNavigationAndOverlayDismissalStayWithThePresentation() throws {
        let variants = try selectedVariants("""
        {"commands":[
          {"SetNavigation":{"surface_id":"main","revision":1,"navigation":{"items":[]}}},
          {"DismissOverlay":{"surface_id":"main","revision":1,"kind":"navigation"}},
          {"BleStartScanning":{"service_uuid":"0000"}},
          "RequestBiometricUnlock"
        ]}
        """)

        XCTAssertEqual(variants, ["BleStartScanning"])
    }

    /// Left as platform effects they decode as `.unknown` and are answered
    /// on the wrong transport, so Core's export would wait forever
    /// (vauchi/private#712).
    func testUserPresenceCommandsStayWithThePresentation() throws {
        let variants = try selectedVariants("""
        {"commands":[
          {"CreateUserPresenceSecret":{"prompt":"p","binding":"biometry"}},
          {"RevealUserPresenceSecret":{"prompt":"p"}},
          "BleStopScanning"
        ]}
        """)

        XCTAssertEqual(variants, ["BleStopScanning"])
    }

    func testReloadThemeStaysWithThePresentation() throws {
        let variants = try selectedVariants(#"{"commands":["ReloadTheme","BleStopScanning"]}"#)

        XCTAssertEqual(variants, ["BleStopScanning"])
    }

    func testAnEnvelopeWithOnlyPresentationCommandsSelectsNothing() throws {
        let selected = try NativeEffectSelection.platformEffectsJSON(in: Data("""
        {"commands":[{"SetNavigation":{"surface_id":"main","revision":1,"navigation":{"items":[]}}}]}
        """.utf8))

        XCTAssertNil(selected)
    }

    func testPlatformEffectsKeepTheirOrderAndPayload() throws {
        let variants = try selectedVariants("""
        {"commands":["BleStopScanning",{"ScheduleWakeup":{"delay_millis":5}},"SomethingFromTheFuture"]}
        """)

        XCTAssertEqual(variants, ["BleStopScanning", "ScheduleWakeup", "SomethingFromTheFuture"])
    }
}
