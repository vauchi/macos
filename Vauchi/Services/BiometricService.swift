// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// BiometricService.swift
// Touch ID / biometric authentication using LocalAuthentication framework

import Foundation
import LocalAuthentication

enum BiometricError: Error, LocalizedError {
    case notAvailable
    case authenticationFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            "Biometric authentication is not available on this device"
        case let .authenticationFailed(reason):
            "Authentication failed: \(reason)"
        case .cancelled:
            "Authentication was cancelled"
        }
    }
}

/// Available biometric type on the current device.
enum BiometricType {
    case none
    case touchID

    var displayName: String {
        switch self {
        case .none: "None"
        case .touchID: "Touch ID"
        }
    }

    var systemImage: String {
        switch self {
        case .none: "lock.slash"
        case .touchID: "touchid"
        }
    }
}

/// Provides biometric (Touch ID) authentication for macOS.
///
/// On Macs with Touch ID (MacBook Pro with Touch Bar, M-series MacBooks),
/// this service uses `LAContext` to authenticate users. Falls back to
/// system password when biometrics are unavailable.
class BiometricService {
    static let shared = BiometricService()

    private init() {}

    // MARK: - Public API

    /// Returns the biometric type available on this device.
    var availableBiometricType: BiometricType {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }

    /// Checks whether biometric authentication (Touch ID) is available.
    func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Performs biometric authentication with the given reason string.
    ///
    /// Attempts Touch ID first. If biometrics are unavailable, falls back
    /// to device owner authentication (macOS login password).
    ///
    /// - Parameter reason: Localized string explaining why authentication is needed.
    /// - Returns: `true` if authentication succeeded.
    /// - Throws: `BiometricError` on failure or cancellation.
    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        var error: NSError?

        let policy: LAPolicy
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            policy = .deviceOwnerAuthenticationWithBiometrics
        } else {
            // Fall back to password authentication
            policy = .deviceOwnerAuthentication
        }

        do {
            return try await context.evaluatePolicy(policy, localizedReason: reason)
        } catch let authError as LAError {
            switch authError.code {
            case .userCancel, .appCancel, .systemCancel:
                throw BiometricError.cancelled
            case .biometryNotAvailable, .biometryNotEnrolled:
                throw BiometricError.notAvailable
            default:
                throw BiometricError.authenticationFailed(authError.localizedDescription)
            }
        }
    }

    /// Performs biometric-only authentication (no password fallback).
    ///
    /// - Parameter reason: Localized string explaining why authentication is needed.
    /// - Returns: `true` if biometric authentication succeeded.
    /// - Throws: `BiometricError` if biometrics are unavailable or authentication fails.
    func authenticateBiometricOnly(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "" // Hide "Enter Password" fallback
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw BiometricError.notAvailable
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch let authError as LAError {
            switch authError.code {
            case .userCancel, .appCancel, .systemCancel:
                throw BiometricError.cancelled
            case .biometryNotAvailable, .biometryNotEnrolled:
                throw BiometricError.notAvailable
            default:
                throw BiometricError.authenticationFailed(authError.localizedDescription)
            }
        }
    }
}
