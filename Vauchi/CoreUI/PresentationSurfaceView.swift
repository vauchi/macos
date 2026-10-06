// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// One surface's card: its title row (carrying the active surface's Back,
/// Navigate, Actions and Info slots), its scrollable or fixed content, and
/// — only when Core sends one — a full-width Primary button pinned under
/// the content. There is no row of controls above or below this card any
/// more; Core's context bar moved into the surface it describes
/// (vauchi/private#479, #534).
struct PresentationSurfaceView: View {
    let surface: PresentationSurface
    let active: Bool
    let bar: PresentationContextBar?
    let navigationShown: Bool
    let reducedMotion: Bool
    let focusedBinding: FocusState<String?>.Binding
    let onEvent: (PresentationEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat(surface.tokens.spacingMedium)) {
            titleRow
            if let subtitle = surface.subtitle {
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            Group {
                if surface.layout == .scroll {
                    ScrollView {
                        nodesContent
                    }
                } else {
                    nodesContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if let primary = bar?.primary {
                primaryButton(primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CGFloat(surface.tokens.spacingLarge))
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(
            RoundedRectangle(cornerRadius: CGFloat(surface.tokens.cornerRadius))
        )
        .overlay {
            RoundedRectangle(cornerRadius: CGFloat(surface.tokens.cornerRadius))
                .stroke(
                    active ? Color.accentColor : Color.secondary.opacity(0.25),
                    lineWidth: 1
                )
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                // Simultaneous so it still fires when a child handles the
                // click: focus must leave the field whatever was pressed,
                // otherwise SwiftUI keeps it and Core never hears that the
                // user moved on. Clicking the focused field itself clears
                // and re-takes focus, so one spurious InputFocusEnded can
                // precede the refocus.
                focusedBinding.wrappedValue = nil
                onEvent(.surfaceActivated(surfaceID: surface.surfaceID))
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(surface.accessibilityLabel)
    }

    private var titleRow: some View {
        let leading = ContextCommandBarLayout.leadingTitleSlots(bar: bar, navigationShown: navigationShown)
        let trailing = ContextCommandBarLayout.trailingTitleSlots(bar: bar)
        return HStack(spacing: 8) {
            if leading.contains(.back), let back = bar?.back {
                roleButton(back, systemImage: "arrow.left", slot: .back)
            }
            if leading.contains(.navigation), let navigation = bar?.navigation {
                roleButton(navigation, systemImage: "line.3.horizontal", slot: .navigation)
            }
            Text(surface.title)
                .font(.title2.bold())
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            if trailing.contains(.secondary), let secondary = bar?.secondary {
                roleButton(secondary, systemImage: "ellipsis", slot: .secondary)
            }
            if trailing.contains(.info), let info = bar?.info {
                roleButton(info, systemImage: "info.circle", slot: .info)
            }
        }
    }

    private var nodesContent: some View {
        VStack(alignment: .leading, spacing: CGFloat(surface.tokens.spacingMedium)) {
            ForEach(identifyPresentationNodes(surface.nodes)) { identified in
                PresentationNodeView(
                    node: identified.node,
                    surfaceID: surface.surfaceID,
                    minimumTarget: CGFloat(surface.tokens.minimumTargetSize),
                    focusedBinding: focusedBinding,
                    onEvent: onEvent
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func primaryButton(_ primary: PresentationAction) -> some View {
        Button(primary.label) {
            activate(primary)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .disabled(!primary.enabled)
        .accessibilityLabel(primary.accessibilityLabel)
        .accessibilityIdentifier(ContextCommandBarLayout.accessibilityIdentifier(for: .primary))
        .keyboardShortcut(
            primary.shortcut == .undo ? "z" : .return,
            modifiers: .command
        )
        .keyboardFocusRing(
            focusedBinding,
            equals: primary.interactionID,
            color: ThemeService.shared.focusRing
        )
    }

    private func roleButton(
        _ action: PresentationAction,
        systemImage: String,
        slot: ContextCommandBarLayout.Slot
    ) -> some View {
        Button {
            activate(action)
        } label: {
            Image(systemName: systemImage)
        }
        .disabled(!action.enabled)
        .accessibilityLabel(action.accessibilityLabel)
        .accessibilityIdentifier(ContextCommandBarLayout.accessibilityIdentifier(for: slot))
        .help(ContextCommandBarLayout.helpText(for: slot))
        .keyboardShortcut(ContextCommandBarLayout.keyboardShortcut(for: slot))
        .keyboardFocusRing(
            focusedBinding,
            equals: action.interactionID,
            color: ThemeService.shared.focusRing
        )
    }

    private func activate(_ action: PresentationAction) {
        withAnimation(reducedMotion ? nil : .easeOut(duration: 0.2)) {
            onEvent(
                .actionActivated(
                    surfaceID: surface.surfaceID,
                    interactionID: action.interactionID
                )
            )
        }
    }
}
