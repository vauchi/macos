// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The visible composition of one `PresentationState`: sidebar, surfaces
/// (each carrying the active one's context bar in its own title row and
/// content) and any overlay. `PresentationHostView` wraps it with the live
/// view model, window measurement and alerts; the screen-catalog render
/// replays a state through it without an engine.
struct PresentationHostContent: View {
    let state: PresentationState
    let onEvent: (_ surfaceID: String, _ event: PresentationEvent) -> Void
    let onDismissOverlay: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @FocusState private var focusedBindingID: String?

    var body: some View {
        chrome
            // WCAG 2.2 SC 2.4.11: a presented overlay visually covers the
            // active surface, so any control focused underneath it must
            // release focus rather than leave its ring drawn beneath a
            // layer the user can no longer see through.
            .onChange(of: state.activeOverlay) { overlay in
                if overlay != nil {
                    focusedBindingID = nil
                }
            }
    }

    /// Wraps `content` in the persistent desktop sidebar when Core
    /// publishes destinations for the active surface; empty `NavigationSpec`
    /// (locked app) hides the column entirely rather than rendering one with
    /// nothing in it. The navigation overlay stays reachable from the
    /// active surface's title row regardless — this sidebar is the
    /// persistent peer, not a replacement for it.
    @ViewBuilder
    private var chrome: some View {
        let sidebarModel = SidebarModel(navigation: state.activeNavigation)
        if sidebarModel.isHidden {
            content
        } else {
            NavigationSplitView {
                PresentationSidebarView(
                    model: sidebarModel,
                    focusedBinding: $focusedBindingID,
                    onSelect: { interactionID in
                        guard let surfaceID = state.activeSurfaceID else {
                            return
                        }
                        onEvent(
                            surfaceID,
                            .actionActivated(
                                surfaceID: surfaceID,
                                interactionID: interactionID
                            )
                        )
                    }
                )
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
            } detail: {
                content
            }
        }
    }

    private var content: some View {
        ZStack {
            surfaces
                .padding(16)
            if let overlay = state.activeOverlay {
                PresentationOverlayView(
                    overlay: overlay,
                    reducedMotion: reducedMotion,
                    onAction: { event in
                        // Choosing an item closes the menu, and Core has to
                        // hear that: `AppEngine::open_overlay` is cleared
                        // only by an `OverlayDismissed` event, so staying
                        // quiet leaves its toggle rewriting the next request
                        // for this menu into a dismissal and the menu stops
                        // opening. Report it *before* the action, while this
                        // surface is still active — reporting it afterwards
                        // is rejected by Core's fail-closed validation and
                        // reaches the user as a "Presentation error" alert
                        // (vauchi/ios!633).
                        onDismissOverlay()
                        onEvent(overlay.surfaceID, event)
                    },
                    onDismiss: onDismissOverlay
                )
                .zIndex(20)
            }
        }
    }

    @ViewBuilder
    private var surfaces: some View {
        let ids = state.visibleSurfaceIDs
        if state.profile?.paneLayout == .split {
            HStack(spacing: 16) {
                surfaceViews(ids)
            }
        } else {
            VStack {
                surfaceViews(ids)
            }
        }
    }

    private func surfaceViews(_ ids: [String]) -> some View {
        let navigationShown = !SidebarModel(navigation: state.activeNavigation).isHidden
        return ForEach(ids, id: \.self) { surfaceID in
            if let surface = state.surfaces[surfaceID] {
                let isActive = state.activeSurfaceID == surfaceID
                PresentationSurfaceView(
                    surface: surface,
                    active: isActive,
                    // Core's bar belongs to the active surface only — the
                    // same scoping `state.activeBar` already applied when
                    // this drew as a separate row.
                    bar: isActive ? state.activeBar : nil,
                    navigationShown: navigationShown,
                    reducedMotion: reducedMotion,
                    focusedBinding: $focusedBindingID,
                    onEvent: { event in
                        onEvent(surfaceID, event)
                    }
                )
            }
        }
    }
}
