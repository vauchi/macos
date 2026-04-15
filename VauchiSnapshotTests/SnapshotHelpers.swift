// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// SnapshotHelpers.swift
// Test helpers for macOS snapshot tests
//
// macOS adaptation of ios/VauchiSnapshotTests/SnapshotHelpers.swift.
// Uses NSHostingController + NSImage-based snapshots (no UIKit on macOS).

import AppKit
import SnapshotTesting
import SwiftUI
@testable import Vauchi

// MARK: - NSHostingController Wrapper

/// Wraps a SwiftUI view in an NSHostingController for macOS snapshot testing.
/// swift-snapshot-testing requires NSViewController (not bare SwiftUI views) on macOS.
@MainActor
private func hostingController(
    for view: some View,
    width: CGFloat,
    height: CGFloat
) -> NSViewController {
    let controller = NSHostingController(rootView: view)
    controller.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
    return controller
}

// MARK: - Component Snapshot Helper

/// Asserts a snapshot of a SwiftUI view at a fixed size.
/// macOS uses NSHostingController + NSImage-based snapshots.
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
    let host = hostingController(
        for: view.padding(),
        width: width,
        height: height
    )
    assertSnapshot(
        of: host,
        as: .image(perceptualPrecision: 0.98),
        record: isRecording,
        file: file,
        testName: testName,
        line: line
    )
}

/// Asserts a dark mode snapshot of a SwiftUI view.
///
/// Uses 0.95 perceptual precision (vs 0.98 for light mode) because AppKit's
/// NSTextField border and NSAppearance(darkAqua) compositing produce
/// non-deterministic rendering variance between xcodebuild invocations.
///
/// `.focusEffectDisabled()` prevents the system focus ring from appearing
/// non-deterministically on text fields between runs (see testTextInputDark).
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
    let host = hostingController(
        for: view.padding()
            .focusEffectDisabled()
            .environment(\.colorScheme, .dark),
        width: width,
        height: height
    )
    host.view.appearance = NSAppearance(named: .darkAqua)
    assertSnapshot(
        of: host,
        as: .image(perceptualPrecision: 0.95),
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
    let host = hostingController(for: view, width: width, height: height)
    assertSnapshot(
        of: host,
        as: .image(perceptualPrecision: 0.98),
        record: isRecording,
        file: file,
        testName: testName,
        line: line
    )
}

/// Asserts a dark mode snapshot of a full screen.
/// See `assertDarkComponentSnapshot` for precision and focus rationale.
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
        .focusEffectDisabled()
        .environment(\.colorScheme, .dark)
    let host = hostingController(for: view, width: width, height: height)
    host.view.appearance = NSAppearance(named: .darkAqua)
    assertSnapshot(
        of: host,
        as: .image(perceptualPrecision: 0.95),
        record: isRecording,
        file: file,
        testName: testName,
        line: line
    )
}

// MARK: - Accessibility Snapshot Helper

/// Asserts an accessibility snapshot of a SwiftUI view using the
/// recursive description of the accessibility hierarchy as text.
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
    let host = hostingController(for: view, width: width, height: height)
    assertSnapshot(
        of: host,
        as: .recursiveDescription,
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
    progress: Vauchi.Progress? = nil,
    tokens: DesignTokens = .defaults
) -> ScreenModel {
    ScreenModel(
        screenId: screenId,
        title: title,
        subtitle: subtitle,
        components: components,
        actions: actions,
        progress: progress,
        tokens: tokens
    )
}
