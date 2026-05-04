// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// AppState.swift
// Top-level @MainActor state object owning VauchiRepository + AppViewModel,
// driving auth/lock state, and bridging app lifecycle notifications from
// AppDelegate into core actions (background lock, foreground refresh,
// content updates, biometric retry).

import Combine
import CoreUIModels
import Foundation
import SwiftUI

#if canImport(VauchiPlatform)
    import VauchiPlatform

    /// Top-level app state that owns VauchiRepository and AppViewModel.
    @MainActor
    class AppState: ObservableObject {
        @Published var viewModel: AppViewModel?
        @Published var error: String?
        @Published var isAuthenticationRequired = false

        private var repository: VauchiRepository?

        init() {
            // Skip heavy initialization when running as a test host.
            // XCTest injects the test bundle into the app process — the app's
            // full startup (Keychain, native library, biometric auth) would
            // hang on headless CI runners without a login session.
            guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
                return
            }
            initializeRepository()

            #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--reset-for-testing") {
                    seedTestIdentityIfNeeded()
                }
            #endif

            NotificationCenter.default.addObserver(
                forName: .vauchiAppResignedActive,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleAppBackgrounded()
            }

            NotificationCenter.default.addObserver(
                forName: .vauchiAppBecameActive,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.viewModel?.loadScreen()
            }
        }

        #if DEBUG
            private func seedTestIdentityIfNeeded() {
                guard let repo = repository else {
                    print("[Vauchi] --reset-for-testing: no repository")
                    return
                }
                guard !repo.vauchi.hasIdentity() else {
                    print("[Vauchi] --reset-for-testing: identity exists")
                    return
                }
                do {
                    try repo.vauchi.createIdentity(displayName: "Test User")
                    print("[Vauchi] --reset-for-testing: identity created")
                    let appViewModel = AppViewModel(appEngine: repo.appEngine)
                    appViewModel.vauchi = repo.vauchi
                    viewModel = appViewModel
                } catch {
                    print("[Vauchi] --reset-for-testing: failed: \(error)")
                }
            }
        #endif

        func initializeRepository() {
            do {
                let repo = try VauchiRepository()
                repository = repo
                let appViewModel = AppViewModel(appEngine: repo.appEngine)
                appViewModel.vauchi = repo.vauchi
                viewModel = appViewModel
                isAuthenticationRequired = false
                error = nil
                checkContentUpdates(vauchi: repo.vauchi)
            } catch VauchiRepositoryError.deviceLocked {
                isAuthenticationRequired = true
                print("VauchiApp: device locked, authentication required")
            } catch {
                self.error = error.localizedDescription
                print("VauchiApp: failed to initialize: \(error)")
            }
        }

        /// Check for content updates (locales, themes) in the background after startup.
        private func checkContentUpdates(vauchi: VauchiPlatform) {
            guard vauchi.isContentUpdatesSupported() else { return }

            Task.detached(priority: .utility) { [weak self] in
                let status = vauchi.checkContentUpdates()
                guard case .updatesAvailable = status else { return }

                let result = vauchi.applyContentUpdates()
                if case let .applied(applied, _) = result {
                    if applied.contains(.themes) {
                        await MainActor.run {
                            ThemeService.shared.applySelectedTheme()
                        }
                    }
                    // Locale store is hot-reloaded by core — no action needed
                    await MainActor.run {
                        self?.viewModel?.invalidateAll()
                    }
                }
            }
        }

        /// Authenticate with Touch ID / password and retry initialization.
        func authenticateAndRetry() {
            Task {
                do {
                    let success = try await BiometricService.shared.authenticate(
                        reason: LocalizationService.shared.t("lock.auth_reason")
                    )
                    if success {
                        initializeRepository()
                    }
                } catch BiometricError.cancelled {
                    print("VauchiApp: authentication cancelled")
                } catch {
                    print("VauchiApp: authentication failed: \(error)")
                }
            }
        }

        /// Handle app backgrounded event (C1 auto-lock).
        func handleAppBackgrounded() {
            guard repository?.handleAppBackgrounded() != nil else { return }
            // Core navigated to Lock screen — refresh UI to show it
            viewModel?.loadScreen()
        }

        /// Poll for and display OS notifications (E).
        func pollNotifications() {
            NotificationService.shared.pollAndDisplayNotifications(repository: repository)
        }
    }
#endif
