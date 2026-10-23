// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Core holds content downloads back on a metered network and counts an
// unknown network as metered (private#733, D6), so only a path that is up
// and neither expensive nor constrained reports unmetered.
//
// Traces to: features/remote_content.feature

@testable import Vauchi
import VauchiPlatform
import XCTest

final class NetworkCostMonitorTests: XCTestCase {
    func testAnOpenPathThatIsNeitherExpensiveNorConstrainedIsUnmetered() {
        XCTAssertEqual(
            NetworkCostMonitor.cost(isSatisfied: true, isExpensive: false, isConstrained: false),
            .unmetered
        )
    }

    /// A Mac on an iPhone hotspot sees an expensive path.
    func testAnExpensivePathIsMetered() {
        XCTAssertEqual(
            NetworkCostMonitor.cost(isSatisfied: true, isExpensive: true, isConstrained: false),
            .metered
        )
    }

    func testAConstrainedPathIsMetered() {
        XCTAssertEqual(
            NetworkCostMonitor.cost(isSatisfied: true, isExpensive: false, isConstrained: true),
            .metered
        )
    }

    func testNoPathIsUnknown() {
        XCTAssertEqual(
            NetworkCostMonitor.cost(isSatisfied: false, isExpensive: false, isConstrained: false),
            .unknown
        )
    }
}
