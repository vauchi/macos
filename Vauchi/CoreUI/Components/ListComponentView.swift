// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// ListComponentView.swift
// Renders a ContactList component from core UI (macOS)

import CoreUIModels
import SwiftUI
#if canImport(VauchiPlatform)
    import VauchiPlatform
#endif

/// Renders a core `Component::ContactList` as a searchable list of contacts.
struct ListComponentView: View {
    let component: ContactListComponent
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
                ForEach(component.contacts) { contact in
                    ContactItemRow(contact: contact) {
                        onAction(.listItemSelected(componentId: component.id, itemId: contact.id))
                    }

                    if contact.id != component.contacts.last?.id {
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

struct ContactItemRow: View {
    let contact: ContactItem
    let onTap: () -> Void

    @Environment(\.designTokens) private var tokens
    @EnvironmentObject private var themeService: ThemeService

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar circle with initials
                Text(contact.avatarInitials)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(themeService.accent)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    if let subtitle = contact.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if let status = contact.status {
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
        .accessibilityLabel(contact.a11y?.label ?? contact.name)
        .accessibilityHint(contact.a11y?.hint ?? contact.subtitle ?? "")
        .accessibilityAddTraits(.isButton)
    }
}
