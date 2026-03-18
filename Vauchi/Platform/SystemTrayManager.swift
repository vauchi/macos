// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// SystemTrayManager.swift
// macOS status bar (system tray) integration

import AppKit

/// Manages the macOS status bar item for the Vauchi app.
///
/// Provides a persistent status bar icon for:
/// - Quick access to exchange contact cards
/// - Notification indicators for pending exchanges
/// - Background sync status
class SystemTrayManager {
    private var statusItem: NSStatusItem?

    /// Creates and configures the status bar item.
    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "person.crop.circle",
                accessibilityDescription: "Vauchi"
            )
            button.action = #selector(statusItemClicked(_:))
            button.target = self
        }

        statusItem = item
    }

    /// Updates the status bar icon badge.
    func updateBadge(count: Int) {
        guard let button = statusItem?.button else { return }
        if count > 0 {
            button.title = "\(count)"
        } else {
            button.title = ""
        }
    }

    /// Removes the status bar item.
    func teardown() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    /// Brings the app window to front and activates it.
    @objc private func statusItemClicked(_: Any?) {
        bringAppToFront()
    }

    func bringAppToFront() {
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        // Find the main app window (not Settings or panels)
        if let window = NSApp.windows.first(where: {
            $0.canBecomeMain && $0.className.contains("NSWindow")
        }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
