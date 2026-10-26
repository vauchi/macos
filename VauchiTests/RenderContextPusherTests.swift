// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Pins the JSON `buildRenderContextJson` sends to core's
// `setRenderContextJson`. On "Follow system" no `locale` is sent, so core
// rendered English until the OS language travelled as `system_locale`
// (vauchi/private#721).

@testable import Vauchi
import XCTest

final class RenderContextPusherTests: XCTestCase {
    private func parse(_ json: String) throws -> [String: String] {
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        return try XCTUnwrap(object as? [String: String])
    }

    func testFollowingTheSystemSendsTheSystemLanguageAndNoPickedLanguage() throws {
        let json = try parse(buildRenderContextJson(locale: nil, systemLocale: "fr-CH", restorableState: nil))

        XCTAssertEqual(json, ["system_locale": "fr-CH"])
    }

    func testAPickedLanguageStillTravelsWithTheSystemLanguage() throws {
        let json = try parse(buildRenderContextJson(locale: "de", systemLocale: "fr-CH", restorableState: nil))

        XCTAssertEqual(json, ["locale": "de", "system_locale": "fr-CH"])
    }

    func testAnUnknownSystemLanguageIsLeftOut() throws {
        let json = try parse(buildRenderContextJson(locale: "de", systemLocale: nil, restorableState: nil))

        XCTAssertEqual(json, ["locale": "de"])
    }

    func testAQuoteOrBackslashInTheSystemTagStaysInsideItsString() throws {
        let json = try parse(buildRenderContextJson(locale: nil, systemLocale: "x\"\\y", restorableState: nil))

        XCTAssertEqual(json, ["system_locale": "x\"\\y"])
    }

    func testTheKeptRestorableStateTravelsInEveryPush() throws {
        let json = try parse(buildRenderContextJson(
            locale: nil,
            systemLocale: "fr-CH",
            restorableState: #"{"v":1,"locale":"de"}"#
        ))

        XCTAssertEqual(json, ["system_locale": "fr-CH", "restorable_state": #"{"v":1,"locale":"de"}"#])
    }

    func testNoKeptStateSendsNoRestorableStateKey() throws {
        let json = try parse(buildRenderContextJson(
            locale: nil,
            systemLocale: nil,
            restorableState: nil
        ))

        XCTAssertEqual(json, [:])
    }

    /// Core owns the state's content, so a control character must not break
    /// the push the shell builds around it.
    func testAControlCharacterInTheKeptStateStaysInsideItsString() throws {
        let json = try parse(buildRenderContextJson(
            locale: nil,
            systemLocale: nil,
            restorableState: "a\nb\u{0}c\td"
        ))

        XCTAssertEqual(json, ["restorable_state": "a\nb\u{0}c\td"])
    }
}
