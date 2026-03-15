// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// ScreenSnapshotTests.swift
// Full-screen visual regression tests for macOS.
// Based on: features/identity.feature, features/contact_exchange.feature, features/settings.feature
//
// macOS adaptation of ios/VauchiSnapshotTests/VisualRegressionTests.swift.
// Uses ScreenRendererView + ScreenModel instead of per-view snapshots,
// since macOS app renders all screens through core's UI contract.

import SnapshotTesting
import SwiftUI
@testable import Vauchi
import XCTest

/// Visual regression tests for complete screens rendered via ScreenRendererView.
///
/// Tests core-driven screens at desktop window size (480×700 pt).
/// Each test constructs a ScreenModel matching what core would produce,
/// then renders it through the same ScreenRendererView used in production.
@MainActor
final class ScreenSnapshotTests: XCTestCase {
    /// Whether to record new baselines. Always false in CI.
    private var isRecording: Bool {
        false
    }

    // MARK: - Onboarding Screens

    func testWelcomeScreen() {
        let screen = makeScreen(
            screenId: "welcome",
            title: "Welcome to Vauchi",
            subtitle: "Privacy-first contact cards. Exchanged in person, updated automatically.",
            components: [
                .infoPanel(InfoPanelComponent(
                    id: "features",
                    icon: nil,
                    title: "How It Works",
                    items: [
                        InfoItem(
                            icon: "qrcode",
                            title: "Exchange In Person",
                            detail: "Scan QR codes face-to-face to share contact info."
                        ),
                        InfoItem(
                            icon: "lock.shield",
                            title: "End-to-End Encrypted",
                            detail: "Only you and your contacts can read your data."
                        ),
                        InfoItem(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Auto-Update",
                            detail: "Changes are delivered automatically to all contacts."
                        ),
                    ]
                )),
            ],
            actions: [
                ScreenAction(id: "get_started", label: "Get Started", style: .primary, enabled: true),
                ScreenAction(id: "restore", label: "Restore from Backup", style: .secondary, enabled: true),
            ]
        )
        assertScreenSnapshot(of: screen, record: isRecording)
    }

    func testCreateIdentityScreen() {
        let screen = makeScreen(
            screenId: "create_identity",
            title: "Create Your Identity",
            subtitle: "Choose a display name. This is what your contacts will see.",
            components: [
                .textInput(TextInputComponent(
                    id: "display_name",
                    label: "Display Name",
                    value: "",
                    placeholder: "Enter your name",
                    maxLength: 50,
                    validationError: nil,
                    inputType: .text
                )),
            ],
            actions: [
                ScreenAction(id: "continue", label: "Continue", style: .primary, enabled: false),
                ScreenAction(id: "back", label: "Back", style: .secondary, enabled: true),
            ],
            progress: Progress(currentStep: 1, totalSteps: 4, label: "Step 1 of 4")
        )
        assertScreenSnapshot(of: screen, record: isRecording)
    }

    func testAddFieldsScreen() {
        let screen = makeScreen(
            screenId: "add_fields",
            title: "Add Contact Fields",
            subtitle: "Add the information you want to share with contacts.",
            components: [
                .textInput(TextInputComponent(
                    id: "email",
                    label: "Email",
                    value: "",
                    placeholder: "you@example.com",
                    maxLength: nil,
                    validationError: nil,
                    inputType: .email
                )),
                .textInput(TextInputComponent(
                    id: "phone",
                    label: "Phone",
                    value: "",
                    placeholder: "+41...",
                    maxLength: nil,
                    validationError: nil,
                    inputType: .phone
                )),
            ],
            actions: [
                ScreenAction(id: "continue", label: "Continue", style: .primary, enabled: true),
                ScreenAction(id: "skip", label: "Skip for Now", style: .secondary, enabled: true),
                ScreenAction(id: "back", label: "Back", style: .secondary, enabled: true),
            ],
            progress: Progress(currentStep: 2, totalSteps: 4, label: "Step 2 of 4")
        )
        assertScreenSnapshot(of: screen, record: isRecording)
    }

    // MARK: - Main App Screens

    func testHomeScreenEmpty() {
        let screen = makeScreen(
            screenId: "home",
            title: "Your Card",
            subtitle: "Alice",
            components: [
                .cardPreview(CardPreviewComponent(
                    name: "Alice",
                    fields: [],
                    groupViews: [],
                    selectedGroup: nil
                )),
            ],
            actions: [
                ScreenAction(id: "edit_card", label: "Edit Card", style: .secondary, enabled: true),
            ]
        )
        assertScreenSnapshot(of: screen, record: isRecording)
    }

