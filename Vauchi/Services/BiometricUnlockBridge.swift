// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import VauchiPlatform

/// Translates a Touch ID prompt's outcome into the hardware event Core
/// expects after `RequestBiometricUnlock` (ADR-066). Core consults its
/// duress state on success and answers with the authentication
/// requirement; failures reuse the shapes every transport reports.
enum BiometricUnlockBridge {
    /// Not in Core's nameable capability list, so it surfaces as the
    /// generic "unavailable" toast rather than a mistranslated name.
    static let transport = "biometrics"

    /// `nil` when the user dismissed the sheet: the lock screen simply
    /// stays, and there is no fault for Core to alert about.
    static func event(for result: Result<Bool, Error>) -> MobileEvent? {
        switch result {
        case .success(true):
            return .biometricUnlockSucceeded
        case .success(false):
            return .hardwareError(transport: transport, error: "Authentication failed")
        case .failure(BiometricError.cancelled):
            return nil
        case .failure(BiometricError.notAvailable):
            return .hardwareUnavailable(transport: transport)
        case let .failure(BiometricError.authenticationFailed(reason)):
            return .hardwareError(transport: transport, error: reason)
        case let .failure(error):
            return .hardwareError(transport: transport, error: error.localizedDescription)
        }
    }
}
