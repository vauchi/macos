// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// EditableTextComponentView.swift
// Renders an EditableText component from core UI (macOS)

import SwiftUI
#if canImport(VauchiPlatform)
    import VauchiPlatform
#endif

/// Renders a core `Component::EditableText` that toggles between display and edit mode.
struct EditableTextComponentView: View {
    let component: EditableTextComponent
    let onAction: (UserAction) -> Void

    @ObservedObject private var localizationService = LocalizationService.shared
    @EnvironmentObject private var themeService: ThemeService

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(component.label)
                .font(.caption)
                .foregroundColor(.secondary)

            if component.editing {
                TextField(component.label, text: .constant(component.value))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: component.value) { _, newValue in
                        onAction(.textChanged(componentId: component.id, value: newValue))
                    }

                if let error = component.validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(themeService.error)
                }
            } else {
                HStack {
                    Text(component.value)
                        .font(.body)

                    Spacer()

                    Button {
                        onAction(.actionPressed(actionId: "\(component.id):edit"))
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(themeService.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizationService.t(
                        "a11y.edit_field",
                        args: ["label": component.label]
                    ))
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityLabel(component.a11y?.label ?? component.label)
        .accessibilityHint(component.a11y?.hint ?? "")
    }
}
