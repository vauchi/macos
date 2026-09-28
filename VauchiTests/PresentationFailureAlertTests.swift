// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// A presentation failure reaches the user as Core-localized copy, never as
// the error's own description (vauchi/private#308 Defect 2: the alert used
// to print `String(describing: error)`; ADR-045 Amendment 1, DC-05).
// Pure — no engine — so it runs in the XCTest host, unlike the
// Keychain-bound AppViewModel tests.
//
// Traces to: features/generic_presentation_protocol.feature

@testable import Vauchi
import XCTest

@MainActor
final class PresentationFailureAlertTests: XCTestCase {
    private struct InternalDetailError: Error, CustomStringConvertible {
        var description: String {
            "InvalidInput(field: \"\", detail: \"surface is not active\")"
        }
    }

    func testFailureAlertUsesCoreLocalizedCopy() {
        let alert = AppViewModel.presentationFailureAlert(for: InternalDetailError())

        XCTAssertEqual(alert.title, LocalizationService.shared.t("error.title"))
        XCTAssertEqual(alert.message, LocalizationService.shared.t("error.generic"))
        XCTAssertNotEqual(alert.message, "error.generic", "copy must resolve, not echo the key")
        XCTAssertFalse(alert.message.contains("surface is not active"),
                       "the error's own text must not reach the user: \(alert.message)")
    }
}
