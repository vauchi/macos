// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// AccessibilityTests.swift
// Accessibility snapshot tests for macOS components and screens.
// Verifies that all interactive elements have proper accessibility labels,
// traits, and values for VoiceOver users.

import SnapshotTesting
import SwiftUI
@testable import Vauchi
import XCTest

/// Accessibility snapshot tests.
///
/// Uses `.accessibilityImage` strategy to capture the accessibility tree
/// overlaid on the rendered view, catching missing labels or broken traits.
@MainActor
final class AccessibilityTests: XCTestCase {
    private var isRecording: Bool {
        ProcessInfo.processInfo.environment["SNAPSHOT_TESTING_RECORD"] == "all"
    }

    // MARK: - Component Accessibility

    func testTextInputAccessibility() {
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
        assertAccessibilitySnapshot(of: view, record: isRecording)
    }

    func testTextInputWithErrorAccessibility() {
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
        assertAccessibilitySnapshot(of: view, record: isRecording)
    }

    func testToggleListAccessibility() {
        let component = ToggleListComponent(
            id: "groups",
            label: "Groups",
            items: [
                ToggleItem(id: "family", label: "Family", selected: true, subtitle: nil),
                ToggleItem(id: "friends", label: "Friends", selected: false, subtitle: "Personal contacts"),
            ]
        )
        let view = ToggleListComponentView(component: component, onAction: noOp)
        assertAccessibilitySnapshot(of: view, height: 220, record: isRecording)
    }

    func testInfoPanelAccessibility() {
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
        assertAccessibilitySnapshot(of: view, height: 250, record: isRecording)
    }

    func testStatusIndicatorAccessibility() {
        let component = StatusIndicatorComponent(
            id: "status",
            icon: "checkmark.circle.fill",
            title: "Exchange Complete",
            detail: "Contact card saved successfully",
            status: .success
        )
        let view = StatusIndicatorComponentView(component: component)
        assertAccessibilitySnapshot(of: view, height: 120, record: isRecording)
    }

    func testInlineConfirmAccessibility() {
        let component = InlineConfirmComponent(
            id: "confirm-delete",
            warning: "Are you sure you want to delete this contact?",
            confirmText: "Delete",
            cancelText: "Cancel",
            destructive: true
        )
        let view = InlineConfirmComponentView(component: component, onAction: noOp)
        assertAccessibilitySnapshot(of: view, height: 150, record: isRecording)
    }

    func testContactListAccessibility() {
        let component = ContactListComponent(
            id: "contacts",
            contacts: [
                ContactItem(id: "c1", name: "Bob", subtitle: "Last updated 2h ago", avatarInitials: "B", status: nil),
                ContactItem(id: "c2", name: "Charlie", subtitle: nil, avatarInitials: "C", status: "pending"),
            ],
            searchable: true
        )
        let view = ContactListComponentView(component: component, onAction: noOp)
        assertAccessibilitySnapshot(of: view, height: 250, record: isRecording)
    }

    func testSettingsGroupAccessibility() {
        let component = SettingsGroupComponent(
            id: "security",
            label: "Security",
            items: [
                SettingsItem(id: "biometric", label: "Require Touch ID", kind: .toggle(enabled: true)),
                SettingsItem(id: "backup", label: "Export Backup", kind: .link(detail: nil)),
                SettingsItem(id: "wipe", label: "Delete All Data", kind: .destructive(label: "Delete")),
            ]
        )
        let view = SettingsGroupComponentView(component: component, onAction: noOp)
        assertAccessibilitySnapshot(of: view, height: 250, record: isRecording)
    }

    // MARK: - Screen Accessibility

    func testScreenRendererAccessibility() {
        let screen = makeScreen(
            screenId: "create_identity",
            title: "Create Your Identity",
            subtitle: "Choose a display name.",
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
            progress: Vauchi.Progress(currentStep: 1, totalSteps: 4, label: "Step 1 of 4")
        )
        let view = ScreenRendererView(screen: screen, onAction: noOp)
        assertAccessibilitySnapshot(of: view, height: 700, record: isRecording)
    }

    func testActionButtonDisabledAccessibility() {
        let action = ScreenAction(id: "continue", label: "Continue", style: .primary, enabled: false)
        let view = ActionButton(action: action, onTap: {})
        assertAccessibilitySnapshot(of: view, height: 80, record: isRecording)
    }

    func testActionButtonEnabledAccessibility() {
        let action = ScreenAction(id: "continue", label: "Continue", style: .primary, enabled: true)
        let view = ActionButton(action: action, onTap: {})
        assertAccessibilitySnapshot(of: view, height: 80, record: isRecording)
    }
}
