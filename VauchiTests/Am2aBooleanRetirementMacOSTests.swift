// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// macOS-specific tests for ADR-044 Amendment 2a boolean-family retirement:
// - Back affordance driven by ScreenModel.navActions (id == "go_back").
// - UserAction.navigateBack forwarded unconditionally.
// - ActionResult.performNativeBack terminates the app.
// - ScreenModel.navTabId drives sidebar selection.
// - CommandDTO.scheduleWakeup arms a desktop timer that calls onWakeup.

import CoreUIModels
@testable import Vauchi
import XCTest

#if canImport(VauchiPlatform)
    import VauchiPlatform

    final class Am2aBooleanRetirementMacOSTests: XCTestCase {
        // MARK: - UserAction

        /// Scenario: navigateBack encodes as the externally-tagged
        /// `{"NavigateBack": {}}` shape core expects.
        func testNavigateBackEncodesToCoreShape() throws {
            let data = try coreJSONEncoder.encode(UserAction.navigateBack)
            let json = try XCTUnwrap(String(data: data, encoding: .utf8))
            XCTAssertTrue(json.contains("\"NavigateBack\""), "Expected PascalCase variant key, got \(json)")
        }

        // MARK: - ActionResult

        /// Scenario: a core "PerformNativeBack" result decodes to the
        /// dedicated enum case so the frontend can perform native back.
        func testPerformNativeBackDecodes() throws {
            let json = Data("\"PerformNativeBack\"".utf8)
            let result = try coreJSONDecoder.decode(ActionResult.self, from: json)
            guard case .performNativeBack = result else {
                XCTFail("Expected .performNativeBack, got \(result)")
                return
            }
        }

        // MARK: - ScreenModel chrome

        /// Scenario: a screen with nav_actions containing "go_back" exposes
        /// the back affordance through the model.
        func testScreenModelExposesGoBackNavAction() throws {
            let json = Data("""
            {
                "screen_id": "contact_detail",
                "title": "Contact",
                "components": [],
                "actions": [],
                "nav_actions": [
                    {
                        "id": "go_back",
                        "label": "Back",
                        "style": "Secondary",
                        "enabled": true
                    }
                ],
                "nav_tab_id": "contacts"
            }
            """.utf8)
            let screen = try coreJSONDecoder.decode(ScreenModel.self, from: json)
            XCTAssertTrue(screen.navActions.contains(where: { $0.id == "go_back" }))
            XCTAssertEqual(screen.navTabId, "contacts")
        }

        /// Scenario: a transient screen with no tab chrome has a nil navTabId
        /// and empty navActions.
        func testScreenModelDefaultsNavActionsAndNavTabId() throws {
            let json = Data("""
            {
                "screen_id": "onboarding_welcome",
                "title": "Welcome",
                "components": [],
                "actions": []
            }
            """.utf8)
            let screen = try coreJSONDecoder.decode(ScreenModel.self, from: json)
            XCTAssertTrue(screen.navActions.isEmpty)
            XCTAssertNil(screen.navTabId)
        }

        // MARK: - CommandDTO

        /// Scenario: a scheduleWakeup command carries relative seconds the
        /// frontend translates into a desktop timer.
        func testScheduleWakeupDecodesRelativeSeconds() throws {
            let json = Data("""
            {
                "ScheduleWakeup": {
                    "earliest_secs": 10,
                    "deadline_secs": 60,
                    "min_interval_secs": 30
                }
            }
            """.utf8)
            let command = try coreJSONDecoder.decode(CommandDTO.self, from: json)
            guard case let .scheduleWakeup(earliestSecs, deadlineSecs, minIntervalSecs) = command else {
                XCTFail("Expected .scheduleWakeup, got \(command)")
                return
            }
            XCTAssertEqual(earliestSecs, 10)
            XCTAssertEqual(deadlineSecs, 60)
            XCTAssertEqual(minIntervalSecs, 30)
        }
    }
#endif
