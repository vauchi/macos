// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct PresentationOverlayView: View {
    let overlay: RevisionedOverlay
    let reducedMotion: Bool
    let onAction: (PresentationEvent) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            ThemeService.shared.scrim
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            if overlay.overlay.kind == .navigation {
                navigationPalette
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(
                        reducedMotion
                            ? .identity
                            : .move(edge: .leading).combined(with: .opacity)
                    )
            } else if overlay.overlay.kind == .information {
                informationPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(reducedMotion ? .identity : .opacity)
            } else {
                actionPopover
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .bottomTrailing
                    )
                    .transition(
                        reducedMotion
                            ? .identity
                            : .scale(scale: 0.94, anchor: .bottomTrailing)
                            .combined(with: .opacity)
                    )
            }
        }
        .onExitCommand(perform: onDismiss)
    }

    private var navigationPalette: some View {
        panel {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150))],
                spacing: 8
            ) {
                actions
            }
            // Stable frontend a11y anchor for UI tests (NOT a core action
            // id): lets tests query the destination buttons without coupling
            // to localized labels. Mirrors the iOS shell's anchor.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("navigationDestinations")
        }
        .frame(maxWidth: 620)
        .padding(.top, 72)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// Core's words about the surface, read in full; dismissing is the only
    /// action, through the close button, Escape or the scrim.
    private var informationPanel: some View {
        panel {
            ScrollView {
                Text(overlay.overlay.body ?? "")
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("informationBody")
            }
            .frame(maxHeight: 320)
        }
        .frame(width: 420)
    }

    private var actionPopover: some View {
        panel {
            VStack(alignment: .leading, spacing: 6) {
                actions
            }
        }
        .frame(width: 300)
        .padding(.trailing, 24)
        .padding(.bottom, 86)
    }

    private func panel<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(overlay.overlay.title ?? "")
                    .font(.headline)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            content()
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 24)
    }

    private var actions: some View {
        ForEach(overlay.overlay.items) { action in
            Button {
                onAction(
                    .actionActivated(
                        surfaceID: overlay.surfaceID,
                        interactionID: action.interactionID
                    )
                )
            } label: {
                actionLabel(action)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .disabled(!action.enabled)
            .foregroundStyle(action.tone.foregroundColor)
            .accessibilityLabel(action.accessibilityLabel)
        }
    }

    /// Icon *and* label, never icon alone: the symbol is a recognition aid
    /// for readers who skim rather than read, and removing the word would
    /// trade one barrier for another.
    @ViewBuilder
    private func actionLabel(_ action: PresentationAction) -> some View {
        if let icon = NavigationIconMap.icon(
            forOverlayKind: overlay.overlay.kind,
            token: action.iconToken
        ) {
            Label {
                Text(action.label)
            } icon: {
                NavigationIconImage(icon)
            }
            .labelStyle(.titleAndIcon)
        } else {
            Text(action.label)
        }
    }
}
