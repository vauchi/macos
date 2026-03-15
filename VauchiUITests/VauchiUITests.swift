// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// VauchiUITests.swift
// Automated UI tests for the macOS app.
// Uses XCUITest for end-to-end interaction testing.
// Based on: features/identity.feature, features/contact_exchange.feature

import XCTest

final class VauchiUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    // MARK: - App Launch

    func testAppLaunches() {
        XCTAssertTrue(app.state == .runningForeground, "App should launch and be in foreground")
    }

    func testAppWindowExists() {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists, "App should have a main window")
        XCTAssertTrue(window.frame.width > 0, "Window should have non-zero width")
        XCTAssertTrue(window.frame.height > 0, "Window should have non-zero height")
    }

    // MARK: - Accessibility Audit

    func testAccessibilityAudit() throws {
        // macOS 14+ XCUITest accessibility audit
        if #available(macOS 14.0, *) {
            try app.performAccessibilityAudit()
        }
    }
}
