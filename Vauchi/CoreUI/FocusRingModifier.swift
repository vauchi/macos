// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Draws the WCAG 2.2 SC 2.4.7/2.4.11 keyboard-focus indicator: a ring in
/// the theme's focus colour, offset clear of the control it wraps. Core's
/// `focus.ring_width` (3) and `focus.ring_offset` (2) tokens name these
/// numbers but do not yet cross UniFFI (F4,
/// `2026-09-09-cross-frontend-design-review-design.md`), so the values are
/// hardcoded here and pinned by `FocusRingModifierTests` against the token
/// document instead.
struct FocusRingModifier: ViewModifier {
    static let ringWidth: CGFloat = 3
    static let ringOffset: CGFloat = 2

    let isFocused: Bool
    let color: Color
    var cornerRadius: CGFloat = 6

    func body(content: Content) -> some View {
        content.overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(color, lineWidth: Self.ringWidth)
                    .padding(-(Self.ringWidth / 2 + Self.ringOffset))
            }
        }
    }
}

extension View {
    /// Makes a control keyboard-reachable and draws `FocusRingModifier`
    /// while `focusedBinding` names `id` as the surface's currently
    /// focused element. Reuses the same shared `FocusState<String?>`
    /// every input field already binds into, so a row, toggle, or action
    /// button becomes just another focus target on the same surface.
    func keyboardFocusRing(
        _ focusedBinding: FocusState<String?>.Binding,
        equals id: String,
        color: Color,
        cornerRadius: CGFloat = 6
    ) -> some View {
        focusable(true)
            .focused(focusedBinding, equals: id)
            .modifier(
                FocusRingModifier(
                    isFocused: focusedBinding.wrappedValue == id,
                    color: color,
                    cornerRadius: cornerRadius
                )
            )
    }
}
