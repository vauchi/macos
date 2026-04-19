// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// AnimatedQrTimerTests.swift
// Tests for AppViewModel QR frame timer lifecycle.
// Based on: features/contact_exchange.feature — animated QR frames.

@testable import Vauchi
import XCTest

#if canImport(VauchiPlatform)
    import VauchiPlatform

    /// Unit tests for `AppViewModel.startQrFrameTimer` / `stopQrFrameTimer`.
    /// The view layer toggles these on `.onAppear` / `.onChange` / `.onDisappear`
    /// of the ShowQr screen; both start and stop must be idempotent because
    /// SwiftUI can deliver redundant lifecycle hooks (e.g. scene restoration
    /// delivers `.onAppear` plus the first screen change in the same tick).
    ///
    /// Constructs `PlatformAppEngine` directly against a temp `dataDir` so
    /// the tests work inside the test host (unlike `VauchiRepository`, which
    /// requires Keychain access).
    @MainActor
    final class AnimatedQrTimerTests: XCTestCase {
        var tempDir: URL!
        var engine: PlatformAppEngine!
        var viewModel: AppViewModel!

        /// `PlatformAppEngine` init touches SecureStorage which fails in the
        /// macOS XCTest host (no signed Vauchi app → no Keychain entitlement).
        /// SmokeTests uses the same skip pattern; see pipeline #2463404370 job
        /// 13987634725 where these tests crashed in 0.000s before this guard.
        private var isTestHost: Bool {
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        }

        override func setUpWithError() throws {
            try XCTSkipIf(isTestHost, "Requires Keychain — skipped in test host (SmokeTests convention)")

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
            viewModel?.stopQrFrameTimer()
            viewModel = nil
            engine = nil
            if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
        }

        /// Scenario: starting the timer twice does not create a second timer.
        func testStartQrFrameTimerIsIdempotent() {
            XCTAssertFalse(viewModel.hasActiveQrFrameTimer, "starts inactive")

            viewModel.startQrFrameTimer()
            XCTAssertTrue(viewModel.hasActiveQrFrameTimer, "first start activates")

            viewModel.startQrFrameTimer()
            XCTAssertTrue(viewModel.hasActiveQrFrameTimer, "second start is a no-op")
        }

        /// Scenario: stopping an inactive timer is a no-op.
        func testStopQrFrameTimerOnInactiveIsSafe() {
            XCTAssertFalse(viewModel.hasActiveQrFrameTimer)

            viewModel.stopQrFrameTimer()
            XCTAssertFalse(viewModel.hasActiveQrFrameTimer, "stop on inactive stays inactive")
        }

        /// Scenario: start then stop clears the timer.
        func testStartThenStopDeactivates() {
            viewModel.startQrFrameTimer()
            XCTAssertTrue(viewModel.hasActiveQrFrameTimer)

            viewModel.stopQrFrameTimer()
            XCTAssertFalse(viewModel.hasActiveQrFrameTimer)
        }

        /// Scenario: stop twice in a row is safe.
        func testStopTwiceIsIdempotent() {
            viewModel.startQrFrameTimer()
            viewModel.stopQrFrameTimer()
            viewModel.stopQrFrameTimer()
            XCTAssertFalse(viewModel.hasActiveQrFrameTimer)
        }

        /// Scenario: start/stop cycle can be repeated without leaking timers.
        func testStartStopCycleRepeatable() {
            for _ in 0 ..< 5 {
                viewModel.startQrFrameTimer()
                XCTAssertTrue(viewModel.hasActiveQrFrameTimer)
                viewModel.stopQrFrameTimer()
                XCTAssertFalse(viewModel.hasActiveQrFrameTimer)
            }
        }
    }
#endif
