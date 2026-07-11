// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

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

            // A tapped notification forwards its core-supplied deep link to core
            // as `LinkOpened`; core owns the destination.
            NotificationService.shared.onDeepLinkTapped = { [weak self] uri in
                Task { @MainActor in self?.openDeepLink(uri) }
            }
        }

        #if DEBUG
            private func seedTestIdentityIfNeeded() {
                guard let repo = repository else {
                    print("[Vauchi] --reset-for-testing: no repository")
                    return
                }
                guard !((try? repo.appEngine.hasIdentity()) ?? false) else {
                    print("[Vauchi] --reset-for-testing: identity exists")
                    return
                }
                do {
                    try repo.appEngine.createIdentity(displayName: "Test User")
                    print("[Vauchi] --reset-for-testing: identity created")
                    viewModel = AppViewModel(appEngine: repo.appEngine)
                } catch {
                    print("[Vauchi] --reset-for-testing: failed: \(error)")
                }
            }
        #endif

        func initializeRepository() {
            do {
                let repo = try VauchiRepository()
                repository = repo
                viewModel = AppViewModel(appEngine: repo.appEngine)
                isAuthenticationRequired = false
                error = nil
                runContentUpdateCycle(appEngine: repo.appEngine)
            } catch VauchiRepositoryError.deviceLocked {
                isAuthenticationRequired = true
                print("VauchiApp: device locked, authentication required")
            } catch {
                self.error = error.localizedDescription
                print("VauchiApp: failed to initialize: \(error)")
            }
        }

        /// Native follow-ups for a content-update cycle outcome. Pure so
        /// the decision is unit-testable (`ContentUpdateCycleTests`)
        /// without an engine; the domain check→apply sequencing lives in
        /// core (`RunContentUpdateCycle`). `refreshAppearance` implies
        /// `applied` (core invariant), so the `applied` guard alone gates
        /// both follow-ups.
        nonisolated static func contentCycleActions(
            _ outcome: MobileContentCycleOutcome
        ) -> (refreshTheme: Bool, reloadUI: Bool) {
            guard outcome.applied else { return (false, false) }
            return (outcome.refreshAppearance, true)
        }

        /// Run the remote content-update cycle in the background after
        /// startup. Core owns the whole check→apply→invalidate sequence
        /// (`RunContentUpdateCycle`); macOS only performs the native
        /// consequences — re-applying the theme when the appearance
        /// changed and reloading the UI when anything was applied. Best
        /// effort: fired once on launch, no retry; failures return a
        /// no-op outcome, logged in debug without disrupting startup.
        private func runContentUpdateCycle(appEngine: PlatformAppEngine) {
            Task.detached(priority: .utility) { [weak self] in
                let outcome: MobileContentCycleOutcome
                do {
                    outcome = try appEngine.runContentUpdateCycle()
                } catch {
                    print("AppState: runContentUpdateCycle dispatch failed: \(error)")
                    return
                }
                let actions = AppState.contentCycleActions(outcome)
                guard actions.reloadUI else { return }
                await MainActor.run {
                    if actions.refreshTheme {
                        ThemeService.shared.applySelectedTheme()
                    }
                    // Locale store is hot-reloaded by core — reload picks
                    // up any new social-network labels / locale strings.
                    self?.viewModel?.invalidateAll()
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

        /// Relays an opaque `vauchi://` URI to core as `LinkOpened`. Core owns
        /// the destination (contact detail, exchange consent, device-link join,
        /// or a core-owned error). Dropped while locked — the tap has already
        /// foregrounded the app for the user to unlock.
        func openDeepLink(_ uri: String) {
            viewModel?.handleAction(.linkOpened(uri: uri))
        }
    }
#endif
