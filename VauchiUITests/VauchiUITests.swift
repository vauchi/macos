// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Automated UI tests for the macOS app.
// Uses XCUITest for end-to-end interaction testing.
// Based on: features/identity.feature, features/contact_exchange.feature

import XCTest

final class VauchiUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = UITestLaunch.arguments()
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
        // macOS 14+ XCUITest accessibility audit.
        //
        // The handler collects every issue and the test fails once on the
        // list, instead of failing on the first: the audit stops at its
        // first failed issue, which hid one finding behind another for
        // several CI runs (vauchi/private#722, pipeline 2968737205).
        //
        // Each issue is printed because the .xcresult carries only a
        // screenshot cropped to the element and no identity for it, which
        // cost two CI round trips to turn into a name the first time it
        // fired (2026-09-11, the window's GeometryReader wrapper).
        //
        // `isAppKitChrome` exempts exactly two elements the app does not
        // draw and cannot describe; every other issue still fails. Do not
        // widen it: the audit is a deliberate regression guard
        // (claude-errors-2026-03, E29) and CC-21 applies before weakening
        // any check.
        if #available(macOS 14.0, *) {
            var issues: [String] = []
            try app.performAccessibilityAudit { issue in
                print("""
                A11Y-AUDIT-ISSUE
                  type:     \(issue.auditType)
                  compact:  \(issue.compactDescription)
                  detailed: \(issue.detailedDescription)
                  element:  \(String(describing: issue.element))
                """)
                if !self.isAppKitChrome(issue) {
                    issues.append("\(issue.compactDescription): \(String(describing: issue.element))")
                }
                return true
            }
            XCTAssertEqual(issues, [], "accessibility audit issues")
        }
    }

    /// AppKit's own window chrome, flagged on the macOS CI host in pipeline
    /// 2968737205 (vauchi/private#722): the Group inside the title bar's
    /// full-screen button (Parent/Child mismatch) and a TouchBar element on
    /// a Mac without a Touch Bar (no description).
    @available(macOS 14.0, *)
    private func isAppKitChrome(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        guard let element = issue.element else { return false }
        switch issue.auditType {
        case .parentChild:
            let fullScreenButton = app.windows.firstMatch.buttons["_XCUI:FullScreenWindow"]
            return fullScreenButton.exists && fullScreenButton.frame.contains(element.frame)
        case .sufficientElementDescription:
            return element.elementType == .touchBar
        default:
            return false
        }
    }
}
