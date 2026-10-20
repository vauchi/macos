// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// DIAG vauchi/private#714 (throwaway): tags each AppKit ancestor of the
/// sidebar with its depth, so the accessibility audit's flagged element
/// names which one it is.
struct SidebarColumnAccessibility: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        ProbeView()
    }

    func updateNSView(_: NSView, context _: Context) {}

    private final class ProbeView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            var view = superview
            var depth = 1
            while let current = view, depth <= 10, current !== window?.contentView {
                if current.accessibilityIdentifier().isEmpty {
                    current.setAccessibilityIdentifier(
                        "diag714.ancestor.\(depth).\(type(of: current))"
                    )
                }
                view = current.superview
                depth += 1
            }
        }
    }
}
