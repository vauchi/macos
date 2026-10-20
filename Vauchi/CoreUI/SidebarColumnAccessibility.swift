// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Gives the sidebar column's hosting view the description the a11y audit
/// asks for (vauchi/private#714).
///
/// `testAccessibilityAudit` flagged a Group with no description around the
/// sidebar's list. A diagnostic run (macos pipeline 2967921702) named it:
/// the second AppKit ancestor of the list,
/// `NSHostingView<ModifiedContent<ColumnView, NavigationPaneModifier<…>>>`,
/// the host `NavigationSplitView` makes for its sidebar column. Like the
/// window's content view (`WindowContentAccessibility`) it is SwiftUI's own
/// container, reachable only from AppKit.
///
/// The label is `app.navigation`, the same word the list inside already
/// carries; the column is OS chrome below the shell protocol, so there is
/// nothing for Core to prepare.
struct SidebarColumnAccessibility: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        ColumnAccessibilityView()
    }

    func updateNSView(_: NSView, context _: Context) {}

    /// Zero-sized and never drawn; it exists to reach its ancestors.
    private final class ColumnAccessibilityView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let column = nearestHostingAncestor() else { return }
            // The anchor a later run can find the element by in the tree.
            column.setAccessibilityIdentifier("appkit.sidebarcolumn")
            column.setAccessibilityLabel(LocalizationService.shared.t("app.navigation"))
        }

        /// The column's host is the first hosting view above the list; the
        /// walk stops at the window's content view, so it never reaches the
        /// window, whose identifier XCUITest resolves windows by.
        private func nearestHostingAncestor() -> NSView? {
            var view = superview
            while let current = view, current !== window?.contentView {
                if String(describing: type(of: current)).hasPrefix("NSHostingView") {
                    return current
                }
                view = current.superview
            }
            return nil
        }
    }
}
