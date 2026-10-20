// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Each row of a Core list is announced by its own words, not the list's
// title (vauchi/private#715: VoiceOver read "Privacy" for every row of
// Settings' Privacy section). Queries the live hierarchy (CC-20).
//
// Uses Core's English copy for the Settings rows, as the other UI tests do.
//
// Traces to: features/accessibility.feature

import XCTest

final class ListRowAccessibilityUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = UITestLaunch.arguments("--reset-for-testing")
        app.launch()
        app.activate()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testSettingsRowsAnnounceTheirOwnTitles() {
        let destinations = app.descendants(matching: .any).matching(identifier: "navigationDestinations")
        XCTAssertTrue(destinations.firstMatch.waitForExistence(timeout: 15),
                      "--reset-for-testing should seed an identity and show the destinations")
        destinations.buttons.matching(NSPredicate(format: "label == %@", "Settings")).firstMatch.click()

        let rowTitle = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR value == %@", "Delivery Receipts", "Delivery Receipts"))
            .firstMatch
        XCTAssertTrue(rowTitle.waitForExistence(timeout: 10),
                      "The Delivery Receipts row should be announced by its title. On screen: \(announced())")

        let rowControls = app.checkBoxes.matching(identifier: "presentationRowControl").allElementsBoundByIndex
        XCTAssertFalse(rowControls.isEmpty, "Settings should show its row toggles")
        XCTAssertFalse(rowControls.contains { $0.label == "Privacy" },
                       "A toggle must not be announced by its section's title. Toggles: \(rowControls.map(\.label))")
    }

    private func announced() -> [String] {
        app.descendants(matching: .any).allElementsBoundByIndex
            .map { "\($0.label)|\(String(describing: $0.value ?? ""))" }
            .filter { $0 != "|" }
    }
}
