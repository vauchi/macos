// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

@testable import Vauchi
import XCTest

final class PresentationSmokeTests: XCTestCase {
    #if canImport(VauchiPlatform)
        @MainActor
        func testAppStateSkipsNativeStartupInsideTestHost() {
            let appState = AppState()

            XCTAssertNil(appState.viewModel)
            XCTAssertNil(appState.error)
        }
    #endif

    func testBackEventUsesCanonicalReducerShape() throws {
        let data = try JSONEncoder().encode(
            PresentationEvent.backRequested(surfaceID: "detail")
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? NSDictionary
        )

        XCTAssertEqual(
            object,
            ["BackRequested": ["surface_id": "detail"]] as NSDictionary
        )
    }
}
