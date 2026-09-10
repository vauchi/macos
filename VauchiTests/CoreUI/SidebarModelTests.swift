// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

@testable import Vauchi
import XCTest

final class SidebarModelTests: XCTestCase {
    private func item(
        id: String,
        label: String,
        selected: Bool,
        badgeCount: UInt32 = 0
    ) -> NavigationItem {
        NavigationItem(
            interactionID: id,
            label: label,
            accessibilityLabel: label,
            iconToken: "person.2",
            selected: selected,
            badgeCount: badgeCount
        )
    }

    func testRowsProjectEachNavigationItem() {
        let model = SidebarModel(navigation: NavigationSpec(items: [
            item(id: "nav.contacts", label: "Contacts", selected: true),
            item(id: "nav.groups", label: "Groups", selected: false, badgeCount: 3),
        ]))

        XCTAssertEqual(model.rows.map(\.interactionID), ["nav.contacts", "nav.groups"])
        XCTAssertEqual(model.rows[0].label, "Contacts")
        XCTAssertEqual(model.rows[1].badgeCount, 3)
    }

    func testSelectedIndexMatchesTheSelectedItem() {
        let model = SidebarModel(navigation: NavigationSpec(items: [
            item(id: "nav.contacts", label: "Contacts", selected: false),
            item(id: "nav.groups", label: "Groups", selected: true),
        ]))

        XCTAssertEqual(model.selectedIndex, 1)
        XCTAssertEqual(model.selectedID, "nav.groups")
    }

    func testSelectedIndexIsNilWhenCoreSelectsNoItem() {
        let model = SidebarModel(navigation: NavigationSpec(items: [
            item(id: "nav.contacts", label: "Contacts", selected: false),
        ]))

        XCTAssertNil(model.selectedIndex)
        XCTAssertNil(model.selectedID)
    }

    func testHiddenWhenNavigationHasNoItems() {
        XCTAssertTrue(SidebarModel(navigation: NavigationSpec(items: [])).isHidden)
        XCTAssertTrue(SidebarModel(navigation: nil).isHidden)
    }

    func testNotHiddenWhenNavigationHasItems() {
        let model = SidebarModel(navigation: NavigationSpec(items: [
            item(id: "nav.contacts", label: "Contacts", selected: true),
        ]))

        XCTAssertFalse(model.isHidden)
    }
}
