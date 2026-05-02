// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// VauchiApp.swift
// macOS native desktop app entry point

import Combine
import CoreUIModels
import SwiftUI
import UserNotifications

private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

@main
struct VauchiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    #if canImport(VauchiPlatform)
        @StateObject private var appState = AppState()
        @StateObject private var themeService = ThemeService.shared
    #endif

    var body: some Scene {
        WindowGroup {
            #if canImport(VauchiPlatform)
                ContentView()
                    .environmentObject(appState)
                    .environmentObject(themeService)
                    .onReceive(timer) { _ in
                        appState.pollNotifications()
                    }
            #else
                PlaceholderContentView()
            #endif
        }
        .defaultSize(width: 400, height: 700)
        .commands {
            VauchiMenuCommands()
        }

        #if os(macOS) && canImport(VauchiPlatform)
            Settings {
                SettingsWindowView()
                    .environmentObject(appState)
                    .environmentObject(themeService)
                    .frame(minWidth: 400, minHeight: 500)
            }
        #endif
    }
}

/// App delegate for macOS-specific lifecycle hooks (menu bar, system tray).
class AppDelegate: NSObject, NSApplicationDelegate {
    let systemTrayManager = SystemTrayManager()
    let menuBarManager = MenuBarManager()

    func applicationDidFinishLaunching(_: Notification) {
        ScreenCaptureProtection.enable()
        systemTrayManager.setup()
        menuBarManager.setupMenuBar()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        // Keep running in menu bar when window is closed
        false
    }

    func applicationWillTerminate(_: Notification) {
        systemTrayManager.teardown()
    }

    func applicationDidResignActive(_: Notification) {
        // Trigger auto-lock if enabled when app loses focus (C1)
        #if canImport(VauchiPlatform)
            // Use NSApp to find our AppState which is @StateObject in @main VauchiApp
            // But since AppState is a @StateObject in a struct, we should ideally access it via a notification
            // or a shared singleton if AppState was one.
            // Given the current structure, let's post a notification that AppState can listen to.
            NotificationCenter.default.post(name: .vauchiAppResignedActive, object: nil)
        #endif
    }

    func applicationDidBecomeActive(_: Notification) {
        // Re-fetch the current screen from core on background→foreground.
        // Listener events cover most state changes, but a missed event
        // would leave the UI stale until the next user action.
        #if canImport(VauchiPlatform)
            NotificationCenter.default.post(name: .vauchiAppBecameActive, object: nil)
        #endif
    }
}

#if canImport(VauchiPlatform)
    extension Notification.Name {
        static let vauchiAppResignedActive = Notification.Name("vauchiAppResignedActive")
        static let vauchiAppBecameActive = Notification.Name("vauchiAppBecameActive")
    }
#endif

