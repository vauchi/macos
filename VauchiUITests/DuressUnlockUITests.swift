// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// With an app password and a duress PIN set, the next launch stops on
// Core's lock screen, refuses a wrong PIN and opens on the duress PIN
// (vauchi/private#591: macOS used to drop Core's app-password requirement).
//
// The typed path only. The CI runner has no Touch ID, and XCUITest cannot
// fake a biometric success on macOS, so "Touch ID still asks for the PIN"
// stays a check on a Mac with a sensor.
//
// Finds Core's controls by their English labels, as EmergencyWipeUITests
// does, for the same reason: the shell gives Core's rows no identifiers.

import XCTest

final class DuressUnlockUITests: XCTestCase {
    private var app: XCUIApplication!

    private enum Label {
        static let settings = "Settings"
        static let advanced = "Advanced"
        static let changePassword = "Change Password"
        static let duressPin = "Duress PIN"
        static let setUpPin = "Set Up PIN"
        static let save = "Save"
        static let continueButton = "Continue"
        static let unlock = "Unlock"
    }

    private let appPassword = "correct horse 591"
    private let duressPin = "246813"
    private let wrongPin = "135792"

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

    func testTheNextLaunchAsksForThePasswordAndOpensOnTheDuressPin() {
        XCTAssertTrue(destinations.firstMatch.waitForExistence(timeout: 15),
                      "--reset-for-testing should seed an identity and show the destinations")

        // Both rows sit in Advanced's Security group, not on Settings itself.
        openDestination(Label.settings)
        click(Label.advanced)
        click(Label.changePassword)
        fillSecureFields(with: appPassword)
        click(Label.save)

        openDestination(Label.settings)
        click(Label.advanced)
        click(Label.duressPin)
        click(Label.setUpPin)
        fillSecureFields(with: duressPin)
        click(Label.continueButton)
        fillSecureFields(with: duressPin)
        click(Label.continueButton)
        attachScreen(named: "duress-set")

        // No testing flag: both flags wipe the store, password included.
        app.terminate()
        app.launchArguments = UITestLaunch.arguments()
        app.launch()
        app.activate()

        let lockField = app.secureTextFields.firstMatch
        XCTAssertTrue(lockField.waitForExistence(timeout: 15),
                      "The relaunch should stop on Core's lock screen. On screen: \(labelsOnScreen())")
        XCTAssertFalse(destinations.firstMatch.exists, "Locked, the app must not show its destinations")
        attachScreen(named: "locked")

        fillSecureFields(with: wrongPin)
        click(Label.unlock)
        XCTAssertTrue(app.secureTextFields.firstMatch.waitForExistence(timeout: 5),
                      "A wrong PIN should leave the lock screen up. On screen: \(labelsOnScreen())")
        XCTAssertFalse(destinations.firstMatch.waitForExistence(timeout: 3),
                       "A wrong PIN must not open the app")

        fillSecureFields(with: duressPin)
        click(Label.unlock)
        let opened = destinations.firstMatch.waitForExistence(timeout: 15)
        attachScreen(named: "after-duress-pin")
        XCTAssertTrue(opened, "The duress PIN should open the app. On screen: \(labelsOnScreen())")
    }

    // MARK: - Driving

    private var destinations: XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "navigationDestinations")
    }

    private func openDestination(_ label: String) {
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
        guard let element = hittableElement(labeled: label) else {
            attachScreen(named: "missing-\(label)")
            XCTFail("Nothing labelled '\(label)'. On screen: \(labelsOnScreen())", file: file, line: line)
            return
        }
        element.click()
    }

    /// Every password and PIN input on a screen takes the same value here:
    /// a new password and its confirmation, or the one field elsewhere.
    /// Typing waits for focus because the CI host's launched window is not
    /// key until activated (see `fillNameFieldIfPresent` in the walk).
    private func fillSecureFields(with text: String, file: StaticString = #filePath, line: UInt = #line) {
        let fields = app.secureTextFields
        guard fields.firstMatch.waitForExistence(timeout: 10) else {
            attachScreen(named: "no-secure-field")
            XCTFail("No password or PIN field. On screen: \(labelsOnScreen())", file: file, line: line)
            return
        }
        app.activate()
        for field in fields.allElementsBoundByIndex {
            field.click()
            field.typeText(text)
        }
    }

    /// Core's rows may render as buttons, cells or bare text; a button wins
    /// over text with the same label, scrolling down while none is hittable.
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
