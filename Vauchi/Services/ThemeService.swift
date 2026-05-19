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
    ///
    /// Source of truth is `UserDefaults` (OS-native, Category 1 —
    /// render-context). Core's `RenderContext` is informed of changes via
    /// `setRenderContextJson` so the Settings dropdown's `selected` value
    /// stays in sync (S4 of `2026-05-16-settings-storage-by-sensitivity`).
    final class ThemeService: ObservableObject {
        static let shared = ThemeService()

        private let defaults: UserDefaults
        private var appEngine: PlatformAppEngine?

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

        // MARK: - Engine attachment

        /// Wire this service to the live [PlatformAppEngine] so subsequent
        /// theme changes propagate to core's `RenderContext`. Called once
        /// from `VauchiRepository` after the engine finishes
        /// initialization. Re-applies the theme and pushes it to core so
        /// the Settings dropdown reflects what's on disk.
        func attachAppEngine(_ engine: PlatformAppEngine) {
            appEngine = engine
            applySelectedTheme()
            pushRenderContext(engine: engine)
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
            pushRenderContext(engine: appEngine)
        }

        /// Reset to follow system appearance.
        func resetToSystem() {
            followSystem = true
            selectedThemeId = nil
            applySelectedTheme()
            pushRenderContext(engine: appEngine)
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
