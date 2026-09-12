// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

@testable import Vauchi
import XCTest

/// The design canvas draws a short Choice (Perspective "Their Info / My
/// Info for Them", Groups "Members / Visibility") as a segmented control
/// and a long one (Theme, 15 entries) as a menu. The threshold lives on the
/// node so the view stays a straight switch.
final class PresentationChoiceNodeTests: XCTestCase {
    private func choice(optionCount: Int) throws -> PresentationChoiceNode {
        let options = (0 ..< optionCount)
            .map { #"{"id":"o\#($0)","label":"Option \#($0)"}"# }
            .joined(separator: ",")
        let json = """
        {"binding_id":"mode","label":"Mode","selected":null,\
        "options":[\(options)],"enabled":true,"accessibility":{"label":"Mode"}}
        """
        return try JSONDecoder().decode(PresentationChoiceNode.self, from: Data(json.utf8))
    }

    func testTwoAndThreeOptionsPreferASegmentedControl() throws {
        XCTAssertTrue(try choice(optionCount: 2).prefersSegmentedControl)
        XCTAssertTrue(try choice(optionCount: 3).prefersSegmentedControl)
    }

    /// Fifteen theme names do not fit a segmented control's row; one option
    /// has nothing to segment.
    func testLongAndDegenerateListsKeepTheMenu() throws {
        XCTAssertFalse(try choice(optionCount: 1).prefersSegmentedControl)
        XCTAssertFalse(try choice(optionCount: 4).prefersSegmentedControl)
        XCTAssertFalse(try choice(optionCount: 15).prefersSegmentedControl)
    }
}
