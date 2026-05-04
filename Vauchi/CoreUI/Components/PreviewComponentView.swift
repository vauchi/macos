// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// PreviewComponentView.swift
// Renders a Preview component from core UI (macOS, Wire Humble — variants
// replace the old contact-specific group views).

import CoreUIModels
import SwiftUI
#if canImport(VauchiPlatform)
    import VauchiPlatform
#endif

/// Renders a core `Component::Preview` as a styled card with optional
/// variant tabs. The renderer doesn't know what kind of thing the
/// preview represents — engines populate `variants` with whatever
/// alternate looks make sense (group views today; per-locale, per-
/// relationship, etc. tomorrow).
struct PreviewComponentView: View {
    let component: PreviewComponent
    let onAction: (UserAction) -> Void

    @Environment(\.designTokens) private var tokens
    @ObservedObject private var localizationService = LocalizationService.shared
    @EnvironmentObject private var themeService: ThemeService

    var body: some View {
        VStack(spacing: 16) {
            // Variant selector (if alternate views exist)
            if !component.variants.isEmpty {
                variantSelector
            }

            // Card
            cardView
        }
        .accessibilityLabel(component.a11y?.label ?? localizationService.t(
            "card_preview.a11y_card_preview",
            args: ["name": component.name]
        ))
    }

    private var variantSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" tab
                variantTab(
                    name: localizationService.t("card_preview.all_groups"),
                    isSelected: component.selectedVariant == nil
                ) {
                    onAction(.groupViewSelected(groupName: nil))
                }

                ForEach(component.variants) { variant in
                    variantTab(
                        name: variant.displayName,
                        isSelected: component.selectedVariant == variant.variantId
                    ) {
                        onAction(.groupViewSelected(groupName: variant.variantId))
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func variantTab(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
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
                        PreviewFieldRow(field: field)
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
        if let selectedVariant = component.selectedVariant,
           let variant = component.variants.first(where: { $0.variantId == selectedVariant })
        {
            return variant.displayName
        }
        return component.name
    }

    private var currentFields: [Field] {
        // Core's `build_visible_fields` does the selectedVariant branch + the
        // visibility filter identically across frontends. Render the
        // pre-computed list directly — no fallback. Test fixtures are part
        // of the contract: they must populate `visibleFields:` matching
        // what core emits. ADR-021 / ADR-043 (Humble UI).
        component.visibleFields
    }
}

struct PreviewFieldRow: View {
    let field: Field

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
