// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// VauchiApp.swift
// macOS native desktop app entry point

import SwiftUI

@main
struct VauchiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
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

struct ContentView: View {
    // TODO: Replace with actual OnboardingViewModel when UniFFI bindings are available
    @StateObject private var viewModel = PlaceholderViewModel()

    var body: some View {
        if let screen = viewModel.currentScreen {
            ScreenRendererView(screen: screen, onAction: { action in
                viewModel.handleAction(action)
            })
        } else {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.rectangle.stack")
                    .font(.system(size: 48))
                    .foregroundColor(.cyan)

                Text("Vauchi")
                    .font(.largeTitle.bold())

                Text("Privacy-focused contact cards")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Placeholder ViewModel until UniFFI MobileOnboardingWorkflow is available.
///
/// Will be replaced by `OnboardingViewModel` (shared with iOS) once the
/// published VauchiMobile bindings contain MobileOnboardingWorkflow.
class PlaceholderViewModel: ObservableObject {
    @Published var currentScreen: ScreenModel?

    func handleAction(_: UserAction) {
        // TODO: Forward to WorkflowEngine via UniFFI
    }
}