// MARK: - With VauchiPlatform bindings

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
                    // Reinitialize viewModel to pick up the new identity
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
                    // Refresh theme catalog if themes were updated
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
                    // User cancelled — stay on lock screen
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

    struct ContentView: View {
        @EnvironmentObject var appState: AppState

        var body: some View {
            Group {
                if appState.isAuthenticationRequired {
                    LockScreenView(onUnlock: { appState.authenticateAndRetry() })
                } else if let error = appState.error {
                    ErrorView(message: error)
                } else if let viewModel = appState.viewModel {
                    AppContentView(viewModel: viewModel)
                } else {
                    ProgressView(LocalizationService.shared.t("app.initializing"))
                }
            }
        }
    }

    struct AppContentView: View {
        @ObservedObject var viewModel: AppViewModel

        var body: some View {
            ZStack(alignment: .top) {
                NavigationSplitView {
                    SidebarView(viewModel: viewModel)
                } detail: {
                    if let screen = viewModel.currentScreen {
                        ScreenRendererView(
                            screen: screen,
                            onAction: { action in
                                viewModel.handleAction(action)
                            },
                            onQrScanned: { data in
                                viewModel.handleQrScanned(data: data)
                            }
                        )
                    } else {
                        LoadingView()
                    }
                }

                // Toast overlay for ActionResult.showToast (positioned above content)
                if let message = viewModel.toastMessage {
                    ToastOverlayView(
                        message: message,
                        undoActionId: viewModel.toastUndoActionId,
                        onAction: { action in viewModel.handleAction(action) },
                        onDismiss: {
                            withAnimation {
                                viewModel.toastMessage = nil
                                viewModel.toastUndoActionId = nil
                            }
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                    .padding(.horizontal, 24)
                    .zIndex(100)
                }
            }
            .alert(item: $viewModel.alertMessage) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text(LocalizationService.shared.t("action.ok")))
                )
            }
            .onChange(of: viewModel.currentScreen?.screenId) { newId in
                syncQrFrameTimer(for: newId)
            }
            .onAppear {
                syncQrFrameTimer(for: viewModel.currentScreen?.screenId)
            }
            .onDisappear {
                viewModel.stopQrFrameTimer()
            }
            .sheet(isPresented: $viewModel.showDeviceLinkSheet) {
                DeviceLinkSheet(viewModel: viewModel)
            }
            .onReceive(NotificationCenter.default.publisher(for: .vauchiMenuExchange)) { _ in
                viewModel.navigateTo(screenJson: "\"Exchange\"")
            }
            .onReceive(NotificationCenter.default.publisher(for: .vauchiMenuContacts)) { _ in
                viewModel.navigateTo(screenJson: "\"Contacts\"")
            }
            .onReceive(NotificationCenter.default.publisher(for: .vauchiMenuGroups)) { _ in
                viewModel.navigateTo(screenJson: "\"Groups\"")
            }
            .onReceive(NotificationCenter.default.publisher(for: .vauchiMenuMyCard)) { _ in
                viewModel.navigateTo(screenJson: "\"MyInfo\"")
            }
            .onReceive(NotificationCenter.default.publisher(for: .vauchiMenuMore)) { _ in
                viewModel.navigateTo(screenJson: "\"More\"")
            }
            .sheet(isPresented: $viewModel.showImportBackupSheet) {
                ImportBackupSheet()
                    .environmentObject(viewModel)
            }
            .onReceive(NotificationCenter.default.publisher(for: .vauchiMenuImportContacts)) { _ in
                viewModel.showImportContactsSheet = true
            }
            .sheet(isPresented: $viewModel.showImportContactsSheet) {
                ImportContactsSheet()
                    .environmentObject(viewModel)
            }
        }

        /// Start the animated-QR timer while the ShowQr screen is visible; stop
        /// it everywhere else. Cheap to call unconditionally — both methods are
        /// idempotent.
        private func syncQrFrameTimer(for screenId: String?) {
            if screenId == "exchange_show_qr" {
                viewModel.startQrFrameTimer()
            } else {
                viewModel.stopQrFrameTimer()
            }
        }
    }

    /// Sidebar listing available navigation screens from core.
    struct SidebarView: View {
        @ObservedObject var viewModel: AppViewModel
        @State private var sidebarSelection: String?

        var body: some View {
            List(selection: $sidebarSelection) {
                ForEach(viewModel.sidebarItems, id: \.id) { tab in
                    Label(
                        tab.label,
                        systemImage: sidebarIcon(forScreenId: tab.id)
                    )
                    .tag(AppViewModel.appScreenName(fromScreenId: tab.id))
                }
            }
            .navigationTitle(LocalizationService.shared.t("app.name"))
            .onChange(of: sidebarSelection) { newValue in
                guard let screen = newValue,
                      screen != viewModel.selectedScreen
                else { return }
                viewModel.navigateTo(screenJson: "\"\(screen)\"")
            }
            .onChange(of: viewModel.selectedScreen) { newValue in
                sidebarSelection = newValue
            }
            .onAppear {
                sidebarSelection = viewModel.selectedScreen
            }
        }

        /// macOS contributes the preferred SF Symbol (prefer filled
        /// variants) for each top-level sidebar entry. Labels + the
        /// entry set itself are core-owned via
        /// `AppEngine::sidebar_items(locale)`; see §6 of the
        /// pure-renderer audit for rationale.
        private func sidebarIcon(forScreenId id: String) -> String {
            switch id {
            case "my_info": "person.crop.rectangle.fill"
            case "contacts": "person.2.fill"
            case "exchange": "qrcode"
            case "groups": "rectangle.3.group.fill"
            case "settings": "gearshape.fill"
            case "recovery": "key.horizontal.fill"
            case "device_management": "laptopcomputer"
            case "backup": "externaldrive.fill"
            case "privacy": "hand.raised.fill"
            case "support": "bubble.left.and.bubble.right.fill"
            case "help": "questionmark.circle.fill"
            case "activity_log": "list.bullet.rectangle.fill"
            case "sync": "arrow.triangle.2.circlepath"
            case "more": "ellipsis.circle.fill"
            case "onboarding": "wand.and.stars"
            default: "square"
            }
        }
    }

    struct ErrorView: View {
        let message: String

        @Environment(\.designTokens) private var tokens

        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)

                Text(LocalizationService.shared.t("app.failed_to_start"))
                    .font(.title2.bold())

                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(CGFloat(tokens.spacing.xl))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    struct LoadingView: View {
        var body: some View {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)

                Text(LocalizationService.shared.t("app.loading"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
#endif

// MARK: - Without VauchiPlatform bindings

#if !canImport(VauchiPlatform)
    struct PlaceholderContentView: View {
        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.rectangle.stack")
                    .font(.system(size: 48))
                    .foregroundColor(.cyan)

                Text("Vauchi")
                    .font(.largeTitle.bold())

                Text("Privacy-focused contact cards")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("VauchiPlatform bindings not available")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Placeholder ViewModel for tests when VauchiPlatform is not available.
    class PlaceholderViewModel: ObservableObject {
        @Published var currentScreen: ScreenModel?

        func handleAction(_: UserAction) {
            // No-op: requires VauchiPlatform bindings
        }
    }
#endif
