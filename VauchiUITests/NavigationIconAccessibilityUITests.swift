// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Structural accessibility tests for the navigation overlay — queries the
// live view hierarchy, never a compile-time constant (CC-20).
//
// These need a real Aqua session to launch a test host, which the macOS
// runner has (`test:unit` fails fast when the console session is switched
// out). They are the only way to observe what VoiceOver would actually
// stop on: the same defect is invisible to unit tests, and Apple's own
// accessibility audit passes straight through it.
//
// Traces to: features/accessibility.feature

import XCTest

final class NavigationIconAccessibilityUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-for-testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// An SF Symbol name, e.g. `person.crop.rectangle.fill` — lowercase
    /// segments joined by dots, which no human-facing label ever is.
    private func looksLikeSymbolName(_ label: String) -> Bool {
        let pattern = "^[a-z][a-z0-9]*(\\.[a-z0-9]+)+$"
        return label.range(of: pattern, options: .regularExpression) != nil
    }

    /// Opens the navigation overlay via the command bar and returns its
    /// destination container.
    private func openNavigationDestinations() -> XCUIElement {
        let destinations = app.descendants(matching: .any)
            .matching(identifier: "navigationDestinations")
            .firstMatch
        if !destinations.exists {
            let navigationCommand = app.buttons["command.navigation"]
            XCTAssertTrue(navigationCommand.waitForExistence(timeout: 10),
                          "Navigation command should exist on the main surface")
            navigationCommand.click()
        }
        return destinations
    }

    /// Each destination shows an icon beside its word. The icon repeats what
    /// the word already says, so it must be decorative — otherwise VoiceOver
    /// stops on it and reads a second, separate thing.
    ///
    /// Left exposed, SwiftUI supplies the announcement itself, and both of
    /// its answers are wrong. For a symbol Apple has not described it reads
    /// the raw identifier: "person dot crop dot rectangle dot fill". For one
    /// it has, it reads a generic verb with no idea of the context —
    /// `folder.fill` beside "Groups" announces "Move", `key.fill` beside
    /// "Recovery" announces "Passwords", and `mappin.and.ellipse` beside
    /// "Places" announces "Remove Map Pin", naming a destructive action on a
    /// row that only navigates.
    func testNavigationIconsAreNotSeparateElements() {
        let destinations = openNavigationDestinations()
        XCTAssertTrue(destinations.waitForExistence(timeout: 10),
                      "Navigation destinations should be reachable from the command bar")

        XCTAssertEqual(destinations.images.count, 0,
                       "Destination icons must be decorative — VoiceOver should stop on "
                           + "the row, not on the row and then its icon")
    }

    /// The label-shaped half of the same defect: whatever elements the
    /// overlay does expose, none of them may be announcing an SF Symbol
    /// identifier. Kept separate from the element-count check so a future
    /// refactor that changes the element *type* cannot quietly reintroduce
    /// the gibberish announcement.
    func testNoDestinationAnnouncesASymbolIdentifier() {
        let destinations = openNavigationDestinations()
        XCTAssertTrue(destinations.waitForExistence(timeout: 10),
                      "Navigation destinations should be reachable from the command bar")

        let offenders = destinations.descendants(matching: .any)
            .allElementsBoundByIndex
            .map(\.label)
            .filter(looksLikeSymbolName)

        XCTAssertTrue(offenders.isEmpty,
                      "These read back as SF Symbol identifiers: \(offenders)")
    }
}
