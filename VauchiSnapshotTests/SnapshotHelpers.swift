// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Test helpers for macOS snapshot tests
//
// macOS adaptation of ios/VauchiSnapshotTests/SnapshotHelpers.swift.
// Uses NSHostingController + NSImage-based snapshots (no UIKit on macOS).

import AppKit
import CoreUIModels
import SnapshotTesting
import SwiftUI
@testable import Vauchi

// MARK: - NSHostingController Wrapper

/// Shared ThemeService instance used for all snapshot tests. Reads the same
/// `ThemeService.shared` the app uses — gives deterministic output once a
/// baseline theme (Catppuccin Mocha / Latte) is loaded on the first FFI call.
@MainActor
private let snapshotThemeService = ThemeService.shared

/// Wraps a SwiftUI view in an NSHostingController for macOS snapshot testing.
/// swift-snapshot-testing requires NSViewController (not bare SwiftUI views) on macOS.
/// Injects `ThemeService` as an `@EnvironmentObject` so CoreUI components
/// that consume it render with the real palette instead of hitting a runtime
/// "missing environmentObject" crash.
@MainActor
private func hostingController(
    for view: some View,
    width: CGFloat,
    height: CGFloat
) -> NSViewController {
    let themed = view.environmentObject(snapshotThemeService)
    let controller = NSHostingController(rootView: themed)
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
        // precision 0.96 tolerates ≤4% of pixels differing. The CI runner
        // renders at 1× scale, where thin 1-px features (text strokes, borders,
        // circle edges) have no supersampling headroom and flip white↔fill on a
        // sub-pixel layout wobble between otherwise-identical runs; two measured
        // flakes (light contacts + dark text-input) were each ~3.7% of pixels.
        // perceptualPrecision 0.95 still guards colour drift across the bulk.
        // Trade-off: a real regression under ~4% of the frame can slip; the
        // power-preserving alternative is 2× (Retina) rendering + re-record.
        as: .image(precision: 0.96, perceptualPrecision: 0.95),
        record: isRecording,
        file: file,
        testName: testName,
        line: line
    )
}

/// Asserts a dark mode snapshot of a SwiftUI view.
///
/// Uses perceptualPrecision 0.95 + precision 0.96 (matching the light helpers) because AppKit's
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
        // precision 0.96 (≤4% pixel tolerance): the dark helpers flake on the
        // same 1×-scale thin-feature jitter as light — testTextInputDark failed
        // at ~3.7% differing pixels. See assertComponentSnapshot for the trade-off.
        as: .image(precision: 0.96, perceptualPrecision: 0.95),
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
        // Same 1×-scale thin-feature jitter as assertComponentSnapshot.
        as: .image(precision: 0.96, perceptualPrecision: 0.95),
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
        // precision 0.96 (≤4% pixel tolerance): the dark helpers flake on the
        // same 1×-scale thin-feature jitter as light — testTextInputDark failed
        // at ~3.7% differing pixels. See assertComponentSnapshot for the trade-off.
        as: .image(precision: 0.96, perceptualPrecision: 0.95),
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
    progress: CoreUIModels.Progress? = nil,
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
