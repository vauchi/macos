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

        #if os(macOS)
            Settings {
                Text("Settings placeholder")
                    .frame(width: 300, height: 200)
            }
        #endif
    }
}

/// App delegate for macOS-specific lifecycle hooks (menu bar, system tray).
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        // TODO: Initialize MenuBarManager, SystemTrayManager
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        // Keep running in menu bar when window is closed
        false
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
                viewModel = AppViewModel(appEngine: repo.appEngine)
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
            if let screen = viewModel.currentScreen {
                ScreenRendererView(screen: screen, onAction: { action in
                    viewModel.handleAction(action)
                })
                .alert(item: $viewModel.alertMessage) { alert in
                    Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        dismissButton: .default(Text("OK"))
                    )
                }
            } else {
                LoadingView()
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
