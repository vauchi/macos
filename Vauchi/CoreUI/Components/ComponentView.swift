// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// ComponentView.swift
// Routes a Component enum to the appropriate SwiftUI view

import SwiftUI

/// Routes a core `Component` to the appropriate SwiftUI view.
struct ComponentView: View {
    let component: Component
    let onAction: (UserAction) -> Void

    var body: some View {
        switch component {
        case let .text(textComponent):
            TextComponentView(component: textComponent)

        case let .textInput(inputComponent):
            TextInputComponentView(component: inputComponent, onAction: onAction)

        case let .toggleList(toggleComponent):
            ToggleListComponentView(component: toggleComponent, onAction: onAction)

        case let .fieldList(fieldComponent):
            FieldListComponentView(component: fieldComponent, onAction: onAction)

        case let .cardPreview(previewComponent):
            CardPreviewComponentView(component: previewComponent, onAction: onAction)

        case let .infoPanel(panelComponent):
            InfoPanelComponentView(component: panelComponent)

        case let .contactList(contactListComponent):
            ContactListComponentView(component: contactListComponent, onAction: onAction)

        case let .settingsGroup(settingsGroupComponent):
            SettingsGroupComponentView(component: settingsGroupComponent, onAction: onAction)

        case let .actionList(actionListComponent):
            ActionListComponentView(component: actionListComponent, onAction: onAction)

        case let .statusIndicator(statusComponent):
            StatusIndicatorComponentView(component: statusComponent)

        case let .pinInput(pinComponent):
            PinInputComponentView(component: pinComponent, onAction: onAction)

        case let .qrCode(qrComponent):
            QrCodeComponentView(component: qrComponent, onAction: onAction)

        case let .confirmationDialog(dialogComponent):
            ConfirmationDialogComponentView(component: dialogComponent, onAction: onAction)

        case let .showToast(toastComponent):
            // Toast rendering is handled at the screen level, not inline
            EmptyView()
                .onAppear {
                    print("ComponentView: ShowToast should be handled at screen level: \(toastComponent.message)")
                }

        case let .inlineConfirm(confirmComponent):
            InlineConfirmComponentView(component: confirmComponent, onAction: onAction)

        case let .editableText(editableComponent):
            EditableTextComponentView(component: editableComponent, onAction: onAction)

        case let .banner(bannerComponent):
            BannerComponentView(component: bannerComponent, onAction: onAction)

        case .divider:
            DividerComponentView()

        case .unknown:
            EmptyView()
        }
    }
}
