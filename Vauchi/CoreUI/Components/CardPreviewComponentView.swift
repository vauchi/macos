// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// CardPreviewComponentView.swift
// Renders a CardPreview component from core UI (macOS)

import SwiftUI
#if canImport(VauchiPlatform)
    import VauchiPlatform
#endif

/// Renders a core `Component::CardPreview` as a styled card with group views.
struct CardPreviewComponentView: View {
    let component: CardPreviewComponent
    let onAction: (UserAction) -> Void

    @Environment(\.designTokens) private var tokens
    @ObservedObject private var localizationService = LocalizationService.shared
    @EnvironmentObject private var themeService: ThemeService

    var body: some View {
        VStack(spacing: 16) {
            // Group selector (if groups exist)
            if !component.groupViews.isEmpty {
                groupSelector
            }

            // Card
            cardView
        }
        .accessibilityLabel(component.a11y?.label ?? localizationService.t(
            "card_preview.a11y_card_preview",
            args: ["name": component.name]
        ))
    }

    private var groupSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" tab
                groupTab(
                    name: localizationService.t("card_preview.all_groups"),
                    isSelected: component.selectedGroup == nil
                ) {
                    onAction(.groupViewSelected(groupName: nil))
                }

                ForEach(component.groupViews) { groupView in
                    groupTab(
                        name: groupView.groupName,
                        isSelected: component.selectedGroup == groupView.groupName
                    ) {
                        onAction(.groupViewSelected(groupName: groupView.groupName))
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func groupTab(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? themeService.accent : Color(nsColor: .quaternaryLabelColor))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(CGFloat(tokens.borderRadius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityValue(localizationService.t(isSelected ? "a11y.selected" : "a11y.not_selected"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var cardView: some View {
        VStack(spacing: 0) {
            // Card header
            VStack(spacing: 8) {
                avatarCircle
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                Text(currentDisplayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityLabel(localizationService.t(
                        "a11y.display_name",
                        args: ["name": currentDisplayName]
                    ))
            }
            .padding(.vertical, 24)

            Divider()

            // Fields
            VStack(spacing: 0) {
                let fields = currentFields
                if fields.isEmpty {
                    Text(localizationService.t("card_preview.no_fields_visible"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(fields) { field in
                        CardFieldRow(field: field)
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(CGFloat(tokens.borderRadius.lg))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private var avatarCircle: some View {
        if let avatarData = component.avatarData,
           let nsImage = NSImage(data: Data(avatarData))
        {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
        } else {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [themeService.accent, themeService.accent.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Text(currentDisplayName.prefix(1).uppercased())
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                )
        }
    }

    private var currentDisplayName: String {
        if let selectedGroup = component.selectedGroup,
           let groupView = component.groupViews.first(where: { $0.groupName == selectedGroup })
        {
            return groupView.displayName
        }
        return component.name
    }

    private var currentFields: [FieldDisplay] {
        if let selectedGroup = component.selectedGroup,
           let groupView = component.groupViews.first(where: { $0.groupName == selectedGroup })
        {
            return groupView.visibleFields
        }
        return component.fields.filter { field in
            if case .shown = field.visibility { return true }
            if case .groups = field.visibility { return true }
            return false
        }
    }
}

struct CardFieldRow: View {
    let field: FieldDisplay

    @Environment(\.designTokens) private var tokens
    @ObservedObject private var localizationService = LocalizationService.shared
    @EnvironmentObject private var themeService: ThemeService

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForFieldType(field.fieldType))
                .foregroundColor(themeService.accent)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(field.label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(field.value)
                    .font(.body)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, CGFloat(tokens.borderRadius.mdLg))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(field.a11y?.label ?? localizationService.t(
            "a11y.field_value",
            args: ["label": field.label, "value": field.value]
        ))
    }

    private func iconForFieldType(_ type: String) -> String {
        switch type.lowercased() {
        case "phone": "phone"
        case "email": "envelope"
        case "website": "globe"
        case "address": "mappin"
        case "social": "at"
        case "birthday": "gift"
        default: "doc.text"
        }
    }
}
