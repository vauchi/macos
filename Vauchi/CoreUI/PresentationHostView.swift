// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct PresentationHostView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @FocusState private var focusedBindingID: String?
    /// Last measured window size, kept so `reducedMotion` changes can
    /// re-report the environment without the GeometryReader in scope.
    @State private var viewportSize: CGSize = .zero

    var body: some View {
        // The GeometryReader measures the window; it must not WRAP the
        // window. As a wrapper it became the single child of the window in
        // the accessibility tree — a full-frame group holding the surface
        // and the command bar, with no description of its own, which is
        // what `testAccessibilityAudit` flags (audit type
        // `sufficientElementDescription`). Its children are all labelled;
        // only this structural wrapper was not, and a purely structural
        // container should not be an accessibility element at all rather
        // than be given invented copy. Reading the size from a background
        // keeps the measurement and drops the wrapper.
        chrome
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            viewportSize = geometry.size
                            reportEnvironment(geometry.size)
                        }
                        .onChange(of: geometry.size) { size in
                            viewportSize = size
                            reportEnvironment(size)
                        }
                }
                .accessibilityHidden(true)
            }
            .onChange(of: reducedMotion) { _ in
                reportEnvironment(viewportSize)
            }
            // WCAG 2.2 SC 2.4.11: a presented overlay visually covers the
            // active surface, so any control focused underneath it must
            // release focus rather than leave its ring drawn beneath a
            // layer the user can no longer see through.
            .onChange(of: viewModel.presentationState.activeOverlay) { overlay in
                if overlay != nil {
                    focusedBindingID = nil
                }
            }
            .onExitCommand {
                guard let surfaceID = viewModel.presentationState.activeSurfaceID else {
                    return
                }
                viewModel.activateAndDispatch(
                    surfaceID: surfaceID,
                    event: .backRequested(surfaceID: surfaceID)
                )
            }
            .alert(item: $viewModel.alertMessage) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text(LocalizationService.shared.t("action.ok")))
                )
            }
            .overlay(alignment: .top) {
                if let message = viewModel.toastMessage {
                    Text(message)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(radius: 8)
                        .padding(.top, 8)
                        .accessibilityAddTraits(.isStaticText)
                }
            }
    }

    /// Wraps `content` in the persistent desktop sidebar when Core
    /// publishes destinations for the active surface; empty `NavigationSpec`
    /// (locked app) hides the column entirely rather than rendering one with
    /// nothing in it. The navigation overlay stays reachable from the
    /// context bar regardless — this sidebar is the persistent peer, not a
    /// replacement for it.
    @ViewBuilder
    private var chrome: some View {
        let sidebarModel = SidebarModel(navigation: viewModel.presentationState.activeNavigation)
        if sidebarModel.isHidden {
            content
        } else {
            NavigationSplitView {
                PresentationSidebarView(
                    model: sidebarModel,
                    focusedBinding: $focusedBindingID,
                    onSelect: { interactionID in
                        guard let surfaceID = viewModel.presentationState.activeSurfaceID else {
                            return
                        }
                        viewModel.activateAndDispatch(
                            surfaceID: surfaceID,
                            event: .actionActivated(
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
                .safeAreaInset(edge: .bottom) {
                    commandBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            if let overlay = viewModel.presentationState.activeOverlay {
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
                        viewModel.dismissPresentationOverlay()
                        viewModel.activateAndDispatch(
                            surfaceID: overlay.surfaceID,
                            event: event
                        )
                    },
                    onDismiss: viewModel.dismissPresentationOverlay
                )
                .zIndex(20)
            }
        }
    }

    @ViewBuilder
    private var surfaces: some View {
        let state = viewModel.presentationState
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
        ForEach(ids, id: \.self) { surfaceID in
            if let surface = viewModel.presentationState.surfaces[surfaceID] {
                PresentationSurfaceView(
                    surface: surface,
                    active: viewModel.presentationState.activeSurfaceID == surfaceID,
                    focusedBinding: $focusedBindingID,
                    onEvent: { event in
                        viewModel.activateAndDispatch(
                            surfaceID: surfaceID,
                            event: event
                        )
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var commandBar: some View {
        if let surfaceID = viewModel.presentationState.activeSurfaceID {
            ContextCommandBarView(
                surfaceID: surfaceID,
                bar: viewModel.presentationState.activeBar,
                tokens: viewModel.presentationState.surfaces[surfaceID]?.tokens,
                reducedMotion: reducedMotion,
                focusedBinding: $focusedBindingID,
                onEvent: { event in
                    viewModel.activateAndDispatch(
                        surfaceID: surfaceID,
                        event: event
                    )
                }
            )
        }
    }

    private func reportEnvironment(_ size: CGSize) {
        viewModel.dispatchPresentation(
            .environmentChanged(
                availableWidth: UInt32(max(0, size.width.rounded())),
                availableHeight: UInt32(max(0, size.height.rounded())),
                inputModes: [.pointer, .keyboard],
                motion: reducedMotion ? .reduced : .full
            )
        )
    }
}
