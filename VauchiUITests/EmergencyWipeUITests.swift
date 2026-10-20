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
        app.launchArguments = UITestLaunch.arguments("--reset-for-testing")
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

        let welcome = app.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@",
                                                           Label.welcomeSubtitle, Label.welcomeSubtitle))
        let landed = welcome.firstMatch.waitForExistence(timeout: 20)
        attachScreen(named: "after-wipe")
        XCTAssertTrue(landed, "After the wipe the app should show Welcome. On screen: \(labelsOnScreen())")
        // Onboarding has its own one-entry navigation ("Welcome"); what must
        // not survive is the seeded identity's.
        let survivors = ["Contacts", "My Card", "Exchange", "Devices", Label.settings].filter { label in
            destinations.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch.exists
        }
        XCTAssertEqual(survivors, [], "The pre-wipe destinations survived the wipe. On screen: \(labelsOnScreen())")
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
        guard focus(target) else {
            attachScreen(named: "no-focus-\(label)")
            XCTFail("'\(label)' never took keyboard focus", file: file, line: line)
            return
        }
        target.typeText(text)
    }

    /// A click on the window's title bar makes it key without pressing
    /// anything in its content, which on this screen holds the wipe button.
    private func focus(_ field: XCUIElement) -> Bool {
        app.activate()
        field.click()
        if !hasKeyboardFocus(field) {
            app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02)).click()
            field.click()
        }
        return hasKeyboardFocus(field)
    }

    private func hasKeyboardFocus(_ element: XCUIElement) -> Bool {
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        let expectation = XCTNSPredicateExpectation(predicate: focused, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 2) == .completed
    }

    /// Core's rows may render as buttons, cells or bare text; the first
    /// hittable match wins, scrolling down while none is.
    /// A Core row's title is its text's value; a control's is its label.
    /// Scrolls the view that holds the match, not the sidebar's.
    private func hittableElement(labeled label: String) -> XCUIElement? {
        let titled = NSPredicate(format: "label == %@ OR value == %@", label, label)
        let matches = app.descendants(matching: .any).matching(titled)
        guard matches.firstMatch.waitForExistence(timeout: 10) else { return nil }
        let scrollView = app.scrollViews.containing(titled).firstMatch
        for _ in 0 ..< 6 {
            let buttons = matches.matching(NSPredicate(format: "elementType == %d",
                                                       XCUIElement.ElementType.button.rawValue))
            if let hit = (buttons.allElementsBoundByIndex + matches.allElementsBoundByIndex)
                .first(where: \.isHittable)
            {
                return hit
            }
            scrollView.scroll(byDeltaX: 0, deltaY: -300)
        }
        return nil
    }

    private func labelsOnScreen() -> [String] {
        app.descendants(matching: .any).allElementsBoundByIndex
            .map { $0.label.isEmpty ? ($0.value as? String ?? "") : $0.label }
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
