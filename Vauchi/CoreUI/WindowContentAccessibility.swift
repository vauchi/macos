// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Gives the window's content container the description the a11y audit asks for.
///
/// `testAccessibilityAudit` flagged an element with no description that the
/// element tree places as the window's direct child at the window's exact
/// frame, with everything `PresentationHostView` builds inside it:
///
///     Window (Main)  {{760,206},{400,700}}  title 'Vauchi'
///       Group        {{760,206},{400,700}}        <- flagged
///         Group      {{775.5,254},{369,644.5}}    <- our content
///
/// It is SwiftUI's hosting container, not a view this app creates, and six
/// SwiftUI-level attempts failed to address it: moving the measuring
/// `GeometryReader` out of the layout chain, making the `ZStack` an
/// explicit container, and applying an identifier or a label at the
/// `WindowGroup` content or inside `ContentView`. The ones that reach it
/// land on the window and replace the identifier XCUITest resolves windows
/// by, which broke `app.windows` and took three green tests red
/// (job 16440006443). Recorded with job ids in
/// `_private/docs/backlog/2026-09-11-macos-a11y-audit-flags-the-window-content-container`.
///
/// AppKit reaches it without that side effect. Job 16461108863 proved the
/// identity: the identifier set below lands on the exact element the audit
/// flags, so `window.contentView` *is* the flagged container.
///
/// Job 16461155146 then proved the label satisfies the audit — the
/// container's `sufficientElementDescription` issue is gone and the other
/// six UI tests stay green.
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
            guard let content = window?.contentView else { return }

            // The identifier is what proved this element is the flagged
            // one (job 16461108863), and it stays as the anchor any future
            // run can grep the dumped tree for. The app's own stdout never
            // reaches the CI job log, so a print statement cannot play
            // that role.
            content.setAccessibilityIdentifier("appkit.contentview")

            // `setAccessibilityElement(false)` was tried first and does
            // nothing — the element stays in the tree, so SwiftUI's
            // hosting view re-asserts it. An identifier alone does not
            // satisfy the audit either; the same job shows the element
            // flagged while carrying one. A description is what it wants.
            //
            // `app.name` comes from the shared locales, so this is not
            // frontend-authored copy: it is the same `t()` mechanism and
            // the same string the window's title bar already shows, so
            // VoiceOver gains a description rather than a second,
            // conflicting one. Core has no command for the window's own
            // container — it is OS chrome, below the shell protocol — so
            // there is nothing here for Core to prepare.
            content.setAccessibilityLabel(LocalizationService.shared.t("app.name"))
        }
    }
}
