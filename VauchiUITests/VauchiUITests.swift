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
        // The handler NEVER suppresses: it returns false for every issue, so
        // the audit fails on all of them exactly as the bare
        // `performAccessibilityAudit()` did. It only prints.
        //
        // That printing is the point. Left bare, this test reports
        // "Element has no description" and nothing else: the .xcresult
        // carries a screenshot of the element cropped to its own frame and
        // no identity for it, which cost two CI round trips to turn into a
        // name the first time it fired (2026-09-11, the window's
        // GeometryReader wrapper). Printing the element means the next
        // failure names itself.
        //
        // Do not turn this into a filter. The no-exclusions audit is a
        // deliberate regression guard (claude-errors-2026-03, E29) and
        // CC-21 applies before weakening any check.
        if #available(macOS 14.0, *) {
            // This run only: needed to see whether the AppKit change
            // altered the tree at all.
            print("A11Y-TREE-BEGIN\n\(app.debugDescription)\nA11Y-TREE-END")
            try app.performAccessibilityAudit { issue in
                print("""
                A11Y-AUDIT-ISSUE
                  type:     \(issue.auditType)
                  compact:  \(issue.compactDescription)
                  detailed: \(issue.detailedDescription)
                  element:  \(String(describing: issue.element))
                """)
                return false
            }
        }
    }
}
