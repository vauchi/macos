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
            Color.black.opacity(0.28)
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
                Text(
                    overlay.overlay.title
                        ?? (overlay.overlay.kind == .navigation
                            ? "Navigation"
                            : "Actions")
                )
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
            .foregroundStyle(
                action.tone == .destructive ? Color.red : Color.primary
            )
            .accessibilityLabel(action.accessibilityLabel)
        }
    }

    /// Icon *and* label, never icon alone: the symbol is a recognition aid
    /// for readers who skim rather than read, and removing the word would
    /// trade one barrier for another.
    @ViewBuilder
    private func actionLabel(_ action: PresentationAction) -> some View {
        if let symbol = NavigationIconMap.systemImage(
            forOverlayKind: overlay.overlay.kind,
            token: action.iconToken
        ) {
            Label(action.label, systemImage: symbol)
                .labelStyle(.titleAndIcon)
        } else {
            Text(action.label)
        }
    }
}
