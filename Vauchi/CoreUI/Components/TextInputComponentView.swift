// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// TextInputComponentView.swift
// Renders a TextInput component from core UI (macOS)

import SwiftUI
#if canImport(VauchiPlatform)
    import VauchiPlatform
#endif

/// Renders a core `Component::TextInput` as a styled TextField with validation.
struct TextInputComponentView: View {
    let component: TextInputComponent
    let onAction: (UserAction) -> Void

    @ObservedObject private var localizationService = LocalizationService.shared
    @EnvironmentObject private var themeService: ThemeService
    @State private var localValue: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(component.label)
                .font(.headline)
                .foregroundColor(.secondary)

            Group {
                if component.inputType == .password {
                    SecureField(
                        component.placeholder ?? component.label,
                        text: $localValue
                    )
                } else {
                    TextField(
                        component.placeholder ?? component.label,
                        text: $localValue
                    )
                }
            }
            .textFieldStyle(.roundedBorder)
            .font(.title3)
            .onChange(of: localValue) { newValue in
                let value: String
                if let maxLen = component.maxLength, newValue.count > maxLen {
                    value = String(newValue.prefix(maxLen))
                    localValue = value
                } else {
                    value = newValue
                }
                onAction(.textChanged(componentId: component.id, value: value))
            }
            .accessibilityLabel(component.a11y?.label ?? component.label)
            .accessibilityHint(component.a11y?.hint ?? component.placeholder ?? "")

            if let error = component.validationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(themeService.error)
                    .accessibilityLabel(localizationService.t(
                        "a11y.error_prefix",
                        args: ["error": error]
                    ))
            }
        }
        .onAppear {
            localValue = component.value
        }
    }
}
