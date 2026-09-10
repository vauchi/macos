// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The persistent desktop sidebar for Core's `SetNavigation` destinations —
/// the peer of the phone bottom bar and the navigation overlay's palette,
/// always visible rather than raised on demand. `PresentationHostView`
/// hides this column entirely when `model.isHidden` (a locked app).
struct PresentationSidebarView: View {
    let model: SidebarModel
    let focusedBinding: FocusState<String?>.Binding
    let onSelect: (String) -> Void

    var body: some View {
        List(model.rows) { row in
            sidebarRow(for: row)
        }
        .listStyle(.sidebar)
        .accessibilityLabel("Navigation")
    }

    private func sidebarRow(for row: SidebarRow) -> some View {
        let isSelected = row.interactionID == model.selectedID
        return Button {
            onSelect(row.interactionID)
        } label: {
            rowLabel(for: row)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .listRowBackground(
            isSelected ? ThemeService.shared.accent.opacity(0.16) : Color.clear
        )
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .keyboardFocusRing(
            focusedBinding,
            equals: row.interactionID,
            color: ThemeService.shared.focusRing
        )
    }

    /// Icon and label together, matching the navigation overlay's palette
    /// so the same destination reads the same way in either presentation.
    private func rowLabel(for row: SidebarRow) -> some View {
        HStack {
            Label(row.label, systemImage: NavigationIconMap.systemImage(for: row.iconToken))
                .labelStyle(.titleAndIcon)
            if row.badgeCount > 0 {
                Spacer()
                Text("\(row.badgeCount)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(ThemeService.shared.accent))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityValue(row.badgeCount > 0 ? "\(row.badgeCount)" : "")
    }
}
