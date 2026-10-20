// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Gives a `NavigationSplitView` column's hosting view the description the
/// a11y audit asks for (vauchi/private#714).
///
/// `testAccessibilityAudit` flagged a Group with no description around the
/// sidebar's list. A diagnostic run (macos pipeline 2967921702) named it:
/// the list's second AppKit ancestor,
/// `NSHostingView<ModifiedContent<ColumnView, NavigationPaneModifier<…>>>`,
/// the host the split view makes for each column. With that one labelled
/// (2967958787) the audit moved on to the detail column's, the full-window
/// Group above the active surface. Like the window's content view
/// (`WindowContentAccessibility`), these are SwiftUI's own containers,
/// reachable only from AppKit.
///
/// Callers pass a label that already exists: `app.navigation` for the
/// sidebar, and Core's own accessibility label of the active surface for
/// the detail column.
struct ColumnAccessibility: NSViewRepresentable {
    let label: String
    let identifier: String

    func makeNSView(context _: Context) -> NSView {
        ColumnAccessibilityView()
    }

    func updateNSView(_ view: NSView, context _: Context) {
        guard let view = view as? ColumnAccessibilityView else { return }
        view.apply(label: label, identifier: identifier)
    }

    /// Zero-sized and never drawn; it exists to reach its ancestors.
    final class ColumnAccessibilityView: NSView {
        private var columnLabel = ""
        private var columnIdentifier = ""

        func apply(label: String, identifier: String) {
            columnLabel = label
            columnIdentifier = identifier
            labelColumn()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            labelColumn()
        }

        private func labelColumn() {
            guard !columnIdentifier.isEmpty, let column = nearestHostingAncestor() else { return }
            // The anchor a later run can find the element by in the tree.
            column.setAccessibilityIdentifier(columnIdentifier)
            column.setAccessibilityLabel(columnLabel)
        }

        /// The column's host is the first hosting view above the content;
        /// the walk stops at the window's content view, so it never reaches
        /// the window, whose identifier XCUITest resolves windows by.
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
