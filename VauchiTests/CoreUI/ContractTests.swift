// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Contract tests: verify macOS decoders stay compatible with core's golden fixtures.
// No test references core action IDs — assertions are structural only.

import CoreUIModels
@testable import Vauchi
import XCTest

final class ContractTests: XCTestCase {
    // MARK: - Fixture Loading

    private static let fixturesURL: URL = {
        let testFileURL = URL(fileURLWithPath: #filePath)
        return testFileURL
            .deletingLastPathComponent() // CoreUI/
            .appendingPathComponent("fixtures/golden")
            .standardized
    }()

    private static var fixtureNames: [String] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: fixturesURL,
            includingPropertiesForKeys: nil
        )) ?? []
        return contents
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    private func loadFixture(_ name: String) throws -> ScreenModel {
        let url = Self.fixturesURL.appendingPathComponent("\(name).json")
        let data = try Data(contentsOf: url)
        return try coreJSONDecoder.decode(ScreenModel.self, from: data)
    }

    // MARK: - Contract Decode Tests

    func testAllGoldenFixturesDecodeAsScreenModel() throws {
        XCTAssertGreaterThanOrEqual(
            Self.fixtureNames.count, 20,
            "Expected at least 20 golden fixtures, found \(Self.fixtureNames.count)"
        )
        for name in Self.fixtureNames {
            let screen = try loadFixture(name)
            XCTAssertFalse(screen.screenId.isEmpty, "Fixture '\(name)': screen_id must not be empty")
        }
    }

    func testAllActionsHaveNonEmptyLabels() throws {
        for name in Self.fixtureNames {
            let screen = try loadFixture(name)
            for action in screen.actions {
                XCTAssertFalse(action.label.isEmpty, "Fixture '\(name)': action '\(action.id)' has empty label")
                XCTAssertFalse(action.id.isEmpty, "Fixture '\(name)': action has empty id")
            }
        }
    }

    func testNoFixtureProducesUnknownComponents() throws {
        for name in Self.fixtureNames {
            let screen = try loadFixture(name)
            for component in screen.components {
                if case .unknown = component {
                    XCTFail("Fixture '\(name)': unexpected unknown component")
                }
            }
        }
    }

    // MARK: - Version Linkage

    func testVersionMetadataMatchesFixtureCount() throws {
        let versionURL = Self.fixturesURL.appendingPathComponent(".version")
        let data = try Data(contentsOf: versionURL)
        let meta = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(meta?["core_version"], ".version must have core_version")
        let schemaVersion = meta?["schema_version"] as? Int
        XCTAssertNotNil(schemaVersion, ".version must have schema_version")
        XCTAssertGreaterThanOrEqual(schemaVersion ?? 0, 1)

        let fixtureCount = meta?["fixture_count"] as? Int
        XCTAssertEqual(
            fixtureCount, Self.fixtureNames.count,
            ".version fixture_count must match actual count"
        )
    }
}
