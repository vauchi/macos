// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// LocalizationService.swift
// Internationalization service using vauchi-platform bindings

#if canImport(VauchiPlatform)

    import Combine
    import Foundation
    import VauchiPlatform

    /// Keys for locale-related UserDefaults storage
    private enum LocaleSettingsKey: String {
        case selectedLocaleCode = "vauchi.locale.selectedCode"
        case followSystem = "vauchi.locale.followSystem"
    }

    /// Service for managing app localization via core i18n system.
    final class LocalizationService: ObservableObject {
        static let shared = LocalizationService()

        private let defaults: UserDefaults

        @Published var currentLocale: MobileLocale = .english
        @Published var availableLocales: [MobileLocaleInfo] = []

        private convenience init() {
            self.init(defaults: .standard)
        }

        /// Initialize with custom UserDefaults (for testing).
        init(defaults: UserDefaults) {
            self.defaults = defaults
            registerDefaults()
            loadLocales()
        }

        private func registerDefaults() {
            defaults.register(defaults: [
                LocaleSettingsKey.followSystem.rawValue: true,
            ])
        }

        private func loadLocales() {
            availableLocales = getAvailableLocales()
            applySelectedLocale()
        }

        // MARK: - Settings

        var selectedLocaleCode: String? {
            get { defaults.string(forKey: LocaleSettingsKey.selectedLocaleCode.rawValue) }
            set {
                defaults.set(newValue, forKey: LocaleSettingsKey.selectedLocaleCode.rawValue)
                applySelectedLocale()
            }
        }

        var followSystem: Bool {
            get { defaults.bool(forKey: LocaleSettingsKey.followSystem.rawValue) }
            set {
                defaults.set(newValue, forKey: LocaleSettingsKey.followSystem.rawValue)
                applySelectedLocale()
            }
        }

        // MARK: - Locale Selection

        func applySelectedLocale() {
            if let code = selectedLocaleCode, !followSystem {
                if let locale = parseLocaleCode(code: code) {
                    currentLocale = locale
                    return
                }
            }

            // Use system language
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            if let locale = parseLocaleCode(code: systemLanguage) {
                currentLocale = locale
            } else {
                currentLocale = .english
            }
        }

        /// Select a locale by BCP-47 code.
        func selectLocale(code: String) {
            followSystem = false
            selectedLocaleCode = code
        }

        /// Select a locale directly.
        func selectLocale(_ locale: MobileLocale) {
            let info = getLocaleInfo(locale: locale)
            selectLocale(code: info.code)
        }

        /// Reset to follow system language.
        func resetToSystem() {
            followSystem = true
            selectedLocaleCode = nil
            applySelectedLocale()
        }

        // MARK: - String Lookup

        /// Get a localized string by key.
        func t(_ key: String) -> String {
            getString(locale: currentLocale, key: key)
        }

        /// Get a localized string with interpolation arguments.
        func t(_ key: String, args: [String: String]) -> String {
            getStringWithArgs(locale: currentLocale, key: key, args: args)
        }

        // MARK: - Convenience

        var currentLocaleInfo: MobileLocaleInfo {
            getLocaleInfo(locale: currentLocale)
        }

        var isRightToLeft: Bool {
            currentLocaleInfo.isRtl
        }
    }

#endif
