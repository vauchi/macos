// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// macOS native desktop app entry point. The @main App struct is
// intentionally thin — supporting types (AppDelegate, AppState,
// ContentView, AppContentView, ErrorView, LoadingView, and
// PlaceholderContentView) live in sibling files so this entry stays
// auditable at a glance. See `_private/docs/planning/todo/2026-05-02-
// macos-humble-ui-retirement-plan.md` G3.

import SwiftUI

#if canImport(VauchiPlatform)
    import VauchiPlatform
#endif

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
            #else
                PlaceholderContentView()
            #endif
        }
        .defaultSize(width: 960, height: 680)
    }
}
