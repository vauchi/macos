// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Renders an EditableText component from core UI (macOS)

import CoreUIModels
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

    // Display<->edit is presentation state the frontend owns (matches the
    // web-demo renderer); core is never asked to flip `editing` and receives
    // only the resulting TextChanged. `draft` holds the in-progress text —
    // the previous `.constant(component.value)` binding was read-only, so
    // keystrokes were silently discarded.
    @State private var isEditing = false
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(component.label)
                .font(.caption)
                .foregroundColor(.secondary)

            if isEditing || component.editing {
                TextField(component.label, text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: draft) { _, newValue in
                        onAction(.textChanged(componentId: component.id, value: newValue))
                    }
                    .onAppear { draft = component.value }

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
                        isEditing = true
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
