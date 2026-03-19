// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// KeyboardShortcuts.swift
// macOS keyboard shortcut definitions

import SwiftUI

/// Keyboard shortcut definitions for the Vauchi macOS app.
///
/// Provides desktop-native keyboard shortcuts that don't exist on iOS:
/// - Cmd+E: Start exchange
/// - Cmd+1/2/3: Navigate tabs
/// - Cmd+,: Settings (handled by SwiftUI Settings scene)
enum VauchiShortcuts {
    /// Start a new contact exchange.
    static let exchange = KeyboardShortcut("e", modifiers: .command)

    /// Navigate to contacts tab.
    static let contacts = KeyboardShortcut("1", modifiers: .command)

    /// Navigate to groups tab.
    static let groups = KeyboardShortcut("2", modifiers: .command)

    /// Navigate to card editor.
    static let editCard = KeyboardShortcut("3", modifiers: .command)

    /// Search contacts.
    static let search = KeyboardShortcut("f", modifiers: .command)
}

/// SwiftUI Commands that wire VauchiShortcuts to navigation via NotificationCenter.
struct VauchiMenuCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Exchange Contact Card") {
                NotificationCenter.default.post(name: .vauchiMenuExchange, object: nil)
            }
            .keyboardShortcut(VauchiShortcuts.exchange)
        }

        CommandGroup(replacing: .toolbar) {
            Button("Contacts") {
                NotificationCenter.default.post(name: .vauchiMenuContacts, object: nil)
            }
            .keyboardShortcut(VauchiShortcuts.contacts)

            Button("Groups") {
                NotificationCenter.default.post(name: .vauchiMenuGroups, object: nil)
            }
            .keyboardShortcut(VauchiShortcuts.groups)

            Button("My Card") {
                NotificationCenter.default.post(name: .vauchiMenuMyCard, object: nil)
            }
            .keyboardShortcut(VauchiShortcuts.editCard)
        }
    }
}
