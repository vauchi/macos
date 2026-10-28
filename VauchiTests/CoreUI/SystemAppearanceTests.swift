// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// "Follow system" needs the Mac's own light/dark setting, which the window
// stops showing once it takes the theme's style (vauchi/private#814).

import AppKit
@testable import Vauchi
import XCTest

final class SystemAppearanceTests: XCTestCase {
    /// @internal
    func testEveryDarkAppearanceReportsDarkAndEveryOtherLight() throws {
        let cases: [(NSAppearance.Name, PresentationColorScheme)] = [
            (.aqua, .light),
            (.darkAqua, .dark),
            (.vibrantLight, .light),
            (.vibrantDark, .dark),
            (.accessibilityHighContrastAqua, .light),
            (.accessibilityHighContrastDarkAqua, .dark),
        ]
        for (name, expected) in cases {
            let appearance = try XCTUnwrap(NSAppearance(named: name), name.rawValue)
            XCTAssertEqual(SystemAppearance.scheme(of: appearance), expected, name.rawValue)
        }
    }
}
