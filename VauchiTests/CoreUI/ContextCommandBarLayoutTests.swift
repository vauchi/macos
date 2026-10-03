// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// The context bar sits under the content beside the sidebar. It floated as a
// card, kept a button-sized hole for an absent slot, and offered "More"
// beside a sidebar listing the same destinations (vauchi/private#479).
// Where each of Core's slots goes is pure enough to assert without
// rendering, so `ContextCommandBarLayout` holds it and this file pins it.

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
        XCTAssertTrue(ContextCommandBarLayout.showsLabel(.info))
    }

    // MARK: - showsLabel(_:)

    /// On the desktop there is room for every word, so each role button
    /// writes its label beside the icon; the primary button is its label.
    func testEveryRoleButtonShowsItsLabel() {
        XCTAssertTrue(ContextCommandBarLayout.showsLabel(.navigation))
        XCTAssertTrue(ContextCommandBarLayout.showsLabel(.secondary))
        XCTAssertTrue(ContextCommandBarLayout.showsLabel(.back))
        XCTAssertFalse(ContextCommandBarLayout.showsLabel(.primary))
    }

    // MARK: - needsFlexibleGap(slots:)

    /// The primary button fills the row. Without one, a gap in its place
    /// keeps Back at the leading edge and the launchers at the trailing one.
    func testAGapStandsInForAMissingPrimary() {
        XCTAssertTrue(ContextCommandBarLayout.needsFlexibleGap(slots: [.back, .secondary]))
        XCTAssertTrue(ContextCommandBarLayout.needsFlexibleGap(slots: [.back]))
        XCTAssertFalse(ContextCommandBarLayout.needsFlexibleGap(slots: [.back, .primary, .secondary]))
    }
}
