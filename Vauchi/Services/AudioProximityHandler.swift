// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// AudioProximityHandler.swift
// Bridges MobileProximityHandler to MobileProximityVerifier for macOS exchange flow

import Foundation
import VauchiPlatform

/// Implements MobileProximityHandler by delegating to MobileProximityVerifier.
/// Used as the proximity callback for createQrExchange(proximity:).
class AudioProximityHandler: MobileProximityHandler {
    private let verifier: MobileProximityVerifier

    init(audioService: AudioProximityService) {
        verifier = MobileProximityVerifier(handler: audioService)
    }

    func verifyProximity(challenge: Data, timeoutMs: UInt64) -> String {
        let emitResult = verifier.emitChallenge(challenge: challenge)
        if !emitResult.success {
            return emitResult.error.isEmpty ? "Emit failed" : emitResult.error
        }

        let response = verifier.listenForResponse(timeoutMs: timeoutMs)
        if response.isEmpty {
            return "No response received"
        }

        return "" // success
    }
}
