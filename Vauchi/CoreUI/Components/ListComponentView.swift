// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// ListComponentView.swift
// Renders a List component from core UI (macOS, Wire Humble — domain-agnostic).

import CoreUIModels
import SwiftUI
#if canImport(VauchiPlatform)
    import VauchiPlatform
#endif

/// Renders a core `Component::List` as a searchable list of items. The
/// renderer doesn't know what kind of items it's rendering — engines
/// produce UI-shaped `Item`s from any domain (contacts, decoys, members).
struct ListComponentView: View {
    let component: ListComponent
    let onAction: (UserAction) -> Void

    @Environment(\.designTokens) private var tokens
    @ObservedObject private var localizationService = LocalizationService.shared
    @State private var searchQuery: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if component.searchable {
                TextField(localizationService.t("action.search"), text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: searchQuery) { newValue in
                        onAction(.searchChanged(componentId: component.id, query: newValue))
                    }
                    .accessibilityLabel(localizationService.t("a11y.search_contacts"))
            }

            VStack(spacing: 0) {
                ForEach(component.items) { item in
                    ItemRow(item: item) {
                        onAction(.listItemSelected(componentId: component.id, itemId: item.id))
                    }

                    if item.id != component.items.last?.id {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(CGFloat(tokens.borderRadius.mdLg))
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}

struct ItemRow: View {
    let item: Item
    let onTap: () -> Void

    @Environment(\.designTokens) private var tokens
    @EnvironmentObject private var themeService: ThemeService

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar circle with initials
                Text(item.avatarInitials)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(themeService.accent)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if let status = item.status {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, CGFloat(tokens.borderRadius.mdLg))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.a11y?.label ?? item.name)
        .accessibilityHint(item.a11y?.hint ?? item.subtitle ?? "")
        .accessibilityAddTraits(.isButton)
    }
}
