// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// The context bar no longer draws a row of its own under the content: Back
// and Navigate sit at the leading end of the surface's title row, Actions
// and Info at the trailing end, and Primary becomes a full-width button at
// the bottom of the surface (vauchi/private#479, #534). Where each of
// Core's slots goes is pure enough to assert without rendering, so
// `ContextCommandBarLayout` holds it and this file pins it.

import SwiftUI
@testable import Vauchi
import XCTest

final class ContextCommandBarLayoutTests: XCTestCase {
    /// `PresentationAction` only decodes, as it does from Core's batch.
    private func action(_ interactionID: String) -> PresentationAction? {
        let json = """
        {"interaction_id":"\(interactionID)","label":"Label",
         "accessibility_label":"Label","enabled":true}
        """
        return try? JSONDecoder().decode(PresentationAction.self, from: Data(json.utf8))
    }

    private func bar(
        back: Bool = false,
        navigation: Bool = false,
        primary: Bool = false,
        secondary: Bool = false,
        info: Bool = false
    ) -> PresentationContextBar {
        PresentationContextBar(
            back: back ? action("back") : nil,
            navigation: navigation ? action("navigation") : nil,
            primary: primary ? action("primary") : nil,
            secondary: secondary ? action("secondary") : nil,
            info: info ? action("info") : nil
        )
    }

    // MARK: - slots(bar:)

    func testSlotsKeepTheOrderCoreSendsThemIn() {
        XCTAssertEqual(
            ContextCommandBarLayout.slots(
                bar: bar(back: true, navigation: true, primary: true, secondary: true)
            ),
            [.back, .navigation, .primary, .secondary]
        )
    }

    func testAnAbsentSlotIsLeftOutRatherThanHeldOpen() {
        XCTAssertEqual(
            ContextCommandBarLayout.slots(bar: bar(navigation: true, primary: true, secondary: true)),
            [.navigation, .primary, .secondary]
        )
        XCTAssertEqual(
            ContextCommandBarLayout.slots(bar: bar(back: true)),
            [.back]
        )
    }

    /// The launcher opens the same destinations the tab bar shows; two
    /// controls for one list is what readers tripped over.
    func testTheNavigationLauncherIsLeftOutWhileTheNavigationIsOnScreen() {
        let full = bar(back: true, navigation: true, primary: true, secondary: true)

        XCTAssertEqual(
            ContextCommandBarLayout.slots(bar: full, navigationShown: true),
            [.back, .primary, .secondary]
        )
        XCTAssertEqual(
            ContextCommandBarLayout.slots(bar: full, navigationShown: false),
            [.back, .navigation, .primary, .secondary]
        )
    }

    func testNoBarAndABarWithNoActionsDrawNothing() {
        XCTAssertEqual(ContextCommandBarLayout.slots(bar: nil), [])
        XCTAssertEqual(ContextCommandBarLayout.slots(bar: bar()), [])
    }

    /// Core's fifth slot explains the surface (vauchi/private#479); it sits
    /// after Actions, and an older batch without it changes nothing.
    func testTheInfoSlotComesLastAndOnlyWhenCoreSendsIt() {
        XCTAssertEqual(
            ContextCommandBarLayout.slots(bar: bar(back: true, primary: true, secondary: true, info: true)),
            [.back, .primary, .secondary, .info]
        )
        XCTAssertEqual(
            ContextCommandBarLayout.slots(bar: bar(primary: true, secondary: true)),
            [.primary, .secondary]
        )
    }

    // MARK: - leadingTitleSlots(bar:navigationShown:)

    /// Back and Navigate move into the title row's leading end, in the
    /// same order the retired bar drew them (vauchi/private#479, #534).
    func testLeadingTitleSlotsAreBackThenNavigation() {
        XCTAssertEqual(
            ContextCommandBarLayout.leadingTitleSlots(
                bar: bar(back: true, navigation: true, primary: true, secondary: true, info: true)
            ),
            [.back, .navigation]
        )
    }

