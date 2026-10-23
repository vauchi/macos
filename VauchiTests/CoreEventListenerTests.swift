// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Core starts its content scheduler when a shell registers an event
// listener (private#733, D10), and tells that listener to re-render after
// background work such as an applied content update. Without one the Mac
// never downloads CDN locales or themes once the launch-time cycle is gone.
//
// Traces to: features/remote_content.feature

@testable import Vauchi
import XCTest

#if canImport(VauchiPlatform)
    import VauchiPlatform

    @MainActor
    final class CoreEventListenerTests: XCTestCase {
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

        func testTheViewModelListensToCore() {
            XCTAssertTrue(viewModel.hasEventListener)
        }

        func testAnInvalidationFromCoreKeepsTheScreenUsable() {
            viewModel.eventListenerForTesting?.onPresentationInvalidated()

            let drained = expectation(description: "main queue drained")
            DispatchQueue.main.async { drained.fulfill() }
            wait(for: [drained], timeout: 5)
            XCTAssertNil(viewModel.alertMessage, "a re-render must not surface as an error")
        }
    }
#endif