    func testHomeScreenWithFields() {
        let screen = makeScreen(
            screenId: "home",
            title: "Your Card",
            subtitle: "Alice",
            components: [
                .cardPreview(CardPreviewComponent(
                    name: "Alice",
                    fields: [
                        FieldDisplay(
                            id: "f1",
                            fieldType: "email",
                            label: "Personal Email",
                            value: "alice@example.com",
                            visibility: .shown
                        ),
                        FieldDisplay(
                            id: "f2",
                            fieldType: "phone",
                            label: "Mobile",
                            value: "+41 79 123 45 67",
                            visibility: .shown
                        ),
                        FieldDisplay(
                            id: "f3",
                            fieldType: "website",
                            label: "Website",
                            value: "https://alice.example.com",
                            visibility: .shown
                        ),
                    ],
                    groupViews: [],
                    selectedGroup: nil
                )),
            ],
            actions: [
                ScreenAction(id: "edit_card", label: "Edit Card", style: .secondary, enabled: true),
            ]
        )
        assertScreenSnapshot(of: screen, record: isRecording)
    }

    func testContactsScreenEmpty() {
        let screen = makeScreen(
            screenId: "contacts",
            title: "Contacts",
            subtitle: "No contacts yet. Exchange cards in person to get started.",
            components: [
                .contactList(ContactListComponent(
                    id: "contact_list",
                    contacts: [],
                    searchable: false
                )),
            ],
            actions: [
                ScreenAction(id: "start_exchange", label: "Exchange Cards", style: .primary, enabled: true),
            ]
        )
        assertScreenSnapshot(of: screen, record: isRecording)
    }

    func testContactsScreenWithContacts() {
        let screen = makeScreen(
            screenId: "contacts",
            title: "Contacts",
            components: [
                .contactList(ContactListComponent(
                    id: "contact_list",
                    contacts: [
                        ContactItem(
                            id: "c1",
                            name: "Bob",
                            subtitle: "Last updated 2h ago",
                            avatarInitials: "B",
                            status: nil
                        ),
                        ContactItem(
                            id: "c2",
                            name: "Charlie",
                            subtitle: "3 fields shared",
                            avatarInitials: "C",
                            status: nil
                        ),
                        ContactItem(
                            id: "c3",
                            name: "Diana",
                            subtitle: "Pending verification",
                            avatarInitials: "D",
                            status: "pending"
                        ),
                    ],
                    searchable: true
                )),
            ],
            actions: [
                ScreenAction(id: "start_exchange", label: "Exchange Cards", style: .primary, enabled: true),
            ]
        )
        assertScreenSnapshot(of: screen, record: isRecording)
    }

    // MARK: - Exchange Screens

    func testExchangeShowQrScreen() {
        let screen = makeScreen(
            screenId: "exchange_show_qr",
            title: "Show Your QR Code",
            subtitle: "Let the other person scan this code with their Vauchi app.",
            components: [
                .qrCode(QrCodeComponent(
                    id: "exchange_qr",
                    data: "vauchi://exchange?data=mock_exchange_data_for_snapshot",
                    mode: .display,
                    label: "Exchange QR Code"
                )),
                .text(TextComponent(id: "hint", content: "Hold your device steady so they can scan.", style: .caption)),
            ],
            actions: [
                ScreenAction(id: "scan_theirs", label: "Scan Their Code", style: .primary, enabled: true),
                ScreenAction(id: "cancel", label: "Cancel", style: .secondary, enabled: true),
            ]
        )
        assertScreenSnapshot(of: screen, record: isRecording)
    }

    func testExchangeSuccessScreen() {
        let screen = makeScreen(
            screenId: "exchange_success",
            title: "Exchange Complete",
            components: [
                .statusIndicator(StatusIndicatorComponent(
                    id: "status",
                    icon: "checkmark.circle.fill",
                    title: "Card Exchanged",
                    detail: "You and Bob have exchanged contact cards.",
                    status: .success
                )),
            ],
            actions: [
                ScreenAction(id: "view_contact", label: "View Contact", style: .primary, enabled: true),
                ScreenAction(id: "done", label: "Done", style: .secondary, enabled: true),
            ]
        )
        assertScreenSnapshot(of: screen, record: isRecording)
    }

    // MARK: - Settings Screens

    func testSettingsScreen() {
        let screen = makeScreen(
            screenId: "settings",
            title: "Settings",
            components: [
                .settingsGroup(SettingsGroupComponent(
                    id: "account",
                    label: "Account",
                    items: [
                        SettingsItem(id: "name", label: "Display Name", kind: .value(value: "Alice")),
                        SettingsItem(id: "public_id", label: "Public ID", kind: .value(value: "abc123def456")),
                    ]
                )),
                .settingsGroup(SettingsGroupComponent(
                    id: "security",
                    label: "Security",
                    items: [
                        SettingsItem(id: "biometric", label: "Require Touch ID", kind: .toggle(enabled: true)),
                        SettingsItem(id: "backup", label: "Export Backup", kind: .link(detail: nil)),
                    ]
                )),
                .settingsGroup(SettingsGroupComponent(
                    id: "about",
                    label: "About",
                    items: [
                        SettingsItem(id: "version", label: "Version", kind: .value(value: "0.1.0 (1)")),
                        SettingsItem(id: "core_version", label: "Core Version", kind: .value(value: "0.3.0")),
                        SettingsItem(id: "help", label: "Help & Support", kind: .link(detail: nil)),
                    ]
                )),
                .settingsGroup(SettingsGroupComponent(
                    id: "danger",
                    label: "Danger Zone",
                    items: [
                        SettingsItem(id: "wipe", label: "Delete All Data", kind: .destructive(label: "Delete")),
                    ]
                )),
            ]
        )
        assertScreenSnapshot(of: screen, record: isRecording)
    }

