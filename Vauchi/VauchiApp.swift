// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// VauchiApp.swift
// macOS native desktop app entry point

import SwiftUI

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
}

// MARK: - With VauchiPlatform bindings

#if canImport(VauchiPlatform)
    import VauchiPlatform

    /// Top-level app state that owns VauchiRepository and AppViewModel.
    @MainActor
    class AppState: ObservableObject {
        @Published var viewModel: AppViewModel?
        @Published var error: String?

        private var repository: VauchiRepository?

        init() {
            do {
                let repo = try VauchiRepository()
                repository = repo
                let appViewModel = AppViewModel(appEngine: repo.appEngine)
                appViewModel.vauchi = repo.vauchi
                viewModel = appViewModel
            } catch {
                self.error = error.localizedDescription
                print("VauchiApp: failed to initialize: \(error)")
            }
        }
    }

    struct ContentView: View {
        @EnvironmentObject var appState: AppState

        var body: some View {
            Group {
                if let error = appState.error {
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
