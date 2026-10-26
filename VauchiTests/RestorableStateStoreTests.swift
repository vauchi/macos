// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// The Mac keeps Core's opaque restorable state outside the vault and hands
// it back in every render-context push, so a language or theme pick applies
// before storage opens (Core 0.90.0, vauchi/private#814).

@testable import Vauchi
import XCTest

final class RestorableStateStoreTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "RestorableStateStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testAKeptValueComesBackUnchanged() {
        RestorableStateStore(defaults: defaults).keep(#"{"v":1,"locale":"de"}"#)

        XCTAssertEqual(RestorableStateStore(defaults: defaults).state, #"{"v":1,"locale":"de"}"#)
    }

    func testNothingKeptHandsBackNothing() {
        XCTAssertNil(RestorableStateStore(defaults: defaults).state)
    }

    func testAValueOverFourKibibytesIsNotHandedBack() {
        let store = RestorableStateStore(defaults: defaults)

        store.keep(String(repeating: "a", count: 4097))
        XCTAssertNil(store.state)

        store.keep(String(repeating: "a", count: 4096))
        XCTAssertEqual(store.state?.utf8.count, 4096)
    }
}
