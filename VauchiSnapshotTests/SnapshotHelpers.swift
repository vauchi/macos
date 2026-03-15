// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// SnapshotHelpers.swift
// Test helpers for macOS snapshot tests
//
// macOS adaptation of ios/VauchiSnapshotTests/SnapshotHelpers.swift.
// Uses NSImage-based snapshots instead of UIImage (no UIKit on macOS).

import SnapshotTesting
import SwiftUI
@testable import Vauchi

// MARK: - Component Snapshot Helper

/// Asserts a snapshot of a SwiftUI view at a fixed size.
/// macOS uses NSImage-based snapshots (no UITraitCollection).
@MainActor
func assertComponentSnapshot(
    of view: some View,
    width: CGFloat = 480,
    height: CGFloat = 200,
    record isRecording: Bool = false,
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line
) {
    assertSnapshot(
        of: view.padding().frame(width: width, height: height),
        as: .image,
        record: isRecording,
        file: file,
        testName: testName,
        line: line
    )
}

/// Asserts a dark mode snapshot of a SwiftUI view.
@MainActor
func assertDarkComponentSnapshot(
    of view: some View,
    width: CGFloat = 480,
    height: CGFloat = 200,
    record isRecording: Bool = false,
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line
) {
    assertSnapshot(
        of: view.padding()
            .frame(width: width, height: height)
            .environment(\.colorScheme, .dark),
        as: .image,
        record: isRecording,
        file: file,
        testName: testName,
        line: line
    )
}

// MARK: - Screen Snapshot Helper

/// Asserts a snapshot of a full screen rendered via ScreenRendererView.
/// Uses a desktop-appropriate window size (480×700 pt).
@MainActor
func assertScreenSnapshot(
    of screen: ScreenModel,
    width: CGFloat = 480,
    height: CGFloat = 700,
    record isRecording: Bool = false,
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line
) {
    let view = ScreenRendererView(screen: screen, onAction: { _ in })
        .frame(width: width, height: height)

    assertSnapshot(
        of: view,
        as: .image,
        record: isRecording,
        file: file,
        testName: testName,
        line: line
    )
}

/// Asserts a dark mode snapshot of a full screen.
@MainActor
func assertDarkScreenSnapshot(
    of screen: ScreenModel,
    width: CGFloat = 480,
    height: CGFloat = 700,
    record isRecording: Bool = false,
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line
) {
    let view = ScreenRendererView(screen: screen, onAction: { _ in })
        .frame(width: width, height: height)
        .environment(\.colorScheme, .dark)

    assertSnapshot(
        of: view,
        as: .image,
        record: isRecording,
        file: file,
        testName: testName,
        line: line
    )
}

// MARK: - Accessibility Snapshot Helper

/// Asserts an accessibility audit of a SwiftUI view.
/// Captures the accessibility tree as text for regression testing.
@MainActor
func assertAccessibilitySnapshot(
    of view: some View,
    width: CGFloat = 480,
    height: CGFloat = 400,
    record isRecording: Bool = false,
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line
) {
    assertSnapshot(
        of: view.frame(width: width, height: height),
        as: .accessibilityImage,
        record: isRecording,
        file: file,
        testName: testName,
        line: line
    )
}

// MARK: - No-op Action Handler

/// No-op action handler for components that require one.
let noOp: (UserAction) -> Void = { _ in }

// MARK: - Sample Data Factories

/// Creates a minimal ScreenModel for snapshot testing.
func makeScreen(
    screenId: String = "test_screen",
    title: String = "Test Screen",
    subtitle: String? = nil,
    components: [Component] = [],
    actions: [ScreenAction] = [],
    progress: Progress? = nil
) -> ScreenModel {
    ScreenModel(
        screenId: screenId,
        title: title,
        subtitle: subtitle,
        components: components,
        actions: actions,
        progress: progress
    )
}
