// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// ScreenCaptureProtection.swift
// Marks every NSWindow with `sharingType = .none` so screen-recording
// tools (QuickTime, OBS, screencapture(1), AirPlay mirroring, Universal
// Control mirroring, AppleScript scriptable apps) can't capture the
// window contents. Mirrors the iOS / Android pattern (FLAG_SECURE,
// UIScreen.isCaptured overlay) for the macOS frontend.
//
// Disabled in DEBUG builds — XCUITest snapshot tooling needs to read
// window contents for golden-image comparison.

import AppKit
import Foundation

enum ScreenCaptureProtection {
    /// Apply `sharingType = .none` to every existing window and
    /// install an observer that re-applies it as new windows appear.
    /// Idempotent — calling twice is harmless.
    static func enable() {
        #if DEBUG
            NSLog("[Vauchi] ScreenCaptureProtection: skipped (DEBUG build)")
        #else
            applyToAllWindows()
            NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let window = notification.object as? NSWindow {
                    window.sharingType = .none
                }
            }
            NotificationCenter.default.addObserver(
                forName: NSWindow.didUpdateNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let window = notification.object as? NSWindow,
                   window.sharingType != .none
                {
                    window.sharingType = .none
                }
            }
        #endif
    }

    private static func applyToAllWindows() {
        for window in NSApp.windows {
            window.sharingType = .none
        }
    }
}
