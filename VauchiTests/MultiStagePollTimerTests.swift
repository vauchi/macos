// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// MultiStagePollTimerTests.swift
// Tests for AppViewModel multi-stage exchange poll-timer lifecycle.
// Regression guard for Bug 5 of
// `2026-05-30-exchange-screen-nav-visual-bugs`: the core cycle thread
// retired in slice-32m left the multi-stage (Glance) exchange screen with
// no driver, so the own-QR never appeared. The timer drives
// `pollNotifications` (→ `advance_multi_stage_session`) while the screen is
// visible.

@testable import Vauchi
import XCTest

#if canImport(VauchiPlatform)
    import VauchiPlatform

    /// Unit tests for `AppViewModel.startMultiStagePollTimer` /
    /// `stopMultiStagePollTimer`. `AppContentView` toggles these on
    /// `.onAppear` / `.onChange` / `.onDisappear` of the
    /// `multi_stage_exchange` screen; both start and stop must be idempotent
    /// because SwiftUI can deliver redundant lifecycle hooks.
    @MainActor
    final class MultiStagePollTimerTests: XCTestCase {
        var tempDir: URL!
        var engine: PlatformAppEngine!
        var viewModel: AppViewModel!

        /// `PlatformAppEngine` init touches SecureStorage which fails in the
        /// macOS XCTest host (no signed Vauchi app → no Keychain
        /// entitlement). Mirrors `AnimatedQrTimerTests`' skip.
        private var isTestHost: Bool {
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        }

        override func setUpWithError() throws {
            try XCTSkipIf(isTestHost, "Requires Keychain — skipped in test host (SmokeTests convention)")

            tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let storageKey = Data(repeating: 0, count: 32)
            engine = try PlatformAppEngine(
                dataDir: tempDir.path,
                relayUrl: "https://test.invalid",
                storageKeyBytes: storageKey
            )
            viewModel = AppViewModel(appEngine: engine)
        }

        override func tearDownWithError() throws {
            viewModel?.stopMultiStagePollTimer()
            viewModel = nil
            engine = nil
            if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        }

        /// Scenario: starting the timer twice does not create a second timer.
        func testStartMultiStagePollTimerIsIdempotent() {
            XCTAssertFalse(viewModel.hasActiveMultiStagePollTimer, "starts inactive")

            viewModel.startMultiStagePollTimer()
            XCTAssertTrue(viewModel.hasActiveMultiStagePollTimer, "first start activates")

            viewModel.startMultiStagePollTimer()
            XCTAssertTrue(viewModel.hasActiveMultiStagePollTimer, "second start is a no-op")
        }

        /// Scenario: stopping an inactive timer is a no-op.
        func testStopMultiStagePollTimerOnInactiveIsSafe() {
            XCTAssertFalse(viewModel.hasActiveMultiStagePollTimer)

            viewModel.stopMultiStagePollTimer()
            XCTAssertFalse(viewModel.hasActiveMultiStagePollTimer, "stop on inactive stays inactive")
        }

        /// Scenario: start then stop clears the timer.
        func testStartThenStopDeactivates() {
            viewModel.startMultiStagePollTimer()
            XCTAssertTrue(viewModel.hasActiveMultiStagePollTimer)

            viewModel.stopMultiStagePollTimer()
            XCTAssertFalse(viewModel.hasActiveMultiStagePollTimer)
        }

        /// Scenario: stop twice in a row is safe.
        func testStopTwiceIsIdempotent() {
            viewModel.startMultiStagePollTimer()
            viewModel.stopMultiStagePollTimer()
            viewModel.stopMultiStagePollTimer()
            XCTAssertFalse(viewModel.hasActiveMultiStagePollTimer)
        }

        /// Scenario: start/stop cycle can be repeated without leaking timers.
        func testStartStopCycleRepeatable() {
            for _ in 0 ..< 5 {
                viewModel.startMultiStagePollTimer()
                XCTAssertTrue(viewModel.hasActiveMultiStagePollTimer)
                viewModel.stopMultiStagePollTimer()
                XCTAssertFalse(viewModel.hasActiveMultiStagePollTimer)
            }
        }
    }
#endif