    // MARK: - Confirmation / Destructive Screens

    func testWipeConfirmScreen() {
        let screen = makeScreen(
            screenId: "wipe_confirm",
            title: "Delete All Data?",
            subtitle: "This will permanently delete your identity, contacts, and all data. This cannot be undone.",
            components: [
                .inlineConfirm(InlineConfirmComponent(
                    id: "wipe_confirm",
                    warning: "Type DELETE to confirm.",
                    confirmText: "Delete Everything",
                    cancelText: "Cancel",
                    destructive: true
                )),
            ]
        )
        assertScreenSnapshot(of: screen, record: isRecording)
    }

    // MARK: - Dark Mode Variants

    func testWelcomeScreenDark() {
        let screen = makeScreen(
            screenId: "welcome",
            title: "Welcome to Vauchi",
            subtitle: "Privacy-first contact cards. Exchanged in person, updated automatically.",
            components: [
                .infoPanel(InfoPanelComponent(
                    id: "features",
                    icon: nil,
                    title: "How It Works",
                    items: [
                        InfoItem(icon: "qrcode", title: "Exchange In Person", detail: "Scan QR codes face-to-face."),
                        InfoItem(icon: "lock.shield", title: "End-to-End Encrypted", detail: "Your data is private."),
                        InfoItem(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Auto-Update",
                            detail: "Changes delivered automatically."
                        ),
                    ]
                )),
            ],
            actions: [
                ScreenAction(id: "get_started", label: "Get Started", style: .primary, enabled: true),
                ScreenAction(id: "restore", label: "Restore from Backup", style: .secondary, enabled: true),
            ]
        )
        assertDarkScreenSnapshot(of: screen, record: isRecording)
    }

    func testHomeScreenDark() {
        let screen = makeScreen(
            screenId: "home",
            title: "Your Card",
            subtitle: "Alice",
            components: [
                .cardPreview(CardPreviewComponent(
                    name: "Alice",
                    fields: [
                        FieldDisplay(
                            id: "f1",
                            fieldType: "email",
                            label: "Email",
                            value: "alice@example.com",
                            visibility: .shown
                        ),
                        FieldDisplay(
                            id: "f2",
                            fieldType: "phone",
                            label: "Mobile",
                            value: "+41 79 123 45 67",
                            visibility: .shown
                        ),
                    ],
                    groupViews: [],
                    selectedGroup: nil
                )),
            ],
            actions: [
                ScreenAction(id: "edit_card", label: "Edit Card", style: .secondary, enabled: true),
            ]
        )
        assertDarkScreenSnapshot(of: screen, record: isRecording)
    }

    func testContactsScreenDark() {
        let screen = makeScreen(
            screenId: "contacts",
            title: "Contacts",
            components: [
                .contactList(ContactListComponent(
                    id: "contact_list",
                    contacts: [
                        ContactItem(
                            id: "c1",
                            name: "Bob",
                            subtitle: "Last updated 2h ago",
                            avatarInitials: "B",
                            status: nil
                        ),
                        ContactItem(id: "c2", name: "Charlie", subtitle: nil, avatarInitials: "C", status: nil),
                    ],
                    searchable: true
                )),
            ],
            actions: [
                ScreenAction(id: "start_exchange", label: "Exchange Cards", style: .primary, enabled: true),
            ]
        )
        assertDarkScreenSnapshot(of: screen, record: isRecording)
    }

    func testSettingsScreenDark() {
        let screen = makeScreen(
            screenId: "settings",
            title: "Settings",
            components: [
                .settingsGroup(SettingsGroupComponent(
                    id: "account",
                    label: "Account",
                    items: [
                        SettingsItem(id: "name", label: "Display Name", kind: .value(value: "Alice")),
                    ]
                )),
                .settingsGroup(SettingsGroupComponent(
                    id: "security",
                    label: "Security",
                    items: [
                        SettingsItem(id: "biometric", label: "Require Touch ID", kind: .toggle(enabled: true)),
                    ]
                )),
            ]
        )
        assertDarkScreenSnapshot(of: screen, record: isRecording)
    }

    func testExchangeShowQrDark() {
        let screen = makeScreen(
            screenId: "exchange_show_qr",
            title: "Show Your QR Code",
            subtitle: "Let the other person scan this code.",
            components: [
                .qrCode(QrCodeComponent(
                    id: "exchange_qr",
                    data: "vauchi://exchange?data=mock_data",
                    mode: .display,
                    label: "Exchange QR Code"
                )),
            ],
            actions: [
                ScreenAction(id: "scan_theirs", label: "Scan Their Code", style: .primary, enabled: true),
                ScreenAction(id: "cancel", label: "Cancel", style: .secondary, enabled: true),
            ]
        )
        assertDarkScreenSnapshot(of: screen, record: isRecording)
    }
}
