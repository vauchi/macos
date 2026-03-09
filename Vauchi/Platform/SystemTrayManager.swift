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
///
/// TODO: Implement status bar item when core sync engine is connected.
class SystemTrayManager {
    private var statusItem: NSStatusItem?

    /// Creates and configures the status bar item.
    func setup() {
        // TODO: Create NSStatusItem with vauchi icon
        // - Click: open/focus main window
        // - Right-click: context menu (Exchange, Quit)
        // - Badge: pending exchange count
    }

    /// Updates the status bar icon badge.
    func updateBadge(count: Int) {
        // TODO: Show notification badge on status bar icon
        _ = count
    }

    /// Removes the status bar item.
    func teardown() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }
}
