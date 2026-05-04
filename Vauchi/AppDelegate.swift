// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// AppDelegate.swift
// macOS-specific application lifecycle hooks (menu bar, system tray,
// auto-lock notifications). Posts notifications that `AppState`
// listens for so the app does not need a shared singleton.

import AppKit
import Foundation

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
        // Trigger auto-lock if enabled when app loses focus (C1).
        // Posted via NotificationCenter rather than a shared singleton
        // so AppState (a @StateObject in @main VauchiApp) can subscribe.
        #if canImport(VauchiPlatform)
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
