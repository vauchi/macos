// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Owns VauchiPlatform + PlatformAppEngine with shared storage key

import Foundation

#if canImport(VauchiPlatform)
    import VauchiPlatform

    enum VauchiRepositoryError: Error, LocalizedError {
        case initialization(String)

        var errorDescription: String? {
            switch self {
            case let .initialization(reason):
                "Failed to initialize Vauchi: \(reason)"
            }
        }
    }

    class VauchiRepository: ObservableObject {
        let appEngine: PlatformAppEngine

        /// Core keeps every key that opens the database in `keychain`, so a
        /// shred that deletes them destroys access (vauchi/private#580). A
        /// locked keychain does not fail here: Core starts locked and shows
        /// its own unlock screen.
        init(
            dataDir: String? = nil,
            relayUrl: String = "https://relay.vauchi.app",
            keychain: MobilePlatformKeychain = VauchiKeychainBridge()
        ) throws {
            let dir = dataDir ?? VauchiRepository.defaultDataDir()

            try FileManager.default.createDirectory(
                atPath: dir,
                withIntermediateDirectories: true
            )

            do {
                appEngine = try PlatformAppEngine.openWithKeychain(
                    dataDir: dir,
                    relayUrl: relayUrl,
                    shellStorageKey: nil,
                    keychain: keychain
                )
            } catch {
                throw VauchiRepositoryError.initialization("\(error)")
            }

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
    }

    /// Adapts the macOS `KeychainService` to Core's `MobilePlatformKeychain`:
    /// Core keeps every key that opens the database here (ADR-033).
    ///
    /// Until Core stores its own bootstrap key, the bootstrap name is served
    /// from the storage key this app kept itself before vauchi/private#580,
    /// and deleting it deletes that key too.
    class VauchiKeychainBridge: MobilePlatformKeychain {
        private static let bootstrapKeyName = "storage_bootstrap"
        private static let legacyStorageKeyName = "storage_key"

        private let keychain: KeychainStoring

        init(keychain: KeychainStoring = KeychainService.shared) {
            self.keychain = keychain
        }

        func saveKey(name: String, key: Data) throws {
            do {
                try keychain.save(key: name, data: key)
            } catch {
                throw Self.keychainFailure("saveKey(\(name))", error)
            }
        }

        func loadKey(name: String) throws -> Data? {
            do {
                return try keychain.load(key: name)
            } catch KeychainServiceError.notFound {
                guard name == Self.bootstrapKeyName else { return nil }
                return try loadLegacyStorageKey()
            } catch {
                throw Self.keychainFailure("loadKey(\(name))", error)
            }
        }

        func deleteKey(name: String) throws {
            do {
                try keychain.delete(key: name)
                if name == Self.bootstrapKeyName {
                    try keychain.delete(key: Self.legacyStorageKeyName)
                }
            } catch {
                throw Self.keychainFailure("deleteKey(\(name))", error)
            }
        }

        private func loadLegacyStorageKey() throws -> Data? {
            do {
                return try keychain.load(key: Self.legacyStorageKeyName)
            } catch KeychainServiceError.notFound {
                return nil
            } catch {
                throw Self.keychainFailure("loadKey(\(Self.bootstrapKeyName))", error)
            }
        }

        /// Names the failure for Core, which chooses the screen (ADR-045).
        private static func keychainFailure(_ operation: String, _ error: Error) -> KeychainError {
            if case KeychainServiceError.deviceLocked = error {
                return .AuthenticationRequired
            }
            return .OperationFailed(msg: "\(operation): \(error)")
        }
    }
#endif
