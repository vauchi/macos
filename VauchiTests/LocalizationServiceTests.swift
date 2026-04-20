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

        /// Scenario: a missing key returns core's "Missing: <key>" fallback.
        /// Given a key that does not exist in any locale
        /// When t(key) is called
        /// Then core returns the documented "Missing: <key>" sentinel so
        /// translators / developers can spot the gap visually — see
        /// core/vauchi-app/src/i18n.rs::get_string.
        func test_t_missing_key_returns_missing_sentinel() {
            let service = LocalizationService(defaults: makeEphemeralDefaults())

            let missing = "this.key.should.not.exist.in.any.locale"
            let result = service.t(missing)

            XCTAssertTrue(
                result.hasPrefix("Missing:"),
                "Core's documented fallback is 'Missing: <key>'; got: \(result)"
            )
            XCTAssertTrue(
                result.contains(missing),
                "Fallback string must include the requested key: \(result)"
            )
        }

        /// Scenario: argument interpolation does not mangle keys without placeholders.
        /// Given a bundled key with no {placeholder} in its value
        /// When t(key, args:) is called with spurious args
        /// Then the result is the un-substituted string (args are a no-op).
        ///
        /// The bundled-English fallback only ships app.name and welcome.title —
        /// neither has placeholders — so we exercise the call path but assert
        /// the no-op semantics. Full interpolation coverage lives in core
        /// tests (vauchi-app::i18n::tests::test_get_string_with_args).
        func test_t_with_args_on_bundled_key_is_noop() {
            let service = LocalizationService(defaults: makeEphemeralDefaults())
            service.selectLocale(.english)

            let out = service.t("app.name", args: ["count": "3"])

            XCTAssertEqual(
                out,
                "Vauchi",
                "app.name has no {count} placeholder; args must not alter the result"
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
