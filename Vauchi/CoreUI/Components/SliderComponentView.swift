// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// SliderComponentView.swift
// Renders a Slider component from core UI (macOS)

import SwiftUI

/// Renders a core `Component::Slider` as a labelled SwiftUI Slider.
///
/// Emits `SliderChanged` with `value_milli` (value * 1000) on change,
/// matching core's integer-based action format.
struct SliderComponentView: View {
    let component: SliderComponent
    let onAction: (UserAction) -> Void

    @State private var localValue: Float

    init(component: SliderComponent, onAction: @escaping (UserAction) -> Void) {
        self.component = component
        self.onAction = onAction
        _localValue = State(initialValue: component.value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(component.label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                if let minIcon = component.minIcon {
                    Image(systemName: minIcon)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }

                if component.step > 0 {
                    Slider(
                        value: $localValue,
                        in: component.min ... component.max,
                        step: component.step,
                        onEditingChanged: sliderEditingChanged
                    )
                } else {
                    Slider(
                        value: $localValue,
                        in: component.min ... component.max,
                        onEditingChanged: sliderEditingChanged
                    )
                }

                if let maxIcon = component.maxIcon {
                    Image(systemName: maxIcon)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
            }
        }
        .onChange(of: component.value) { newValue in
            localValue = newValue
        }
        .accessibilityLabel(component.a11y?.label ?? component.label)
        .accessibilityValue("\(Int(localValue * 100))%")
        .accessibilityHint(component.a11y?.hint ?? "")
    }

    private func sliderEditingChanged(_ isEditing: Bool) {
        if !isEditing {
            let valueMilli = Int32(localValue * 1000)
            onAction(.sliderChanged(componentId: component.id, valueMilli: valueMilli))
        }
    }
}
