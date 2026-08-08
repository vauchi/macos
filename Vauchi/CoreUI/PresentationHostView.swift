// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct PresentationHostView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @FocusState private var focusedBindingID: String?

    var body: some View {
        GeometryReader { geometry in
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
            .onAppear {
                reportEnvironment(geometry.size)
            }
            .onChange(of: geometry.size) { size in
                reportEnvironment(size)
            }
            .onChange(of: reducedMotion) { _ in
                reportEnvironment(geometry.size)
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
                reducedMotion: reducedMotion,
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
