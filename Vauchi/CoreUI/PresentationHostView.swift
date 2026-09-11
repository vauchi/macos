// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct PresentationHostView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
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
        PresentationHostContent(
            state: viewModel.presentationState,
            onEvent: { surfaceID, event in
                viewModel.activateAndDispatch(surfaceID: surfaceID, event: event)
            },
            onDismissOverlay: viewModel.dismissPresentationOverlay
        )
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
