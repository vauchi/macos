// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

@testable import Vauchi
import VauchiPlatform
import XCTest

/// Maps the outcome of a Touch ID prompt onto the event Core expects after
/// `RequestBiometricUnlock` (ADR-066). Core consults its duress state on
/// `BiometricUnlockSucceeded` and answers with the authentication
/// requirement; the failure shapes are the ones every hardware transport
/// already reports.
final class BiometricUnlockBridgeTests: XCTestCase {
    func testSuccessReportsBiometricUnlockSucceeded() {
        XCTAssertEqual(
            BiometricUnlockBridge.event(for: .success(true)),
            .biometricUnlockSucceeded
        )
    }

    func testUnavailableBiometryReportsHardwareUnavailable() {
        XCTAssertEqual(
            BiometricUnlockBridge.event(for: .failure(BiometricError.notAvailable)),
            .hardwareUnavailable(transport: BiometricUnlockBridge.transport)
        )
    }

    func testFailedAuthenticationReportsHardwareError() {
        XCTAssertEqual(
            BiometricUnlockBridge.event(for: .failure(BiometricError.authenticationFailed("no match"))),
            .hardwareError(transport: BiometricUnlockBridge.transport, error: "no match")
        )
        XCTAssertEqual(
            BiometricUnlockBridge.event(for: .success(false)),
            .hardwareError(transport: BiometricUnlockBridge.transport, error: "Authentication failed")
        )
    }

    /// Dismissing the sheet is the user's choice, not a hardware fault: the
    /// lock screen simply stays, so Core gets nothing to alert about.
    func testCancellationReportsNothing() {
        XCTAssertNil(BiometricUnlockBridge.event(for: .failure(BiometricError.cancelled)))
    }
}
