// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

@testable import Vauchi
import XCTest

/// Core reads an input value as `{"text": …}`, `{"boolean": …}`,
/// `{"choice": …}` or `{"number": …}` (its `InputValue` is snake_case).
/// Capitalised keys failed to parse, and Core answered every typed or
/// toggled value with "Something went wrong" (vauchi/private#719; iOS fixed
/// the same mistake in f6b46e2).
final class PresentationInputValueEncodingTests: XCTestCase {
    private func encodedValue(_ value: PresentationInputValue) throws -> NSDictionary {
        let data = try JSONEncoder().encode(
            PresentationEvent.valueChanged(surfaceID: "s", bindingID: "b", value: value)
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let payload = try XCTUnwrap(object["ValueChanged"] as? NSDictionary)
        return try XCTUnwrap(payload["value"] as? NSDictionary)
    }

    func testEachValueKindUsesCoresSnakeCaseKey() throws {
        XCTAssertEqual(try encodedValue(.text("x")), ["text": "x"] as NSDictionary)
        XCTAssertEqual(try encodedValue(.boolean(true)), ["boolean": true] as NSDictionary)
        XCTAssertEqual(try encodedValue(.choice("c")), ["choice": "c"] as NSDictionary)
        XCTAssertEqual(try encodedValue(.number(2.5)), ["number": 2.5] as NSDictionary)
    }

    func testAnEmptyTextStaysAnEmptyText() throws {
        XCTAssertEqual(try encodedValue(.text("")), ["text": ""] as NSDictionary)
    }
}
