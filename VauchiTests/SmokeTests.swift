// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// SmokeTests.swift
// Basic smoke tests for the macOS app

@testable import Vauchi
import XCTest

final class SmokeTests: XCTestCase {
    #if canImport(VauchiPlatform)
        /// Whether we're running inside a test host (CI or local XCTest).
        /// AppState skips init in test hosts, so these integration tests
        /// only work when the app is launched normally with Keychain access.
        private var isTestHost: Bool {
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        }

        @MainActor
        func testAppStateInitializes() throws {
            try XCTSkipIf(isTestHost, "Requires Keychain — skipped in test host")
            let appState = AppState()
            XCTAssertNotNil(appState.viewModel, "AppState should create AppViewModel from PlatformAppEngine")
            XCTAssertNil(appState.error, "AppState should not have an error on fresh init")
        }

        @MainActor
        func testAppViewModelLoadsInitialScreen() throws {
            try XCTSkipIf(isTestHost, "Requires Keychain — skipped in test host")
            let appState = AppState()
            guard let viewModel = appState.viewModel else {
                XCTFail("AppState should create AppViewModel")
                return
            }
            XCTAssertNotNil(viewModel.currentScreen, "AppViewModel should load initial screen from core")
        }
    #else
        func testPlaceholderViewModelInitialState() {
            let viewModel = PlaceholderViewModel()
            XCTAssertNil(viewModel.currentScreen, "Initial screen should be nil before UniFFI connection")
        }
    #endif

    func testActionStyleDecoding() throws {
        let json = """
        "Primary"
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let style = try decoder.decode(ActionStyle.self, from: data)
        XCTAssertEqual(style, .primary)
    }

    func testTextStyleDecoding() throws {
        let json = """
        "Body"
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let style = try decoder.decode(TextStyle.self, from: data)
        XCTAssertEqual(style, .body)
    }

    func testDividerComponentDecoding() throws {
        let json = """
        "Divider"
        """
        let data = Data(json.utf8)
        let component = try coreJSONDecoder.decode(Component.self, from: data)
        if case .divider = component {
            // expected
        } else {
            XCTFail("Expected .divider, got \(component)")
        }
    }

    func testActionResultExchangeCommands() throws {
        let json = Data("""
        {"ExchangeCommands": {"commands": ["QrRequestScan", {"QrDisplay": {"data": "test-qr"}}]}}
        """.utf8)

        let result = try coreJSONDecoder.decode(ActionResult.self, from: json)

        guard case let .exchangeCommands(commands) = result else {
            XCTFail("Expected .exchangeCommands, got \(result)")
            return
        }
        XCTAssertEqual(commands.count, 2)
        guard case .qrRequestScan = commands[0] else {
            XCTFail("Expected .qrRequestScan, got \(commands[0])")
            return
        }
        guard case let .qrDisplay(data) = commands[1] else {
            XCTFail("Expected .qrDisplay, got \(commands[1])")
            return
        }
        XCTAssertEqual(data, "test-qr")
    }

    func testUserActionEncoding() throws {
        let action = UserAction.textChanged(componentId: "name", value: "Alice")
        let data = try coreJSONEncoder.encode(action)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("TextChanged"), "Expected PascalCase variant key")
        XCTAssertTrue(json.contains("component_id"), "Expected snake_case field key")
        XCTAssertTrue(json.contains("Alice"), "Expected value in JSON")
    }
}
