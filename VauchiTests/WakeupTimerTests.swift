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
    /// Opens `PlatformAppEngine` against a temp `dataDir` with the fake
    /// keychain store, so the tests run inside the test host, which has no
    /// Keychain entitlement.
    @MainActor
    final class WakeupTimerTests: XCTestCase {
        var tempDir: URL!
        var engine: PlatformAppEngine!
        var viewModel: AppViewModel!

        override func setUpWithError() throws {
            tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            engine = try PlatformAppEngine.openWithKeychain(
                dataDir: tempDir.path,
                relayUrl: "https://test.invalid",
                shellStorageKey: nil,
                keychain: VauchiKeychainBridge(keychain: FakeKeychainStore())
            )
            viewModel = AppViewModel(appEngine: engine)
        }

        override func tearDownWithError() throws {
            viewModel?.cancelWakeupTimer()
            viewModel = nil
            engine = nil
            if let tempDir {
                try? FileManager.default.removeItem(at: tempDir)
            }
        }

        /// Scenario: starting the timer twice does not create a second timer.
        func testArmWakeupTimerIsIdempotent() {
            XCTAssertFalse(viewModel.hasActiveWakeupTimer, "starts inactive")

            viewModel.armWakeupTimer(delayMillis: 10000)
            XCTAssertTrue(viewModel.hasActiveWakeupTimer, "first arm activates")

            viewModel.armWakeupTimer(delayMillis: 10000)
            XCTAssertTrue(viewModel.hasActiveWakeupTimer, "second arm replaces, still one timer")
        }

        /// Scenario: the timer waits exactly the delay Core computed.
        ///
        /// Core sends `delay_millis` (earliest, sub-second when needed, never
        /// past the deadline); macOS derived it from the other fields before
        /// (vauchi/private#548). A live QR exchange's ~300 ms frame dwell
        /// must survive as 0.3 s, not round to a second.
        func testArmsExactlyCoresDelay() {
            viewModel.armWakeupTimer(delayMillis: 300)
            XCTAssertEqual(viewModel.lastWakeupDelay ?? -1, 0.3, accuracy: 0.001)

            viewModel.armWakeupTimer(delayMillis: 30000)
            XCTAssertEqual(viewModel.lastWakeupDelay ?? -1, 30.0, accuracy: 0.001)
        }

        /// Scenario: cancelling an inactive timer is a no-op.
        func testCancelWakeupTimerOnInactiveIsSafe() {
            XCTAssertFalse(viewModel.hasActiveWakeupTimer)

            viewModel.cancelWakeupTimer()
            XCTAssertFalse(viewModel.hasActiveWakeupTimer, "cancel on inactive stays inactive")
        }

        /// Scenario: arm then cancel clears the timer.
        func testArmThenCancelDeactivates() {
            viewModel.armWakeupTimer(delayMillis: 10000)
            XCTAssertTrue(viewModel.hasActiveWakeupTimer)

            viewModel.cancelWakeupTimer()
            XCTAssertFalse(viewModel.hasActiveWakeupTimer)
        }

        /// Scenario: cancel twice in a row is safe.
        func testCancelTwiceIsIdempotent() {
            viewModel.armWakeupTimer(delayMillis: 10000)
            viewModel.cancelWakeupTimer()
            viewModel.cancelWakeupTimer()
            XCTAssertFalse(viewModel.hasActiveWakeupTimer)
        }

        /// Scenario: arm/cancel cycle can be repeated without leaking timers.
        func testArmCancelCycleRepeatable() {
            for _ in 0 ..< 5 {
                viewModel.armWakeupTimer(delayMillis: 10000)
                XCTAssertTrue(viewModel.hasActiveWakeupTimer)
                viewModel.cancelWakeupTimer()
                XCTAssertFalse(viewModel.hasActiveWakeupTimer)
            }
        }
    }
#endif
