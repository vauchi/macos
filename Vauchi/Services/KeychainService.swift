// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// KeychainService.swift
// Secure storage using macOS Keychain

import Foundation
import Security

enum KeychainError: Error {
    case duplicateEntry
    case unknown(OSStatus)
    case notFound
    case invalidData
    case deviceLocked
}

class KeychainService {
    static let shared = KeychainService()

    private let service = "app.vauchi.macos"

    private init() {}

    // MARK: - Public API

    func save(key: String, data: Data) throws {
        try saveToKeychain(key: key, data: data)
    }

    func load(key: String) throws -> Data {
        try loadFromKeychain(key: key)
    }

    func delete(key: String) throws {
        try deleteFromKeychain(key: key)
    }

    // MARK: - Keychain Operations

    private func saveToKeychain(key: String, data: Data) throws {
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        // Try to update first
        var status = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)

        if status == errSecItemNotFound {
            let saveQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            ]
            status = SecItemAdd(saveQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            if status == errSecInteractionNotAllowed {
                throw KeychainError.deviceLocked
            }
            throw KeychainError.unknown(status)
        }
    }

    private func loadFromKeychain(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.notFound
            }
            if status == errSecInteractionNotAllowed {
                throw KeychainError.deviceLocked
            }
            throw KeychainError.unknown(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return data
    }

    private func deleteFromKeychain(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }

    // MARK: - Vauchi specific

    func saveStorageKey(_ key: Data) throws {
        try save(key: "storage_key", data: key)
    }

    func loadStorageKey() throws -> Data {
        try load(key: "storage_key")
    }
}
