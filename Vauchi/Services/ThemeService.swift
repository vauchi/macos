// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// ThemeService.swift
// Theme management using vauchi-platform bindings

#if canImport(VauchiPlatform)

    import AppKit
    import Combine
    import SwiftUI
    import VauchiPlatform

    /// Keys for theme-related UserDefaults storage
    private enum ThemeSettingsKey: String {
        case selectedThemeId = "vauchi.theme.selectedId"
        case followSystem = "vauchi.theme.followSystem"
    }

    /// Service for managing app theming via core theme catalog.
    final class ThemeService: ObservableObject {
        static let shared = ThemeService()

        private let defaults: UserDefaults

        @Published var currentTheme: MobileTheme?
        @Published var availableThemes: [MobileTheme] = []

        private convenience init() {
            self.init(defaults: .standard)
        }

        /// Initialize with custom UserDefaults (for testing).
        init(defaults: UserDefaults) {
            self.defaults = defaults
            registerDefaults()
            loadThemes()
        }

        private func registerDefaults() {
            defaults.register(defaults: [
                ThemeSettingsKey.followSystem.rawValue: true,
            ])
        }

        private func loadThemes() {
            availableThemes = getAvailableThemes()
            applySelectedTheme()
        }

        // MARK: - Settings

        var selectedThemeId: String? {
            get { defaults.string(forKey: ThemeSettingsKey.selectedThemeId.rawValue) }
            set {
                defaults.set(newValue, forKey: ThemeSettingsKey.selectedThemeId.rawValue)
                applySelectedTheme()
            }
        }

        var followSystem: Bool {
            get { defaults.bool(forKey: ThemeSettingsKey.followSystem.rawValue) }
            set {
                defaults.set(newValue, forKey: ThemeSettingsKey.followSystem.rawValue)
                applySelectedTheme()
            }
        }

        // MARK: - Theme Selection

        func applySelectedTheme() {
            if let themeId = selectedThemeId, !followSystem {
                currentTheme = getTheme(themeId: themeId)
            } else {
                let isDark = NSApp?.effectiveAppearance
                    .bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                let defaultId = getDefaultThemeId(preferDark: isDark)
                currentTheme = getTheme(themeId: defaultId)
            }
        }

        /// Select a theme by ID.
        func selectTheme(_ themeId: String) {
            followSystem = false
            selectedThemeId = themeId
        }

        /// Reset to follow system appearance.
        func resetToSystem() {
            followSystem = true
            selectedThemeId = nil
            applySelectedTheme()
        }

        // MARK: - Color Conversion

        /// Convert hex color string to SwiftUI Color.
        func color(from hex: String) -> Color {
            var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            if hexSanitized.hasPrefix("#") {
                hexSanitized.removeFirst()
            }

            guard hexSanitized.count == 6 else {
                return .clear
            }

            var rgb: UInt64 = 0
            Scanner(string: hexSanitized).scanHexInt64(&rgb)

            let red = Double((rgb & 0xFF0000) >> 16) / 255.0
            let green = Double((rgb & 0x00FF00) >> 8) / 255.0
            let blue = Double(rgb & 0x0000FF) / 255.0

            return Color(red: red, green: green, blue: blue)
        }

        // MARK: - Color Accessors

        var bgPrimary: Color {
            guard let theme = currentTheme else { return Color(nsColor: .windowBackgroundColor) }
            return color(from: theme.colors.bgPrimary)
        }

        var bgSecondary: Color {
            guard let theme = currentTheme else { return Color(nsColor: .controlBackgroundColor) }
            return color(from: theme.colors.bgSecondary)
        }

        var textPrimary: Color {
            guard let theme = currentTheme else { return Color(nsColor: .labelColor) }
            return color(from: theme.colors.textPrimary)
        }

        var textSecondary: Color {
            guard let theme = currentTheme else { return Color(nsColor: .secondaryLabelColor) }
            return color(from: theme.colors.textSecondary)
        }

        var accent: Color {
            guard let theme = currentTheme else { return .accentColor }
            return color(from: theme.colors.accent)
        }

        var success: Color {
            guard let theme = currentTheme else { return .green }
            return color(from: theme.colors.success)
        }

        var error: Color {
            guard let theme = currentTheme else { return .red }
            return color(from: theme.colors.error)
        }

        var warning: Color {
            guard let theme = currentTheme else { return .orange }
            return color(from: theme.colors.warning)
        }

        var border: Color {
            guard let theme = currentTheme else { return Color(nsColor: .separatorColor) }
            return color(from: theme.colors.border)
        }

        // MARK: - Grouped Themes

        var darkThemes: [MobileTheme] {
            availableThemes.filter { $0.mode == .dark }
        }

        var lightThemes: [MobileTheme] {
            availableThemes.filter { $0.mode == .light }
        }
    }

#endif
