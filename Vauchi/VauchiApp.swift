// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// VauchiApp.swift
// macOS native desktop app entry point

import Combine
import SwiftUI
import UserNotifications

private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

@main
struct VauchiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    #if canImport(VauchiPlatform)
        @StateObject private var appState = AppState()
    #endif

    var body: some Scene {
        WindowGroup {
            #if canImport(VauchiPlatform)
                ContentView()
                    .environmentObject(appState)
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
}

#if canImport(VauchiPlatform)
    extension Notification.Name {
        static let vauchiAppResignedActive = Notification.Name("vauchiAppResignedActive")
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
                        reason: "Unlock Vauchi to access your contacts"
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
                    ProgressView("Initializing...")
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
                        ScreenRendererView(screen: screen, onAction: { action in
                            viewModel.handleAction(action)
                        })
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
                    dismissButton: .default(Text("OK"))
                )
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
        }
    }

    /// Sidebar listing available navigation screens from core.
    struct SidebarView: View {
        @ObservedObject var viewModel: AppViewModel
        @State private var sidebarSelection: String?

        var body: some View {
            List(selection: $sidebarSelection) {
                ForEach(viewModel.availableScreens, id: \.self) { screen in
                    Label(displayName(for: screen), systemImage: icon(for: screen))
                        .tag(screen)
                }
            }
            .navigationTitle("Vauchi")
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

        private func displayName(for screen: String) -> String {
            switch screen {
            case "MyInfo": "My Card"
            case "Contacts": "Contacts"
            case "Exchange": "Exchange"
            case "Groups": "Groups"
            case "More": "More"
            case "Onboarding": "Setup"
            default: screen
            }
        }

        private func icon(for screen: String) -> String {
            switch screen {
            case "MyInfo": "person.crop.rectangle.fill"
            case "Contacts": "person.2.fill"
            case "Exchange": "qrcode"
            case "Groups": "rectangle.3.group.fill"
            case "More": "ellipsis.circle.fill"
            case "Onboarding": "wand.and.stars"
            default: "square"
            }
        }
    }

    struct ErrorView: View {
        let message: String

        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)

                Text("Failed to Start")
                    .font(.title2.bold())

                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    struct LoadingView: View {
        var body: some View {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)

                Text("Loading...")
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
