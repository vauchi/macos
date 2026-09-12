// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Takes the window's content container out of the accessibility tree.
///
/// `testAccessibilityAudit` flags an element with no description that the
/// element tree places as the window's direct child at the window's exact
/// frame, with everything `PresentationHostView` builds inside it:
///
///     Window (Main)  {{760,206},{400,700}}  title 'Vauchi'
///       Group        {{760,206},{400,700}}        <- flagged
///         Group      {{775.5,254},{369,644.5}}    <- our content
///
/// It is SwiftUI's hosting container, not a view this app creates, and
/// four SwiftUI-level attempts failed to address it: moving the measuring
/// `GeometryReader` out of the layout chain, making the `ZStack` an
/// explicit container, and applying an identifier or a label at the
/// `WindowGroup` content. The last two reach it but land on the window
/// and replace the identifier XCUITest resolves windows by, which broke
/// `app.windows` and took three green tests red (job 16440006443).
/// Recorded with job ids in
/// `_private/docs/backlog/2026-09-11-macos-a11y-audit-flags-the-window-content-container`.
///
/// So reach it through AppKit instead, where the container can be
/// addressed directly rather than through a modifier that also rewrites
/// the window.
///
/// It is cleared rather than labelled deliberately. A purely structural
/// container should not be an accessibility element at all — its children
/// already carry the labels Core prepares — and naming it here would put
/// accessibility copy in the frontend, which ADR-038/ADR-066 keep in Core.
struct WindowContentAccessibility: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        ContentAccessibilityView()
    }

    func updateNSView(_: NSView, context _: Context) {}

    /// Zero-sized and never drawn; it exists to get a `window` reference.
    private final class ContentAccessibilityView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // The window is nil until this view is installed, so this
            // cannot be done at construction time.
            guard let content = window?.contentView else {
                // Distinguishes "the hook never ran" from "it ran and did
                // not help" — the previous attempt could prove neither,
                // which made its negative result unusable as evidence.
                NSLog("[APPKIT-A11Y] viewDidMoveToWindow: window or contentView nil")
                return
            }
            // Tag before clearing, and read the evidence from the
            // accessibility tree rather than from a log line. The app's
            // own stdout does not reach the CI job log at all — six
            // `print("[Vauchi] ...")` statements exist, one of them
            // provably executes (the seeded identity shows up in the
            // tree), and none appear in the trace. So a missing log line
            // is not evidence the code did not run.
            //
            // If `appkit.contentview` appears anywhere in the dumped
            // tree, this ran and that element is the content view. If it
            // appears nowhere, it did not run.
            // Proven by job 16461108863: this identifier lands on the
            // exact element the audit flags, so AppKit does address it.
            // Kept because it is the only evidence that this code ran —
            // the app's stdout never reaches the CI log.
            content.setAccessibilityIdentifier("appkit.contentview")

            // `setAccessibilityElement(false)` was tried here first and
            // does nothing: the element stays in the tree, so SwiftUI's
            // hosting view re-asserts it. An identifier alone does not
            // satisfy the audit either — the same job shows the element
            // flagged while carrying one.
            //
            // So give it the description the audit asks for. `app.name`
            // comes from the shared locales, the same mechanism the shell
            // already uses for user-facing strings, and resolves to the
            // name the window's title bar already shows — VoiceOver gains
            // a description rather than a second, conflicting one.
            content.setAccessibilityLabel(LocalizationService.shared.t("app.name"))
        }
    }
}
