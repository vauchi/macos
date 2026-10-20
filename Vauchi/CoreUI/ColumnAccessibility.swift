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
/// the host the split view makes for each column. Like the window's content
/// view (`WindowContentAccessibility`), it is SwiftUI's own container,
/// reachable only from AppKit; labelled (2967958787) the audit stops
/// flagging it.
///
/// Not used for the detail column: its host spans the whole window, title
/// bar included, and labelled it claims the full-screen button's child
/// (Parent/Child mismatch, 2968004201); `setAccessibilityElement(false)`
/// is ignored (2968128464). vauchi/private#722 tracks it.
///
/// Callers pass a label that already exists, `app.navigation` here.
struct ColumnAccessibility: NSViewRepresentable {
    let label: String
    let identifier: String
    var framesToContent = false

    func makeNSView(context _: Context) -> NSView {
        ColumnAccessibilityView()
    }

    func updateNSView(_ view: NSView, context _: Context) {
        guard let view = view as? ColumnAccessibilityView else { return }
        view.apply(label: label, identifier: identifier, framesToContent: framesToContent)
    }

    /// Zero-sized and never drawn; it exists to reach its ancestors.
    final class ColumnAccessibilityView: NSView {
        private var columnLabel = ""
        private var columnIdentifier = ""
        private var framesToContent = false

        func apply(label: String, identifier: String, framesToContent: Bool) {
            columnLabel = label
            columnIdentifier = identifier
            self.framesToContent = framesToContent
            labelColumn()
        }

        override func layout() {
            super.layout()
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
            if framesToContent, let window {
                // Diagnostic (vauchi/private#722): the host spans the whole
                // window, title bar included; narrowed to the content this
                // view sits behind, it should no longer cover the
                // full-screen button.
                column.setAccessibilityFrame(window.convertToScreen(convert(bounds, to: nil)))
            }
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
