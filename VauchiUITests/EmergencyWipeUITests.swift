// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Emergency Wipe from a seeded identity lands on Welcome, not on the wiped
// screens or a stale layout (vauchi/private#666: the shell kept its
// pre-wipe presentation state on ResetApplication).
//
// Finds Core's controls by their English labels: the shell gives Core's
// rows and buttons no identifiers, and this test is about one flow, not
// about whatever the walk happens to reach. A label Core renames fails the
// test with every label on screen printed, so the fix is one line.

import XCTest

final class EmergencyWipeUITests: XCTestCase {
    private var app: XCUIApplication!

    private enum Label {
        static let settings = "Settings"
        static let advanced = "Advanced"
        static let emergencyWipe = "Emergency Wipe"
        static let typeWipe = "Type WIPE to confirm"
        static let shredEverything = "Shred Everything"
        static let welcomeSubtitle = "Your contact card, shared in person and kept up to date."
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-for-testing"]
        app.launch()
        app.activate()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testEmergencyWipeLandsOnWelcome() {
        let destinations = app.descendants(matching: .any).matching(identifier: "navigationDestinations")
        XCTAssertTrue(destinations.firstMatch.waitForExistence(timeout: 15),
                      "--reset-for-testing should seed an identity and show the destinations")

        openDestination(Label.settings, destinations: destinations)
        click(Label.advanced)
        click(Label.emergencyWipe)
        type("WIPE", into: Label.typeWipe)
        click(Label.shredEverything)

        let welcome = app.staticTexts.matching(NSPredicate(format: "label == %@", Label.welcomeSubtitle))
        let landed = welcome.firstMatch.waitForExistence(timeout: 20)
        attachScreen(named: "after-wipe")
        XCTAssertTrue(landed, "After the wipe the app should show Welcome. On screen: \(labelsOnScreen())")
        XCTAssertFalse(destinations.firstMatch.exists,
                       "Welcome has no destinations; seeing them means the pre-wipe layout survived")
    }

    // MARK: - Driving

    private func openDestination(_ label: String, destinations: XCUIElementQuery) {
        let navigation = app.buttons["command.navigation"]
        if navigation.exists {
            navigation.click()
        }
        let button = destinations.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5),
                      "No '\(label)' destination. On screen: \(labelsOnScreen())")
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }

    private func click(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = hittableElement(labeled: label)
        guard let element else {
            attachScreen(named: "missing-\(label)")
            XCTFail("Nothing labelled '\(label)'. On screen: \(labelsOnScreen())", file: file, line: line)
            return
        }
        element.click()
    }

    /// A click focuses the field only while the window is key, which the CI
    /// host's launched window is not until activated (see
    /// `fillNameFieldIfPresent` in the screenshot walk).
    private func type(_ text: String, into label: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = app.textFields.matching(NSPredicate(format: "label == %@ OR placeholderValue == %@",
                                                        label, label)).firstMatch
        let target = field.waitForExistence(timeout: 5) ? field : app.textFields.firstMatch
        guard target.waitForExistence(timeout: 5) else {
            XCTFail("No text field for '\(label)'. On screen: \(labelsOnScreen())", file: file, line: line)
            return
        }
        app.activate()
        target.click()
        target.typeText(text)
    }

    /// Core's rows may render as buttons, cells or bare text; the first
    /// hittable match wins, scrolling down while none is.
    private func hittableElement(labeled label: String) -> XCUIElement? {
        let matches = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label))
        guard matches.firstMatch.waitForExistence(timeout: 10) else { return nil }
        for _ in 0 ..< 6 {
            let buttons = matches.matching(NSPredicate(format: "elementType == %d",
                                                       XCUIElement.ElementType.button.rawValue))
            if let hit = (buttons.allElementsBoundByIndex + matches.allElementsBoundByIndex)
                .first(where: \.isHittable)
            {
                return hit
            }
            app.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -300)
        }
        return nil
    }

    private func labelsOnScreen() -> [String] {
        app.descendants(matching: .any).allElementsBoundByIndex
            .map(\.label)
            .filter { !$0.isEmpty }
    }

    private func attachScreen(named name: String) {
        let window = app.windows.firstMatch
        let source: XCUIScreenshotProviding = window.exists ? window : XCUIScreen.main
        let attachment = XCTAttachment(screenshot: source.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