    func testLeadingTitleSlotsDropNavigationWhileItIsOnScreen() {
        let full = bar(back: true, navigation: true)
        XCTAssertEqual(
            ContextCommandBarLayout.leadingTitleSlots(bar: full, navigationShown: true),
            [.back]
        )
        XCTAssertEqual(
            ContextCommandBarLayout.leadingTitleSlots(bar: full, navigationShown: false),
            [.back, .navigation]
        )
    }

    /// Primary moved to the bottom of the surface, and Actions/Info sit at
    /// the title row's trailing end instead — neither belongs leading.
    func testLeadingTitleSlotsNeverCarryPrimaryOrTrailingActions() {
        let full = bar(back: true, navigation: true, primary: true, secondary: true, info: true)
        let leading = ContextCommandBarLayout.leadingTitleSlots(bar: full)
        XCTAssertFalse(leading.contains(.primary))
        XCTAssertFalse(leading.contains(.secondary))
        XCTAssertFalse(leading.contains(.info))
    }

    // MARK: - trailingTitleSlots(bar:)

    /// Actions and Info move into the title row's trailing end, in the
    /// same order the retired bar drew them.
    func testTrailingTitleSlotsAreActionsThenInfo() {
        XCTAssertEqual(
            ContextCommandBarLayout.trailingTitleSlots(
                bar: bar(back: true, navigation: true, primary: true, secondary: true, info: true)
            ),
            [.secondary, .info]
        )
    }

    func testTrailingTitleSlotsNeverCarryPrimaryOrLeadingActions() {
        let full = bar(back: true, navigation: true, primary: true, secondary: true, info: true)
        let trailing = ContextCommandBarLayout.trailingTitleSlots(bar: full)
        XCTAssertFalse(trailing.contains(.primary))
        XCTAssertFalse(trailing.contains(.back))
        XCTAssertFalse(trailing.contains(.navigation))
    }

    // MARK: - accessibilityIdentifier(for:)

    /// Stable frontend a11y anchor for UI tests, matching the iOS shell's
    /// `command.*` identifiers — unchanged by the move into the title row.
    func testEverySlotKeepsItsStableAccessibilityIdentifier() {
        XCTAssertEqual(ContextCommandBarLayout.accessibilityIdentifier(for: .back), "command.back")
        XCTAssertEqual(ContextCommandBarLayout.accessibilityIdentifier(for: .navigation), "command.navigation")
        XCTAssertEqual(ContextCommandBarLayout.accessibilityIdentifier(for: .primary), "command.primary")
        XCTAssertEqual(ContextCommandBarLayout.accessibilityIdentifier(for: .secondary), "command.secondary")
        XCTAssertEqual(ContextCommandBarLayout.accessibilityIdentifier(for: .info), "command.info")
    }

    // MARK: - keyboardShortcut(for:)

    /// Keyboard shortcuts stay as they are; only where the button draws
    /// changed (vauchi/private#534).
    func testEachTitleRowSlotKeepsItsKeyboardShortcut() {
        XCTAssertEqual(ContextCommandBarLayout.keyboardShortcut(for: .back).key, KeyEquivalent("["))
        XCTAssertEqual(ContextCommandBarLayout.keyboardShortcut(for: .navigation).key, KeyEquivalent("k"))
        XCTAssertEqual(ContextCommandBarLayout.keyboardShortcut(for: .navigation).modifiers, .command)
        XCTAssertEqual(ContextCommandBarLayout.keyboardShortcut(for: .secondary).key, .downArrow)
        XCTAssertEqual(ContextCommandBarLayout.keyboardShortcut(for: .secondary).modifiers, .option)
        XCTAssertEqual(ContextCommandBarLayout.keyboardShortcut(for: .info).key, KeyEquivalent("?"))
    }
}
