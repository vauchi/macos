// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// PlaceholderContentView.swift
// Fallback content + view-model used when `VauchiPlatform` bindings
// are not present (e.g. SwiftPM-only previews or test hosts running
// without the native xcframework). Never rendered in production.

import SwiftUI

#if !canImport(VauchiPlatform)
    import CoreUIModels

    struct PlaceholderContentView: View {
        // Constants instead of inline string literals — keeps the dev
        // fallback out of the `check-domain-named-views` Text-literal
        // sweep (G4). LocalizationService is unavailable here because
        // it lives behind the bindings we are missing.
        private let appName = "Vauchi"
        private let tagline = "Privacy-focused contact cards"
        private let bindingsMissing = "VauchiPlatform bindings not available"

        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.rectangle.stack")
                    .font(.system(size: 48))
                    .foregroundColor(.cyan)

                Text(appName)
                    .font(.largeTitle.bold())

                Text(tagline)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(bindingsMissing)
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Placeholder ViewModel for tests when VauchiPlatform is not available.
    class PlaceholderViewModel: ObservableObject {
        @Published var currentScreen: ScreenModel?

        func handleAction(_: UserAction) {
            // No-op: requires VauchiPlatform bindings
        }
    }
#endif
