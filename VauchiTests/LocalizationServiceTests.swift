// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// LocalizationServiceTests.swift
// Unit tests for the macOS LocalizationService wrapper over vauchi-platform i18n.

@testable import Vauchi
import XCTest

#if canImport(VauchiPlatform)
    import VauchiPlatform

    final class LocalizationServiceTests: XCTestCase {
        /// Scenario: the shared instance is a singleton.
        /// Given multiple calls to LocalizationService.shared
        /// Then they return the same reference.
        func test_shared_is_singleton() {
            let first = LocalizationService.shared
            let second = LocalizationService.shared

            XCTAssertTrue(first === second, "LocalizationService.shared must be a singleton")
        }

        /// Scenario: the service exposes at least one available locale.
        /// Given the service is initialized
        /// Then availableLocales includes English.
        func test_available_locales_includes_english() {
            let service = LocalizationService.shared

            XCTAssertFalse(
                service.availableLocales.isEmpty,
                "Should expose at least one locale from core"
            )
            XCTAssertTrue(
                service.availableLocales.contains(where: { $0.code == "en" }),
                "English must be one of the available locales"
            )
        }

        /// Scenario: a known key looks up the English translation.
        /// Given the current locale is English (default)
        /// When t("app.name") is called
        /// Then it returns "Vauchi".
        func test_t_returns_english_for_known_key() {
            let service = LocalizationService(defaults: makeEphemeralDefaults())
            service.selectLocale(.english)

            XCTAssertEqual(
                service.t("app.name"),
                "Vauchi",
                "app.name should resolve to the English value"
            )
        }

        /// Scenario: a missing key falls back to the raw key.
        /// Given a key that does not exist in any locale
        /// When t(key) is called
        /// Then it returns the key itself (core's documented fallback).
        func test_t_missing_key_falls_back_to_key() {
            let service = LocalizationService(defaults: makeEphemeralDefaults())

            let missing = "this.key.should.not.exist.in.any.locale"
            XCTAssertEqual(
                service.t(missing),
                missing,
                "Missing keys must fall back to the raw key for debuggability"
            )
        }

        /// Scenario: argument interpolation substitutes {name} placeholders.
        /// Given a key with a {count} placeholder
        /// When t(key, args: ["count": "3"]) is called
        /// Then the returned string contains "3" and not the literal "{count}".
        func test_t_with_args_interpolates() {
            let service = LocalizationService(defaults: makeEphemeralDefaults())
            service.selectLocale(.english)

            let out = service.t("import_contacts.result_imported", args: ["count": "3"])

            XCTAssertTrue(out.contains("3"), "Interpolated value should appear in output")
            XCTAssertFalse(
                out.contains("{count}"),
                "Literal placeholder must be substituted, got: \(out)"
            )
        }

        /// Scenario: resetToSystem clears the stored selection.
        /// Given a locale was manually selected
        /// When resetToSystem is called
        /// Then followSystem becomes true and selectedLocaleCode becomes nil.
        func test_reset_to_system_clears_selection() {
            let service = LocalizationService(defaults: makeEphemeralDefaults())
            service.selectLocale(code: "en")
            XCTAssertFalse(service.followSystem, "precondition: followSystem should be false after selectLocale")

            service.resetToSystem()

            XCTAssertTrue(service.followSystem, "followSystem must become true after resetToSystem")
            XCTAssertNil(service.selectedLocaleCode, "selectedLocaleCode must be cleared")
        }

        // MARK: - Helpers

        /// Creates a private UserDefaults instance so tests don't pollute the
        /// real defaults database across runs.
        private func makeEphemeralDefaults() -> UserDefaults {
            let suiteName = "vauchi.tests.\(UUID().uuidString)"
            return UserDefaults(suiteName: suiteName)!
        }
    }
#endif
