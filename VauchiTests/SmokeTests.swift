// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// SmokeTests.swift
// Basic smoke tests for the macOS app

@testable import Vauchi
import XCTest

final class SmokeTests: XCTestCase {
    #if canImport(VauchiPlatform)
        func testOnboardingViewModelInitialState() {
            let viewModel = OnboardingViewModel()
            XCTAssertNotNil(viewModel.currentScreen, "OnboardingViewModel should load initial screen from core")
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

    func testUserActionEncoding() throws {
        let action = UserAction.textChanged(componentId: "name", value: "Alice")
        let data = try coreJSONEncoder.encode(action)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("TextChanged"), "Expected PascalCase variant key")
        XCTAssertTrue(json.contains("component_id"), "Expected snake_case field key")
        XCTAssertTrue(json.contains("Alice"), "Expected value in JSON")
    }
}
