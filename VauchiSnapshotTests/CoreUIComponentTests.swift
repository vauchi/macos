// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// CoreUIComponentTests.swift
// Component-level snapshot tests for CoreUI views in isolation (macOS).
// Based on: features/contact_exchange.feature, features/identity.feature
//
// macOS adaptation of ios/VauchiSnapshotTests/CoreUIComponentTests.swift.
// Uses NSImage-based snapshots, no UITraitCollection.

import SnapshotTesting
import SwiftUI
@testable import Vauchi
import XCTest

/// Snapshot tests for individual CoreUI components rendered in isolation.
///
/// Each component is tested with mock data at a compact size (480 pt wide)
/// to verify visual rendering without full-screen context.
@MainActor
final class CoreUIComponentTests: XCTestCase {
    /// Whether to record new baselines. Always false in CI.
    private var isRecording: Bool {
        false
    }

    // MARK: - TextInputComponentView

    func testTextInputEmpty() {
        let component = TextInputComponent(
            id: "name",
            label: "Display Name",
            value: "",
            placeholder: "Enter your name",
            maxLength: 50,
            validationError: nil,
            inputType: .text
        )
        let view = TextInputComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, record: isRecording)
    }

    func testTextInputWithValue() {
        let component = TextInputComponent(
            id: "name",
            label: "Display Name",
            value: "Alice",
            placeholder: "Enter your name",
            maxLength: 50,
            validationError: nil,
            inputType: .text
        )
        let view = TextInputComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, record: isRecording)
    }

    func testTextInputWithValidationError() {
        let component = TextInputComponent(
            id: "name",
            label: "Display Name",
            value: "",
            placeholder: "Enter your name",
            maxLength: 50,
            validationError: "Name is required",
            inputType: .text
        )
        let view = TextInputComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, record: isRecording)
    }

    func testTextInputEmailType() {
        let component = TextInputComponent(
            id: "email",
            label: "Email",
            value: "alice@example.com",
            placeholder: "you@example.com",
            maxLength: nil,
            validationError: nil,
            inputType: .email
        )
        let view = TextInputComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, record: isRecording)
    }

    func testTextInputPassword() {
        let component = TextInputComponent(
            id: "pin",
            label: "PIN",
            value: "1234",
            placeholder: "Enter PIN",
            maxLength: 6,
            validationError: nil,
            inputType: .password
        )
        let view = TextInputComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, record: isRecording)
    }

    // MARK: - ToggleListComponentView

    func testToggleListDefault() {
        let component = ToggleListComponent(
            id: "groups",
            label: "Groups",
            items: [
                ToggleItem(id: "family", label: "Family", selected: true, subtitle: nil),
                ToggleItem(id: "friends", label: "Friends", selected: false, subtitle: nil),
                ToggleItem(id: "coworkers", label: "Coworkers", selected: false, subtitle: nil),
            ]
        )
        let view = ToggleListComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, height: 250, record: isRecording)
    }

    func testToggleListAllSelected() {
        let component = ToggleListComponent(
            id: "groups",
            label: "Groups",
            items: [
                ToggleItem(id: "family", label: "Family", selected: true, subtitle: "Close relatives"),
                ToggleItem(id: "friends", label: "Friends", selected: true, subtitle: "Personal contacts"),
                ToggleItem(id: "coworkers", label: "Coworkers", selected: true, subtitle: "Work contacts"),
            ]
        )
        let view = ToggleListComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, height: 300, record: isRecording)
    }

    // MARK: - FieldListComponentView

    func testFieldListEmpty() {
        let component = FieldListComponent(
            id: "fields",
            fields: [],
            visibilityMode: .showHide,
            availableGroups: []
        )
        let view = FieldListComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, record: isRecording)
    }

    func testFieldListWithFieldsShowHide() {
        let component = FieldListComponent(
            id: "fields",
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
                    visibility: .hidden
                ),
            ],
            visibilityMode: .showHide,
            availableGroups: []
        )
        let view = FieldListComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, height: 250, record: isRecording)
    }

    func testFieldListPerGroup() {
        let component = FieldListComponent(
            id: "fields",
            fields: [
                FieldDisplay(
                    id: "f1",
                    fieldType: "email",
                    label: "Email",
                    value: "alice@example.com",
                    visibility: .groups(["Family", "Friends"])
                ),
                FieldDisplay(
                    id: "f2",
                    fieldType: "phone",
                    label: "Mobile",
                    value: "+41 79 123 45 67",
                    visibility: .groups(["Family"])
                ),
            ],
            visibilityMode: .perGroup,
            availableGroups: ["Family", "Friends", "Coworkers"]
        )
        let view = FieldListComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, height: 350, record: isRecording)
    }

    // MARK: - CardPreviewComponentView

    func testCardPreviewMinimal() {
        let component = CardPreviewComponent(
            name: "Alice",
            fields: [],
            groupViews: [],
            selectedGroup: nil
        )
        let view = CardPreviewComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, height: 300, record: isRecording)
    }

    func testCardPreviewWithFields() {
        let component = CardPreviewComponent(
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
        )
        let view = CardPreviewComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, height: 400, record: isRecording)
    }

    func testCardPreviewWithGroups() {
        let component = CardPreviewComponent(
            name: "Alice",
            fields: [
                FieldDisplay(
                    id: "f1",
                    fieldType: "email",
                    label: "Email",
                    value: "alice@example.com",
                    visibility: .groups(["Family", "Friends"])
                ),
            ],
            groupViews: [
                GroupCardView(
                    groupName: "Family",
                    displayName: "Alice",
                    visibleFields: [
                        FieldDisplay(
                            id: "f1",
                            fieldType: "email",
                            label: "Email",
                            value: "alice@example.com",
                            visibility: .shown
                        ),
                    ]
                ),
                GroupCardView(
                    groupName: "Friends",
                    displayName: "Ali",
                    visibleFields: [
                        FieldDisplay(
                            id: "f1",
                            fieldType: "email",
                            label: "Email",
                            value: "alice@example.com",
                            visibility: .shown
                        ),
                    ]
                ),
            ],
            selectedGroup: nil
        )
        let view = CardPreviewComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, height: 450, record: isRecording)
    }

    // MARK: - InfoPanelComponentView

    func testInfoPanelWithIcon() {
        let component = InfoPanelComponent(
            id: "security",
            icon: "lock",
            title: "End-to-End Encryption",
            items: [
                InfoItem(
                    icon: "key",
                    title: "Your Keys",
                    detail: "Keys are generated on your device and never leave it."
                ),
                InfoItem(
                    icon: "shield",
                    title: "Zero Knowledge",
                    detail: "The relay server cannot read your contact data."
                ),
            ]
        )
        let view = InfoPanelComponentView(component: component)
        assertComponentSnapshot(of: view, height: 250, record: isRecording)
    }

    func testInfoPanelSingleItem() {
        let component = InfoPanelComponent(
            id: "tip",
            icon: "checkmark",
            title: "All Set",
            items: [
                InfoItem(icon: "checkmark", title: "Ready", detail: "Your card is ready to share."),
            ]
        )
        let view = InfoPanelComponentView(component: component)
        assertComponentSnapshot(of: view, height: 150, record: isRecording)
    }

    // MARK: - TextComponentView

    func testTextComponentTitle() {
        let component = TextComponent(id: "t1", content: "Welcome to Vauchi", style: .title)
        let view = TextComponentView(component: component)
        assertComponentSnapshot(of: view, height: 80, record: isRecording)
    }

    func testTextComponentSubtitle() {
        let component = TextComponent(id: "t2", content: "Your privacy-first contact card", style: .subtitle)
        let view = TextComponentView(component: component)
        assertComponentSnapshot(of: view, height: 80, record: isRecording)
    }

    func testTextComponentBody() {
        let component = TextComponent(
            id: "t3",
            // swiftlint:disable:next line_length
            content: "Vauchi lets you share contact information securely. Updates are end-to-end encrypted and delivered automatically.",
            style: .body
        )
        let view = TextComponentView(component: component)
        assertComponentSnapshot(of: view, height: 120, record: isRecording)
    }

    func testTextComponentCaption() {
        let component = TextComponent(id: "t4", content: "All data stays on your device", style: .caption)
        let view = TextComponentView(component: component)
        assertComponentSnapshot(of: view, height: 60, record: isRecording)
    }

    // MARK: - InlineConfirmComponentView

    func testInlineConfirmDestructive() {
        let component = InlineConfirmComponent(
            id: "confirm-delete",
            warning: "Are you sure you want to delete this contact?",
            confirmText: "Delete",
            cancelText: "Cancel",
            destructive: true
        )
        let view = InlineConfirmComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, height: 150, record: isRecording)
    }

    func testInlineConfirmNonDestructive() {
        let component = InlineConfirmComponent(
            id: "confirm-merge",
            warning: "Merge these two contacts?",
            confirmText: "Merge",
            cancelText: "Keep Separate",
            destructive: false
        )
        let view = InlineConfirmComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, height: 150, record: isRecording)
    }

    // MARK: - EditableTextComponentView

    func testEditableTextDisplay() {
        let component = EditableTextComponent(
            id: "display-name",
            label: "Display Name",
            value: "Alice",
            editing: false,
            validationError: nil
        )
        let view = EditableTextComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, height: 100, record: isRecording)
    }

    func testEditableTextEditing() {
        let component = EditableTextComponent(
            id: "display-name",
            label: "Display Name",
            value: "Alice",
            editing: true,
            validationError: nil
        )
        let view = EditableTextComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, height: 120, record: isRecording)
    }

    func testEditableTextWithError() {
        let component = EditableTextComponent(
            id: "display-name",
            label: "Display Name",
            value: "",
            editing: true,
            validationError: "Name cannot be empty"
        )
        let view = EditableTextComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, height: 140, record: isRecording)
    }

    // MARK: - StatusIndicatorComponentView

    func testStatusIndicatorSuccess() {
        let component = StatusIndicatorComponent(
            id: "status",
            icon: "checkmark.circle.fill",
            title: "Exchange Complete",
            detail: "Contact card saved successfully",
            status: .success
        )
        let view = StatusIndicatorComponentView(component: component)
        assertComponentSnapshot(of: view, height: 120, record: isRecording)
    }

    func testStatusIndicatorPending() {
        let component = StatusIndicatorComponent(
            id: "status",
            icon: "clock",
            title: "Waiting for Response",
            detail: "The other device has not scanned yet",
            status: .pending
        )
        let view = StatusIndicatorComponentView(component: component)
        assertComponentSnapshot(of: view, height: 120, record: isRecording)
    }

    func testStatusIndicatorFailed() {
        let component = StatusIndicatorComponent(
            id: "status",
            icon: "exclamationmark.triangle",
            title: "Exchange Failed",
            detail: "QR code expired. Please try again.",
            status: .failed
        )
        let view = StatusIndicatorComponentView(component: component)
        assertComponentSnapshot(of: view, height: 120, record: isRecording)
    }

    // MARK: - ContactListComponentView

    func testContactListEmpty() {
        let component = ContactListComponent(
            id: "contacts",
            contacts: [],
            searchable: false
        )
        let view = ContactListComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, height: 100, record: isRecording)
    }

    func testContactListWithContacts() {
        let component = ContactListComponent(
            id: "contacts",
            contacts: [
                ContactItem(id: "c1", name: "Bob", subtitle: "Last updated 2h ago", avatarInitials: "B", status: nil),
                ContactItem(id: "c2", name: "Charlie", subtitle: nil, avatarInitials: "C", status: "pending"),
                ContactItem(id: "c3", name: "Diana", subtitle: "3 fields shared", avatarInitials: "D", status: nil),
            ],
            searchable: true
        )
        let view = ContactListComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, height: 350, record: isRecording)
    }

    // MARK: - SettingsGroupComponentView

    func testSettingsGroup() {
        let component = SettingsGroupComponent(
            id: "privacy",
            label: "Privacy",
            items: [
                SettingsItem(id: "biometric", label: "Require Biometric", kind: .toggle(enabled: true)),
                SettingsItem(id: "version", label: "Version", kind: .value(value: "0.1.0")),
                SettingsItem(id: "about", label: "About", kind: .link(detail: nil)),
                SettingsItem(id: "wipe", label: "Delete All Data", kind: .destructive(label: "Delete")),
            ]
        )
        let view = SettingsGroupComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, height: 350, record: isRecording)
    }

    // MARK: - ActionListComponentView

    func testActionList() {
        let component = ActionListComponent(
            id: "actions",
            items: [
                ActionListItem(id: "share", label: "Share Card", icon: "square.and.arrow.up", detail: nil),
                ActionListItem(
                    id: "export",
                    label: "Export Backup",
                    icon: "arrow.down.doc",
                    detail: "Last backup: Today"
                ),
                ActionListItem(
                    id: "devices",
                    label: "Linked Devices",
                    icon: "laptopcomputer.and.iphone",
                    detail: "2 devices"
                ),
            ]
        )
        let view = ActionListComponentView(component: component, onAction: noOp)
        assertComponentSnapshot(of: view, height: 250, record: isRecording)
    }

    // MARK: - DividerComponentView

    func testDivider() {
        let view = DividerComponentView()
        assertComponentSnapshot(of: view, height: 40, record: isRecording)
    }

    // MARK: - Dark Mode Variants

    func testTextInputDark() {
        let component = TextInputComponent(
            id: "name",
            label: "Display Name",
            value: "Alice",
            placeholder: "Enter your name",
            maxLength: 50,
            validationError: nil,
            inputType: .text
        )
        assertDarkComponentSnapshot(
            of: TextInputComponentView(component: component, onAction: noOp),
            record: isRecording
        )
    }

    func testToggleListDark() {
        let component = ToggleListComponent(
            id: "groups",
            label: "Groups",
            items: [
                ToggleItem(id: "family", label: "Family", selected: true, subtitle: nil),
                ToggleItem(id: "friends", label: "Friends", selected: false, subtitle: "Personal contacts"),
            ]
        )
        assertDarkComponentSnapshot(
            of: ToggleListComponentView(component: component, onAction: noOp),
            height: 220,
            record: isRecording
        )
    }

    func testCardPreviewDark() {
        let component = CardPreviewComponent(
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
        )
        assertDarkComponentSnapshot(
            of: CardPreviewComponentView(component: component, onAction: noOp),
            height: 400,
            record: isRecording
        )
    }

    func testInfoPanelDark() {
        let component = InfoPanelComponent(
            id: "security",
            icon: "lock",
            title: "End-to-End Encryption",
            items: [
                InfoItem(
                    icon: "key",
                    title: "Your Keys",
                    detail: "Keys are generated on your device and never leave it."
                ),
                InfoItem(
                    icon: "shield",
                    title: "Zero Knowledge",
                    detail: "The relay server cannot read your contact data."
                ),
            ]
        )
        assertDarkComponentSnapshot(
            of: InfoPanelComponentView(component: component),
            height: 250,
            record: isRecording
        )
    }

    func testSettingsGroupDark() {
        let component = SettingsGroupComponent(
            id: "privacy",
            label: "Privacy",
            items: [
                SettingsItem(id: "biometric", label: "Require Biometric", kind: .toggle(enabled: true)),
                SettingsItem(id: "version", label: "Version", kind: .value(value: "0.1.0")),
                SettingsItem(id: "wipe", label: "Delete All Data", kind: .destructive(label: "Delete")),
            ]
        )
        assertDarkComponentSnapshot(
            of: SettingsGroupComponentView(component: component, onAction: noOp),
            height: 300,
            record: isRecording
        )
    }

    func testInlineConfirmDark() {
        let component = InlineConfirmComponent(
            id: "confirm-delete",
            warning: "Are you sure you want to delete this contact?",
            confirmText: "Delete",
            cancelText: "Cancel",
            destructive: true
        )
        assertDarkComponentSnapshot(
            of: InlineConfirmComponentView(component: component, onAction: noOp),
            height: 150,
            record: isRecording
        )
    }

    func testStatusIndicatorDark() {
        let component = StatusIndicatorComponent(
            id: "status",
            icon: "checkmark.circle.fill",
            title: "Exchange Complete",
            detail: "Contact card saved successfully",
            status: .success
        )
        assertDarkComponentSnapshot(
            of: StatusIndicatorComponentView(component: component),
            height: 120,
            record: isRecording
        )
    }
}
