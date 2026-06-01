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

            // B7 Phase 2: wire the keychain to PlatformAppEngine so the
            // core-driven shred DomainCommands (SoftShred / CancelShred /
            // HardShred / PanicShred) can reach the platform keychain.
            // Unlike iOS/Android, macOS has no widget/panic-shred path
            // through VauchiPlatform, so only the engine slot is wired.
            appEngine.setPlatformKeychain(keychain: VauchiKeychainBridge())

            // S4 — wire `ThemeService` + `LocalizationService` to the live
            // engine so subsequent theme/locale changes propagate to core
            // via `setRenderContextJson`. No vault → OS-native migration
            // is needed: the 2026-05-16 audit confirmed zero hand-written
            // `appPreferences()` callers on macOS, so the legacy vault
            // `app_preferences` row was never populated on this platform.
            // (Android needed a migration because its pre-S4 ThemeManager +
            // LocalizationManager read from the vault — see `android!407`.)
            ThemeService.shared.attachAppEngine(appEngine)
            LocalizationService.shared.attachAppEngine(appEngine)

            // Report this Mac's exchange-relevant hardware to core so the
            // Exchange mode picker offers only modes the device can perform.
            // Without this push core falls back to `DeviceCapabilities::default()`
            // (all-false) — see `2026-05-23-exchange-capabilities-frontend-gap`.
            pushDeviceCapabilities(engine: appEngine)
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

    /// Bridges core's `MobilePlatformKeychain` callback to the macOS
    /// `KeychainService`, so the `PlatformAppEngine` shred `DomainCommand`s
    /// (B7) can clear key material from the login keychain.
    ///
    /// Unlike iOS, macOS cannot re-wrap failures into the binding's
    /// `KeychainError` type: macOS declares a *local* `KeychainError` (in
    /// `KeychainService`) that shadows the unqualified name, and the binding
    /// type can't be module-qualified because the module name `VauchiPlatform`
    /// collides with the engine class of the same name. We therefore let the
    /// local `KeychainError` propagate — UniFFI's callback shim marshals any
    /// non-matching error as a descriptive `CALL_UNEXPECTED_ERROR` string, so
    /// core still sees a meaningful failure. `loadKey` maps the not-found case
    /// to `nil` as the protocol expects.
    class VauchiKeychainBridge: MobilePlatformKeychain {
        private let keychain = KeychainService.shared

        func saveKey(name: String, key: Data) throws {
            try keychain.save(key: name, data: key)
        }

        func loadKey(name: String) throws -> Data? {
            do {
                return try keychain.load(key: name)
            } catch KeychainError.notFound {
                return nil
            }
        }

        func deleteKey(name: String) throws {
            try keychain.delete(key: name)
        }
    }
#endif
