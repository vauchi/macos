// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// MenuBarManager.swift
// macOS menu bar integration

import AppKit

/// Manages the macOS menu bar for the Vauchi app.
///
/// Responsibilities:
/// - Custom menu items (Exchange, Contacts, Settings)
/// - Keyboard shortcuts integration
/// - Dynamic menu updates based on app state
class MenuBarManager {
    private var exchangeMenuItem: NSMenuItem?
    private var contactsMenuItem: NSMenuItem?
    private var settingsMenuItem: NSMenuItem?

    /// Sets up the application menu bar.
    func setupMenuBar() {
        guard let mainMenu = NSApp.mainMenu else { return }

        // File menu — Exchange
        let fileMenu = NSMenu(title: "File")
        let exchangeItem = NSMenuItem(
            title: "Exchange Contact Card",
            action: #selector(exchangeAction(_:)),
            keyEquivalent: "e"
        )
        exchangeItem.keyEquivalentModifierMask = .command
        exchangeItem.target = self
        fileMenu.addItem(exchangeItem)
        exchangeMenuItem = exchangeItem

        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        fileMenuItem.submenu = fileMenu

        // View menu — Navigation
        let viewMenu = NSMenu(title: "View")

        let contactsItem = NSMenuItem(
            title: "Contacts",
            action: #selector(contactsAction(_:)),
            keyEquivalent: "1"
        )
        contactsItem.keyEquivalentModifierMask = .command
        contactsItem.target = self
        viewMenu.addItem(contactsItem)
        contactsMenuItem = contactsItem

        viewMenu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(settingsAction(_:)),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        viewMenu.addItem(settingsItem)
        settingsMenuItem = settingsItem

        let viewMenuItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        viewMenuItem.submenu = viewMenu

        // Insert after the app menu (index 1)
        let insertIndex = min(1, mainMenu.items.count)
        mainMenu.insertItem(fileMenuItem, at: insertIndex)
        mainMenu.insertItem(viewMenuItem, at: insertIndex + 1)
    }

    /// Updates menu item states based on current app state.
    func updateMenuState(hasIdentity: Bool) {
        exchangeMenuItem?.isEnabled = hasIdentity
        contactsMenuItem?.isEnabled = hasIdentity
    }

    // MARK: - Actions

    // Exchange/Contacts post notifications observed by AppContentView's .onReceive
    // handlers, which call viewModel.navigateTo() for navigation.

    @objc private func exchangeAction(_: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .vauchiMenuExchange, object: nil)
    }

    @objc private func contactsAction(_: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .vauchiMenuContacts, object: nil)
    }

    @objc private func settingsAction(_: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        // showSettingsWindow: is AppKit's internal selector for SwiftUI Settings scenes (macOS 13+)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let vauchiMenuExchange = Notification.Name("vauchiMenuExchange")
    static let vauchiMenuContacts = Notification.Name("vauchiMenuContacts")
    static let vauchiMenuGroups = Notification.Name("vauchiMenuGroups")
    static let vauchiMenuMyCard = Notification.Name("vauchiMenuMyCard")
}
