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
/// - Cmd+N: New contact card
/// - Cmd+1/2/3: Navigate tabs
/// - Cmd+,: Settings (handled by SwiftUI Settings scene)
///
/// TODO: Wire shortcuts to core navigation actions.
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
