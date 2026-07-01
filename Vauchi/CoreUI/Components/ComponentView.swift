// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Routes a Component enum to the appropriate SwiftUI view

import CoreUIModels
import SwiftUI

/// Routes a core `Component` to the appropriate SwiftUI view.
struct ComponentView: View {
    let component: Component
    let onAction: (UserAction) -> Void
    var onQrScanned: ((String) -> Void)?

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

        case let .preview(previewComponent):
            PreviewComponentView(component: previewComponent, onAction: onAction)

        case let .infoPanel(panelComponent):
            InfoPanelComponentView(component: panelComponent)

        case let .list(listComponent):
            ListComponentView(component: listComponent, onAction: onAction)

        case let .settingsGroup(settingsGroupComponent):
            SettingsGroupComponentView(component: settingsGroupComponent, onAction: onAction)

        case let .actionList(actionListComponent):
            ActionListComponentView(component: actionListComponent, onAction: onAction)

        case let .statusIndicator(statusComponent):
            StatusIndicatorComponentView(component: statusComponent)

        case let .pinInput(pinComponent):
            PinInputComponentView(component: pinComponent, onAction: onAction)

        case let .qrCode(qrComponent):
            QrCodeComponentView(
                component: qrComponent,
                onAction: onAction,
                onQrScanned: onQrScanned
            )

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

        case let .dropdown(dropdownComponent):
            DropdownComponentView(component: dropdownComponent, onAction: onAction)

        case let .indicator(indicatorComponent):
            IndicatorComponentView(component: indicatorComponent, onAction: onAction)

        case let .sectionedActionList(sectionedComponent):
            SectionedActionListComponentView(component: sectionedComponent, onAction: onAction)

        case let .row(rowComponent):
            // Horizontal container: render children left-to-right. The
            // first child (e.g. a camera/QR preview) flexes; later children
            // (e.g. an action list of buttons) take their share. Every
            // child is bounded to an equal slice via maxWidth: .infinity so
            // a child that fills its width internally (e.g. ActionList) only
            // fills its slice instead of overflowing and overlapping the
            // preview. Recurse through ComponentView for nesting.
            HStack(alignment: .center, spacing: 12) {
                ForEach(Array(rowComponent.items.enumerated()), id: \.offset) { _, child in
                    ComponentView(component: child, onAction: onAction, onQrScanned: onQrScanned)
                        .frame(maxWidth: .infinity)
                }
            }

        case let .avatarPreview(avatarComponent):
            AvatarPreviewComponentView(component: avatarComponent, onAction: onAction)

        case let .slider(sliderComponent):
            SliderComponentView(component: sliderComponent, onAction: onAction)

        case .divider:
            DividerComponentView()

        case .unknown:
            EmptyView()
        }
    }
}
