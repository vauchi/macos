// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// KeyboardShortcuts.swift
// macOS keyboard shortcut definitions

import SwiftUI
#if canImport(VauchiPlatform)
    import VauchiPlatform
#endif

/// Keyboard shortcut definitions for the Vauchi macOS app.
///
/// Provides desktop-native keyboard shortcuts that don't exist on iOS:
/// - Cmd+E: Start exchange
/// - Cmd+1/2/3/4: Navigate sidebar tabs (My Card, Contacts, Groups, More)
/// - Cmd+,: Settings (handled by SwiftUI Settings scene)
enum VauchiShortcuts {
    /// Start a new contact exchange.
    static let exchange = KeyboardShortcut("e", modifiers: .command)

    /// Navigate to My Card.
    static let myCard = KeyboardShortcut("1", modifiers: .command)

    /// Navigate to contacts tab.
    static let contacts = KeyboardShortcut("2", modifiers: .command)

    /// Navigate to groups tab.
    static let groups = KeyboardShortcut("3", modifiers: .command)

    /// Navigate to More screen.
    static let more = KeyboardShortcut("4", modifiers: .command)

    /// Search contacts.
    static let search = KeyboardShortcut("f", modifiers: .command)
}

/// SwiftUI Commands that wire VauchiShortcuts to navigation via NotificationCenter.
struct VauchiMenuCommands: Commands {
    /// Localized string lookup with a key-fallback when VauchiPlatform is
    /// unavailable (unit-test builds without the bindings).
    private func t(_ key: String) -> String {
        #if canImport(VauchiPlatform)
            return LocalizationService.shared.t(key)
        #else
            return key
        #endif
    }

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button(t("menu.exchange_card")) {
                NotificationCenter.default.post(name: .vauchiMenuExchange, object: nil)
            }
            .keyboardShortcut(VauchiShortcuts.exchange)
        }

        CommandGroup(replacing: .toolbar) {
            Button(t("nav.myCard")) {
                NotificationCenter.default.post(name: .vauchiMenuMyCard, object: nil)
            }
            .keyboardShortcut(VauchiShortcuts.myCard)

            Button(t("nav.contacts")) {
                NotificationCenter.default.post(name: .vauchiMenuContacts, object: nil)
            }
            .keyboardShortcut(VauchiShortcuts.contacts)

            Button(t("nav.groups")) {
                NotificationCenter.default.post(name: .vauchiMenuGroups, object: nil)
            }
            .keyboardShortcut(VauchiShortcuts.groups)

            Button(t("nav.more")) {
                NotificationCenter.default.post(name: .vauchiMenuMore, object: nil)
            }
            .keyboardShortcut(VauchiShortcuts.more)
        }
    }
}
