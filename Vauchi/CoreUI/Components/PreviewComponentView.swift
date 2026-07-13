// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

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
            if !component.variants.isEmpty {
                variantSelector
            }

            cardView
        }
        .accessibilityLabel(component.a11y?.label ?? localizationService.t(
            "card_preview.a11y_card_preview",
            args: ["name": component.name]
        ))
    }

    // TODO(HUMBLE): W — variantSelector uses card_preview.all_groups domain
    // vocabulary (see _private problem record
    // 2026-07-06-desktop-tui-web-domain-shell-violations).
    private var variantSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                variantTab(
                    name: localizationService.t("card_preview.all_groups"),
                    isSelected: component.selectedVariant == nil
                ) {
                    onAction(.variantSelected(variantId: nil))
                }

                ForEach(component.variants) { variant in
                    // Tab label uses `variantId` (the stable engine
                    // identifier — for contact-card variants today
                    // this is the group name, e.g. "Family").
                    // `displayName` is the contact's per-variant name
                    // and is rendered in `cardView`'s header below,
                    // not on the tab. Preserves pre-Wire-Humble UX.
                    variantTab(
                        name: variant.variantId,
                        isSelected: component.selectedVariant == variant.variantId
                    ) {
                        onAction(.variantSelected(variantId: variant.variantId))
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

    private var avatarCircle: some View {
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
            Image(systemName: sfSymbolForCoreIcon(field.icon))
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
}
