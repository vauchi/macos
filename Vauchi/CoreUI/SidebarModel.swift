// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct SidebarRow: Identifiable, Equatable {
    let interactionID: String
    let label: String
    let accessibilityLabel: String
    let iconToken: String?
    let badgeCount: UInt32

    var id: String {
        interactionID
    }
}

/// Projects Core's `NavigationSpec` into the rows a persistent desktop
/// sidebar renders, isolated from SwiftUI so selection and the
/// hidden-when-empty rule (a locked app publishes no items) are testable
/// without a view hierarchy.
struct SidebarModel: Equatable {
    let rows: [SidebarRow]
    let selectedID: String?

    init(navigation: NavigationSpec?) {
        let items = navigation?.items ?? []
        rows = items.map {
            SidebarRow(
                interactionID: $0.interactionID,
                label: $0.label,
                accessibilityLabel: $0.accessibilityLabel,
                iconToken: $0.iconToken,
                badgeCount: $0.badgeCount
            )
        }
        selectedID = items.first(where: \.selected)?.interactionID
    }

    var isHidden: Bool {
        rows.isEmpty
    }

    var selectedIndex: Int? {
        guard let selectedID else { return nil }
        return rows.firstIndex { $0.interactionID == selectedID }
    }
}
