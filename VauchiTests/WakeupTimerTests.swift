// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for AppViewModel core-scheduled wakeup timer lifecycle.
// Based on: features/notifications.feature — ADR-044 Am2a wakeup scheduling.

@testable import Vauchi
import XCTest

#if canImport(VauchiPlatform)
    import VauchiPlatform

    /// Unit tests for `AppViewModel.armWakeupTimer` / `cancelWakeupTimer`.
    /// `AppContentView` arms these via `CommandDTO.scheduleWakeup` and
    /// cancels on disappear; start/stop must be idempotent because SwiftUI
    /// can deliver redundant lifecycle hooks.
    ///
    /// Constructs `PlatformAppEngine` directly against a temp `dataDir` so
    /// the tests work inside the test host (unlike `VauchiRepository`, which
    /// requires Keychain access).
    @MainActor
    final class WakeupTimerTests: XCTestCase {
        var tempDir: URL!
        var engine: PlatformAppEngine!
        var viewModel: AppViewModel!

        /// `PlatformAppEngine` init touches SecureStorage which fails in the
        /// macOS XCTest host (no signed Vauchi app → no Keychain entitlement).
        /// Mirrors the retired `AnimatedQrTimerTests` skip convention.
        private var isTestHost: Bool {
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        }

        override func setUpWithError() throws {
            try XCTSkipIf(isTestHost, "Requires Keychain — skipped in test host")

            tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Deterministic 32-byte storage key — tests never share state with
            // real data dirs, so a constant key is safe and avoids Keychain.
            let storageKey = Data(repeating: 0, count: 32)
            engine = try PlatformAppEngine(
                dataDir: tempDir.path,
                relayUrl: "https://test.invalid",
                storageKeyBytes: storageKey
            )
            viewModel = AppViewModel(appEngine: engine)
        }

        override func tearDownWithError() throws {
            viewModel?.cancelWakeupTimer()
            viewModel = nil
            engine = nil
            if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        }

        /// Scenario: starting the timer twice does not create a second timer.
        func testArmWakeupTimerIsIdempotent() {
            XCTAssertFalse(viewModel.hasActiveWakeupTimer, "starts inactive")

            viewModel.armWakeupTimer(earliestSecs: 10, deadlineSecs: 60, minIntervalSecs: 30)
            XCTAssertTrue(viewModel.hasActiveWakeupTimer, "first arm activates")

            viewModel.armWakeupTimer(earliestSecs: 10, deadlineSecs: 60, minIntervalSecs: 30)
            XCTAssertTrue(viewModel.hasActiveWakeupTimer, "second arm replaces, still one timer")
        }

        /// Scenario: cancelling an inactive timer is a no-op.
        func testCancelWakeupTimerOnInactiveIsSafe() {
            XCTAssertFalse(viewModel.hasActiveWakeupTimer)

            viewModel.cancelWakeupTimer()
            XCTAssertFalse(viewModel.hasActiveWakeupTimer, "cancel on inactive stays inactive")
        }

        /// Scenario: arm then cancel clears the timer.
        func testArmThenCancelDeactivates() {
            viewModel.armWakeupTimer(earliestSecs: 10, deadlineSecs: 60, minIntervalSecs: 30)
            XCTAssertTrue(viewModel.hasActiveWakeupTimer)

            viewModel.cancelWakeupTimer()
            XCTAssertFalse(viewModel.hasActiveWakeupTimer)
        }

        /// Scenario: cancel twice in a row is safe.
        func testCancelTwiceIsIdempotent() {
            viewModel.armWakeupTimer(earliestSecs: 10, deadlineSecs: 60, minIntervalSecs: 30)
            viewModel.cancelWakeupTimer()
            viewModel.cancelWakeupTimer()
            XCTAssertFalse(viewModel.hasActiveWakeupTimer)
        }

        /// Scenario: arm/cancel cycle can be repeated without leaking timers.
        func testArmCancelCycleRepeatable() {
            for _ in 0 ..< 5 {
                viewModel.armWakeupTimer(earliestSecs: 10, deadlineSecs: 60, minIntervalSecs: 30)
                XCTAssertTrue(viewModel.hasActiveWakeupTimer)
                viewModel.cancelWakeupTimer()
                XCTAssertFalse(viewModel.hasActiveWakeupTimer)
            }
        }
    }
#endif
