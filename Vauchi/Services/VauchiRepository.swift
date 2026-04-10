// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// VauchiRepository.swift
// Owns VauchiPlatform + PlatformAppEngine with shared storage key

import Foundation

#if canImport(VauchiPlatform)
    import VauchiPlatform

    enum VauchiRepositoryError: Error, LocalizedError {
        case storageKeyGeneration(String)
        case initialization(String)
        case deviceLocked

        var errorDescription: String? {
            switch self {
            case let .storageKeyGeneration(reason):
                "Failed to generate storage key: \(reason)"
            case let .initialization(reason):
                "Failed to initialize Vauchi: \(reason)"
            case .deviceLocked:
                "Device is locked — unlock to access secure storage"
            }
        }
    }

    class VauchiRepository: ObservableObject {
        let vauchi: VauchiPlatform
        let appEngine: PlatformAppEngine

        init(dataDir: String? = nil, relayUrl: String = "https://relay.vauchi.app") throws {
            let dir = dataDir ?? VauchiRepository.defaultDataDir()

            try FileManager.default.createDirectory(
                atPath: dir,
                withIntermediateDirectories: true
            )

            let storageKeyData: Data
            do {
                storageKeyData = try VauchiRepository.getOrCreateStorageKey()
            } catch let error as KeychainError {
                if case .deviceLocked = error {
                    throw VauchiRepositoryError.deviceLocked
                }
                throw VauchiRepositoryError.storageKeyGeneration("\(error)")
            }

            do {
                vauchi = try VauchiPlatform.newWithSecureKey(
                    dataDir: dir,
                    relayUrl: relayUrl,
                    storageKeyBytes: storageKeyData
                )
                appEngine = try PlatformAppEngine(
                    dataDir: dir,
                    relayUrl: relayUrl,
                    storageKeyBytes: storageKeyData
                )
            } catch {
                throw VauchiRepositoryError.initialization("\(error)")
            }
        }

        // MARK: - Storage Key Management

        static func getOrCreateStorageKey() throws -> Data {
            do {
                return try KeychainService.shared.loadStorageKey()
            } catch KeychainError.notFound {
                // Generate new 32-byte key
                var bytes = [UInt8](repeating: 0, count: 32)
                let status = SecRandomCopyBytes(kSecRandomDefault, 32, &bytes)
                guard status == errSecSuccess else {
                    // Zeroize before throwing
                    _ = bytes.withUnsafeMutableBufferPointer { ptr in
                        memset_s(ptr.baseAddress!, ptr.count, 0, ptr.count)
                    }
                    throw KeychainError.unknown(status)
                }
                let data = Data(bytes)
                // Zeroize the mutable byte array now that Data holds a copy
                bytes.withUnsafeMutableBufferPointer { ptr in
                    memset_s(ptr.baseAddress!, ptr.count, 0, ptr.count)
                }
                try KeychainService.shared.saveStorageKey(data)
                return data
            }
        }

        // MARK: - Data Directory

        static func defaultDataDir() -> String {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            return appSupport
                .appendingPathComponent("Vauchi")
                .appendingPathComponent("data")
                .path
        }

        /// Poll for OS notifications produced by the app engine.
        func pollNotifications() -> [MobilePendingNotification] {
            do {
                return try appEngine.pollNotifications()
            } catch {
                #if DEBUG
                    print("VauchiRepository: pollNotifications failed: \(error)")
                #endif
                return []
            }
        }

        /// Handle app backgrounded event (C1 auto-lock)
        func handleAppBackgrounded() -> String? {
            do {
                return try appEngine.handleAppBackgrounded()
            } catch {
                #if DEBUG
                    print("VauchiRepository: handleAppBackgrounded failed: \(error)")
                #endif
                return nil
            }
        }
    }
#endif
