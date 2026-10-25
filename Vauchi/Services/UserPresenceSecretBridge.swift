// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Security
import VauchiPlatform

/// The shell's answer to a user-presence command (vauchi/private#712).
enum UserPresenceEvent: Equatable, CustomStringConvertible {
    case created([UInt8])
    case revealed([UInt8])
    case cancelled
    case unavailable
    /// The sealed item is gone or no longer opens (vauchi/private#778).
    case missing

    var eventJSON: String {
        hardwareEventJson(event: event)
    }

    private var event: MobileEvent {
        switch self {
        case let .created(secret):
            .userPresenceSecretCreated(secret: Data(secret))
        case let .revealed(secret):
            .userPresenceSecretRevealed(secret: Data(secret))
        case .cancelled:
            .userPresenceCheckCancelled
        case .unavailable:
            .hardwareUnavailable(transport: UserPresenceSecretBridge.transport)
        case .missing:
            .userPresenceSecretMissing
        }
    }

    /// Keeps the secret out of any log line that interpolates the event.
    var description: String {
        switch self {
        case .created: "created(<redacted>)"
        case .revealed: "revealed(<redacted>)"
        case .cancelled: "cancelled"
        case .unavailable: "unavailable"
        case .missing: "missing"
        }
    }
}

/// Executes `CreateUserPresenceSecret` / `RevealUserPresenceSecret` (ADR-066,
/// vauchi/private#712). Core checks the bytes against the digest it kept, so
/// a bare success here confirms nothing.
enum UserPresenceSecretBridge {
    /// The transport Core matches to fall back when the check is unavailable.
    static let transport = "user_presence"
    static let secretLength = 32

    /// `nil` for any other command. Blocks while the OS prompt is up, so call
    /// it off the main actor.
    static func answer(
        to command: PresentationCommand,
        keychain: UserPresenceKeychain,
        randomBytes: (Int) throws -> [UInt8] = systemRandomBytes
    ) -> UserPresenceEvent? {
        switch command {
        case let .createUserPresenceSecret(prompt, binding):
            create(prompt: prompt, binding: binding, keychain: keychain, randomBytes: randomBytes)
        case let .revealUserPresenceSecret(prompt):
            reveal(prompt: prompt, keychain: keychain)
        default:
            nil
        }
    }

    static func systemRandomBytes(_ count: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw UserPresenceKeychainError.status(status)
        }
        return bytes
    }

    /// Answers with the bytes read back through the check, not the ones just
    /// generated, so the event proves the OS check ran.
    private static func create(
        prompt: String,
        binding: UserPresenceBinding?,
        keychain: UserPresenceKeychain,
        randomBytes: (Int) throws -> [UInt8]
    ) -> UserPresenceEvent {
        guard let binding, keychain.canCheckUserPresence else { return .unavailable }
        do {
            var fresh = try randomBytes(secretLength)
            defer { wipe(&fresh) }
            guard fresh.count == secretLength else { return .unavailable }
            try keychain.replaceSecret(fresh, binding: binding)
            return try sealedSecret(prompt: prompt, keychain: keychain).map(UserPresenceEvent.created)
                ?? .unavailable
        } catch {
            return outcome(for: error)
        }
    }

    private static func reveal(prompt: String, keychain: UserPresenceKeychain) -> UserPresenceEvent {
        guard keychain.canCheckUserPresence else { return .unavailable }
        do {
            return try sealedSecret(prompt: prompt, keychain: keychain).map(UserPresenceEvent.revealed)
                ?? .unavailable
        } catch UserPresenceKeychainError.status(errSecItemNotFound) {
            return .missing
        } catch {
            return outcome(for: error)
        }
    }

    /// `nil` for an item of the wrong size: it is not a secret this shell
    /// sealed, and Core should not count it as a wrong answer.
    private static func sealedSecret(prompt: String, keychain: UserPresenceKeychain) throws -> [UInt8]? {
        var secret = try keychain.revealSecret(prompt: prompt)
        guard secret.count == secretLength else {
            wipe(&secret)
            return nil
        }
        return secret
    }

    /// Dismissing the prompt and failing it both leave the user unconfirmed;
    /// Core ends the request either way. Anything else (missing entitlement,
    /// no interaction possible, an item gone right after sealing it) means
    /// this Mac cannot do the check, so Core falls back.
    private static func outcome(for error: Error) -> UserPresenceEvent {
        switch error {
        case UserPresenceKeychainError.status(errSecUserCanceled),
             UserPresenceKeychainError.status(errSecAuthFailed):
            .cancelled
        default:
            .unavailable
        }
    }

    private static func wipe(_ bytes: inout [UInt8]) {
        for index in bytes.indices {
            bytes[index] = 0
        }
    }
}
