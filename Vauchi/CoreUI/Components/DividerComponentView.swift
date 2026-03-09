// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// DividerComponentView.swift
// Renders a Divider component from core UI (macOS)

import SwiftUI

/// Renders a core `Component::Divider` as a styled horizontal divider.
struct DividerComponentView: View {
    var body: some View {
        Divider()
            .padding(.vertical, 4)
    }
}
