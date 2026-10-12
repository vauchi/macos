// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

/// The vauchi.app/x landing page's "Open in Vauchi" button and every shared
/// `vauchi://` link must reach the installed app (vauchi/private#650). The
/// app must declare the scheme for macOS to route the link to it at all.
///
/// The tests run hosted in the app, so `Bundle.main` is the built
/// `Vauchi.app` and this reads the shipped Info.plist, not a source file.
final class URLSchemeContractTests: XCTestCase {
    func testTheAppDeclaresTheVauchiURLScheme() throws {
        let urlTypes = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]],
            "Vauchi.app declares no CFBundleURLTypes"
        )

        let schemes = urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        XCTAssertEqual(schemes, ["vauchi"])
    }
}
