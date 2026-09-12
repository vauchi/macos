// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

@testable import Vauchi
import XCTest

final class PresentationCommandTests: XCTestCase {
    private func decode(_ json: String) throws -> [PresentationCommand] {
        try JSONDecoder()
            .decode(PresentationCommandEnvelope.self, from: Data(json.utf8))
            .commands
    }

    /// Core 0.67.1 emits this from the lock screen's Touch ID button. Left
    /// as an opaque platform effect it fell through to the hardware
    /// dispatcher as `.unknown`, which answered with an "unavailable" toast
    /// instead of a Touch ID prompt.
    func testRequestBiometricUnlockDecodesAsItsOwnCommand() throws {
        let commands = try decode(#"{"commands":["RequestBiometricUnlock"]}"#)

        XCTAssertEqual(commands.count, 1)
        guard case .requestBiometricUnlock = commands[0] else {
            return XCTFail("expected .requestBiometricUnlock, got \(commands[0])")
        }
    }

    func testUnknownStringVariantsStayOpaquePlatformEffects() throws {
        let commands = try decode(#"{"commands":["SomethingFromTheFuture"]}"#)

        guard case let .platformEffect(variant, payload) = commands[0] else {
            return XCTFail("expected .platformEffect, got \(commands[0])")
        }
        XCTAssertEqual(variant, "SomethingFromTheFuture")
        XCTAssertNil(payload)
    }
}
