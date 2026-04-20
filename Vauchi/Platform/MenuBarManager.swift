// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// MenuBarManager.swift
// macOS menu bar integration

import AppKit
#if canImport(VauchiPlatform)
    import VauchiPlatform
#endif

/// Manages the macOS menu bar for the Vauchi app.
///
/// Responsibilities:
/// - Custom menu items (Exchange, Contacts, Settings)
/// - Keyboard shortcuts integration
/// - Dynamic menu updates based on app state
class MenuBarManager {
    private var exchangeMenuItem: NSMenuItem?
    private var importContactsMenuItem: NSMenuItem?
    private var myCardMenuItem: NSMenuItem?
    private var contactsMenuItem: NSMenuItem?
    private var groupsMenuItem: NSMenuItem?
    private var moreMenuItem: NSMenuItem?
    private var settingsMenuItem: NSMenuItem?

    /// Sets up the application menu bar.
    func setupMenuBar() {
        guard let mainMenu = NSApp.mainMenu else { return }
        let fileMenuItem = buildFileMenu()
        let viewMenuItem = buildViewMenu()
        let insertIndex = min(1, mainMenu.items.count)
        mainMenu.insertItem(fileMenuItem, at: insertIndex)
        mainMenu.insertItem(viewMenuItem, at: insertIndex + 1)
    }

    private func buildFileMenu() -> NSMenuItem {
        let menu = NSMenu(title: t("menu.file"))
        exchangeMenuItem = addMenuItem(
            to: menu, title: t("menu.exchange_card"),
            action: #selector(exchangeAction(_:)), key: "e"
        )
        importContactsMenuItem = addMenuItem(
            to: menu, title: t("menu.import_contacts"),
            action: #selector(importContactsAction(_:)), key: "i"
        )
        let menuItem = NSMenuItem(title: t("menu.file"), action: nil, keyEquivalent: "")
        menuItem.submenu = menu
        return menuItem
    }

    private func buildViewMenu() -> NSMenuItem {
        let menu = NSMenu(title: t("menu.view"))
        myCardMenuItem = addMenuItem(to: menu, title: t("nav.myCard"), action: #selector(myCardAction(_:)), key: "1")
        contactsMenuItem = addMenuItem(to: menu, title: t("nav.contacts"), action: #selector(contactsAction(_:)), key: "2")
        groupsMenuItem = addMenuItem(to: menu, title: t("nav.groups"), action: #selector(groupsAction(_:)), key: "3")
        moreMenuItem = addMenuItem(to: menu, title: t("nav.more"), action: #selector(moreAction(_:)), key: "4")
        menu.addItem(NSMenuItem.separator())
        settingsMenuItem = addMenuItem(to: menu, title: t("menu.settings_ellipsis"), action: #selector(settingsAction(_:)), key: ",")
        let menuItem = NSMenuItem(title: t("menu.view"), action: nil, keyEquivalent: "")
        menuItem.submenu = menu
        return menuItem
    }

    /// Look up a localized string. Falls back to the raw key when the
    /// VauchiPlatform bindings are not available (unit-test builds).
    private func t(_ key: String) -> String {
        #if canImport(VauchiPlatform)
            return LocalizationService.shared.t(key)
        #else
            return key
        #endif
    }

    @discardableResult
    private func addMenuItem(to menu: NSMenu, title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = .command
        item.target = self
        menu.addItem(item)
        return item
    }

    /// Updates menu item states based on current app state.
    func updateMenuState(hasIdentity: Bool) {
        exchangeMenuItem?.isEnabled = hasIdentity
        importContactsMenuItem?.isEnabled = hasIdentity
        myCardMenuItem?.isEnabled = hasIdentity
        contactsMenuItem?.isEnabled = hasIdentity
        groupsMenuItem?.isEnabled = hasIdentity
        moreMenuItem?.isEnabled = hasIdentity
    }

    // MARK: - Actions

    // Menu actions post notifications observed by AppContentView's .onReceive
    // handlers, which call viewModel.navigateTo() for navigation.

    @objc private func exchangeAction(_: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .vauchiMenuExchange, object: nil)
    }

    @objc private func importContactsAction(_: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .vauchiMenuImportContacts, object: nil)
    }

    @objc private func myCardAction(_: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .vauchiMenuMyCard, object: nil)
    }

    @objc private func contactsAction(_: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .vauchiMenuContacts, object: nil)
    }

    @objc private func groupsAction(_: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .vauchiMenuGroups, object: nil)
    }

    @objc private func moreAction(_: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .vauchiMenuMore, object: nil)
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
    static let vauchiMenuImportContacts = Notification.Name("vauchiMenuImportContacts")
    static let vauchiMenuContacts = Notification.Name("vauchiMenuContacts")
    static let vauchiMenuGroups = Notification.Name("vauchiMenuGroups")
    static let vauchiMenuMyCard = Notification.Name("vauchiMenuMyCard")
    static let vauchiMenuMore = Notification.Name("vauchiMenuMore")
}
