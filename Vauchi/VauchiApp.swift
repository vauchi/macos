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
                    // The window's content container comes from SwiftUI's
                    // hosting view, above anything PresentationHostView
                    // builds, and `testAccessibilityAudit` flags it for
                    // having no description at all. An identifier is the
                    // one thing that reaches it from here, and it is not
                    // user-facing copy — VoiceOver never speaks it, so
                    // this stays clear of the Core-prepared accessibility
                    // rule while giving the container an identity.
                    .accessibilityIdentifier("vauchi.window.content")
            #else
                PlaceholderContentView()
            #endif
        }
        .defaultSize(width: 960, height: 680)
    }
}
