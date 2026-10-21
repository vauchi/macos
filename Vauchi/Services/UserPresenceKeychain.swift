// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import LocalAuthentication
import Security

enum UserPresenceKeychainError: Error, Equatable {
    case status(OSStatus)
}

/// One secret whose every read needs the OS user-presence check (Touch ID
/// or the login password); `SystemUserPresenceKeychain` in the app, a fake
/// in tests.
protocol UserPresenceKeychain {
    var canCheckUserPresence: Bool { get }
    func replaceSecret(_ secret: [UInt8]) throws
    func revealSecret(prompt: String) throws -> [UInt8]
}

/// Data-protection keychain item guarded by `.userPresence`, so the ACL
/// rather than this code demands the check on each read (vauchi/private#712).
/// The file-based login keychain ignores user-presence ACLs, which is why
/// the item must live in the data-protection keychain.
final class SystemUserPresenceKeychain: UserPresenceKeychain {
    private let service = "app.vauchi.macos.user-presence"
    private let account = "sealed-secret"

    private var itemQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    /// A Mac without Touch ID still has its login password as the device
    /// credential, so `.deviceOwnerAuthentication` is the policy to probe.
    var canCheckUserPresence: Bool {
        var error: NSError?
        guard LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }
        return dataProtectionKeychainIsReachable()
    }

    /// A build signed without an application identifier (the ad-hoc `-`
    /// signature) is refused writes to the data-protection keychain with
    /// `errSecMissingEntitlement`, while its reads merely find nothing.
    /// Deleting an account that is never written shows which, without a
    /// prompt and without touching the sealed secret.
    private func dataProtectionKeychainIsReachable() -> Bool {
        var probe = itemQuery
        probe[kSecAttrAccount as String] = "entitlement-probe"
        return SecItemDelete(probe as CFDictionary) != errSecMissingEntitlement
    }

    func replaceSecret(_ secret: [UInt8]) throws {
        let deleted = SecItemDelete(itemQuery as CFDictionary)
        guard deleted == errSecSuccess || deleted == errSecItemNotFound else {
            throw UserPresenceKeychainError.status(deleted)
        }
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            nil
        ) else {
            throw UserPresenceKeychainError.status(errSecParam)
        }
        var attributes = itemQuery
        attributes[kSecAttrAccessControl as String] = access
        attributes[kSecValueData as String] = Data(secret)
        let added = SecItemAdd(attributes as CFDictionary, nil)
        guard added == errSecSuccess else {
            throw UserPresenceKeychainError.status(added)
        }
    }

    /// A fresh context with no reuse window, so an earlier unlock or check
    /// never stands in for this one.
    func revealSecret(prompt: String) throws -> [UInt8] {
        let context = LAContext()
        context.localizedReason = prompt
        context.touchIDAuthenticationAllowableReuseDuration = 0
        var query = itemQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            throw UserPresenceKeychainError.status(status)
        }
        guard let data = result as? Data else {
            throw UserPresenceKeychainError.status(errSecDecode)
        }
        return [UInt8](data)
    }
}
