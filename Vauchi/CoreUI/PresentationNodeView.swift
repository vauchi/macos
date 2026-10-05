// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreImage.CIFilterBuiltins
import SwiftUI

struct PresentationNodeView: View {
    let node: PresentationNode
    let surfaceID: String
    let minimumTarget: CGFloat
    let focusedBinding: FocusState<String?>.Binding
    let onEvent: (PresentationEvent) -> Void
    /// Whether this node's field held focus at the last change. Only a
    /// field that had it can report losing it.
    @State private var hadFocus = false

    var body: some View {
        switch node {
        case let .text(value):
            let style = textRoleStyle(for: value.style)
            Text(value.content)
                .font(style.font)
                .foregroundStyle(style.muted ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .accessibilityLabel(value.accessibility.label)
        case let .input(value):
            input(value)
        case let .toggle(value):
            Toggle(
                value.label,
                isOn: Binding(
                    get: { value.value },
                    set: { changed in
                        sendValue(value.bindingID, .boolean(changed))
                    }
                )
            )
            .disabled(!value.enabled)
            .accessibilityLabel(value.accessibility.label)
            .keyboardFocusRing(
                focusedBinding,
                equals: value.bindingID,
                color: ThemeService.shared.focusRing
            )
        case let .choice(value):
            choice(value)
        case let .group(value):
            GroupBox(value.label ?? "") {
                if value.axis == .horizontal {
                    HStack {
                        children(value.children)
                    }
                } else {
                    VStack(alignment: .leading) {
                        children(value.children)
                    }
                }
            }
            .accessibilityLabel(value.accessibility.label)
        case let .list(value):
            VStack(alignment: .leading, spacing: 8) {
                if let label = value.label {
                    Text(label).font(.headline)
                }
                ForEach(value.rows) { row in
                    PresentationRowView(
                        row: row,
                        surfaceID: surfaceID,
                        minimumTarget: minimumTarget,
                        focusedBinding: focusedBinding,
                        onEvent: onEvent
                    )
                }
            }
            .accessibilityLabel(value.accessibility.label)
        case let .image(value):
            image(value)
        case let .status(value):
            status(value)
        case let .qrCode(value):
            qrCode(value)
        case let .confirmation(value):
            confirmation(value)
        case let .slider(value):
            VStack(alignment: .leading) {
                Text(value.label)
                Slider(
                    value: Binding(
                        get: { value.value },
                        set: { changed in
                            sendValue(value.bindingID, .number(changed))
                        }
                    ),
                    in: value.minimum ... value.maximum,
                    step: value.step ?? 0.001
                )
            }
            .accessibilityLabel(value.accessibility.label)
        case let .progress(value):
            VStack(alignment: .leading) {
                if let label = value.label {
                    Text(label)
                }
                if let progress = value.value {
                    ProgressView(value: progress)
                } else {
                    ProgressView()
                }
            }
            .accessibilityLabel(value.accessibility.label)
        case .divider:
            Divider()
        }
    }

    private func input(_ value: PresentationInputNode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if value.inputKind == .password || value.inputKind == .pin {
                SecureField(
                    value.label,
                    text: textBinding(value)
                )
                .focused(focusedBinding, equals: value.bindingID)
            } else {
                TextField(
                    value.label,
                    text: textBinding(value),
                    prompt: value.placeholder.map(Text.init)
                )
                .textContentType(textContentType(for: value.inputKind))
                .focused(focusedBinding, equals: value.bindingID)
            }
            if let error = value.validationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(ThemeService.shared.error)
            }
        }
        .onSubmit {
            onEvent(
                .inputSubmitted(
                    surfaceID: surfaceID,
                    bindingID: value.bindingID
                )
            )
        }
        // SwiftUI models focus as one "which binding" value, so a field
        // learns it lost focus by watching that value move off itself.
        // `onChange` here reports only the new value, so the "was it us?"
        // half is tracked per node.
        .onChange(of: focusedBinding.wrappedValue) { current in
            if hadFocus, current != value.bindingID {
                onEvent(
                    .inputFocusEnded(
                        surfaceID: surfaceID,
                        bindingID: value.bindingID
                    )
                )
            }
            hadFocus = current == value.bindingID
        }
        .disabled(!value.enabled)
        .accessibilityLabel(value.accessibility.label)
    }

    private func textBinding(
        _ value: PresentationInputNode
    ) -> Binding<String> {
        Binding(
            get: { value.value },
            set: { changed in
                let limited = value.maxLength.map {
                    String(changed.prefix($0))
                } ?? changed
                sendValue(value.bindingID, .text(limited))
            }
        )
    }

    @ViewBuilder
    private func image(_ value: PresentationImageNode) -> some View {
        let spec = PresentationImageFrameSpec.node(size: value.size, minimumTarget: minimumTarget)
        let sized = PresentationImageContent(value: value, minimumTarget: spec.diameter)
        let content = spec.capsToAvailableWidth
            // Core named an exact square: cap there and shrink with the
            // row rather than flooring and growing to fill it, then
            // centre — the unsized branch below keeps the left-aligned,
            // grow-to-fill behaviour every avatar already relies on.
            ? AnyView(
                sized
                    .frame(maxWidth: spec.diameter, maxHeight: spec.diameter)
                    .frame(maxWidth: .infinity)
            )
            : AnyView(sized.frame(minWidth: spec.diameter, minHeight: spec.diameter))
        if let action = value.activation {
            Button {
                sendAction(action)
            } label: {
                content
            }
            .buttonStyle(.plain)
            .disabled(!action.enabled)
            .accessibilityLabel(action.accessibilityLabel)
            .keyboardFocusRing(
                focusedBinding,
                equals: action.interactionID,
                color: ThemeService.shared.focusRing
            )
        } else {
            content.accessibilityLabel(value.accessibility.label)
        }
    }

    /// No "none" row: Core rejects `Choice(None)`, so offering it only
    /// produced a rejected value. The label stays on the picker in both
    /// styles so VoiceOver reads what the segments choose between.
    @ViewBuilder
    private func choice(_ value: PresentationChoiceNode) -> some View {
        let picker = Picker(
            value.label,
            selection: Binding(
                get: { value.selected },
                set: { changed in
                    sendValue(value.bindingID, .choice(changed))
                }
            )
        ) {
            ForEach(value.options) { option in
                Text(option.label).tag(String?.some(option.id))
            }
        }
        .disabled(!value.enabled)
        .accessibilityLabel(value.accessibility.label)
        if value.prefersSegmentedControl {
            picker.pickerStyle(.segmented)
        } else {
            picker.pickerStyle(.menu)
        }
    }

    private func status(_ value: PresentationStatusNode) -> some View {
        HStack {
            if let icon = NavigationIconMap.statusIcon(for: value.iconToken) {
                NavigationIconImage(icon, pointSize: 24, relativeTo: .title3)
                    .font(.title3)
                    .foregroundStyle(toneColor(value.tone))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading) {
                Text(value.title).font(.headline)
                if let detail = value.detail {
                    Text(detail).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let badge = value.badge {
                Text(badge).font(.caption)
            }
            if let action = value.activation {
                Button(action.label) {
                    sendAction(action)
                }
                .disabled(!action.enabled)
                .keyboardFocusRing(
                    focusedBinding,
                    equals: action.interactionID,
                    color: ThemeService.shared.focusRing
                )
            }
        }
        .padding(8)
        .background(toneColor(value.tone).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(value.accessibility.label)
    }

    private func qrCode(_ value: PresentationNode.QrCode) -> some View {
        VStack {
            if let label = value.label {
                Text(label).font(.headline)
            }
            if value.purpose == .display,
               let placement = value.placement,
               let payload = value.payloads.first,
               let image = qrImage(payload, errorCorrection: value.errorCorrection)
            {
                placedQr(image, at: placement, label: value.accessibility.label)
            } else if value.purpose == .display,
                      let payload = value.payloads.first,
                      let image = qrImage(payload, errorCorrection: value.errorCorrection)
            {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: Self.qrSide, maxHeight: Self.qrSide)
                    .accessibilityLabel(value.accessibility.label)
            } else if value.purpose == .capture {
                TextField(
                    value.accessibility.label,
                    text: Binding(
                        get: { "" },
                        set: { sendValue(value.id, .text($0)) }
                    )
                )
                .focused(focusedBinding, equals: value.id)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func confirmation(
        _ value: PresentationNode.Confirmation
    ) -> some View {
        VStack(alignment: .leading) {
            Text(value.warning)
            HStack {
                Spacer()
                actionButton(value.cancel)
                actionButton(value.confirm)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(8)
        .background(ThemeService.shared.warning.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(value.accessibility.label)
    }

    private func actionButton(_ action: PresentationAction) -> some View {
        Button(action.label) {
            sendAction(action)
        }
        .disabled(!action.enabled)
        .accessibilityLabel(action.accessibilityLabel)
        .keyboardFocusRing(
            focusedBinding,
            equals: action.interactionID,
            color: ThemeService.shared.focusRing
        )
    }

    private func children(_ nodes: [PresentationNode]) -> some View {
        ForEach(identifyPresentationNodes(nodes)) { identified in
            PresentationNodeView(
                node: identified.node,
                surfaceID: surfaceID,
                minimumTarget: minimumTarget,
                focusedBinding: focusedBinding,
                onEvent: onEvent
            )
        }
    }

    private func sendAction(_ action: PresentationAction) {
        onEvent(
            .actionActivated(
                surfaceID: surfaceID,
                interactionID: action.interactionID
            )
        )
    }

    private func sendValue(
        _ bindingID: String,
        _ value: PresentationInputValue
    ) {
        onEvent(
            .valueChanged(
                surfaceID: surfaceID,
                bindingID: bindingID,
                value: value
            )
        )
    }

    private func toneColor(_ tone: PresentationTone) -> Color {
        switch tone {
        case .neutral: .secondary
        case .accent: .accentColor
        case .success: ThemeService.shared.success
        case .warning: ThemeService.shared.warning
        case .error: ThemeService.shared.error
        }
    }

    private func textContentType(
        for kind: PresentationInputKind
    ) -> NSTextContentType? {
        switch kind {
        case .email: .emailAddress
        case .phone: .telephoneNumber
        case .url: .URL
        case .password, .pin: .password
        default: nil
        }
    }

    /// The square a display code is drawn in, in points.
    static let qrSide: CGFloat = 240

    /// A placed code leaves part of the square empty. That part is white,
    /// so the peer's camera sees one bright square whatever the theme.
    private func placedQr(
        _ image: NSImage,
        at placement: QrPlacement,
        label: String
    ) -> some View {
        let frame = QrFrameSpec(placement: placement, squareSide: Self.qrSide)
        return Color.white // design-token-ok: a QR code needs a white quiet zone for the peer's camera
            .frame(width: Self.qrSide, height: Self.qrSide)
            .overlay(alignment: .topLeading) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: frame.side, height: frame.side)
                    .offset(x: frame.left, y: frame.top)
            }
            .accessibilityLabel(label)
    }

    private func qrImage(_ value: String, errorCorrection: String?) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = qrCorrectionLevel(errorCorrection)
        guard let output = filter.outputImage else { return nil }
        let representation = CIContext().createCGImage(
            output.transformed(by: .init(scaleX: 10, y: 10)),
            from: output.extent.applying(.init(scaleX: 10, y: 10))
        )
        return representation.map {
            NSImage(cgImage: $0, size: .init(width: Self.qrSide, height: Self.qrSide))
        }
    }
}

/// Not private: `PresentationImageContentTests` renders it directly, because
/// the defect it guards is a missing fill that no UI-level query can see.
struct PresentationImageContent: View {
    let value: PresentationImageNode
    /// The surface's pointer-target floor. Doubles as the fallback avatar's
    /// diameter, matching `PresentationRowView`'s row avatar.
    let minimumTarget: CGFloat

    var body: some View {
        if let data = value.data, let image = NSImage(data: Data(data)) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .brightness(Double(value.brightness))
                .clipShape(clipShape(for: imageDataSpec))
        } else if let fallback = value.fallbackText, !fallback.isEmpty {
            // The fill is the point. `clipShape` on a bare `Text` clips
            // nothing, because a `Text` paints no body — which is why the
            // initials read as a stray letter on the page rather than as
            // an avatar. `PresentationRowView` below already frames and
            // fills its own fallback; only this node was missing it.
            Text(fallback)
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
                .frame(width: fallbackSpec.diameter, height: fallbackSpec.diameter)
                .background(Color.secondary.opacity(AvatarFallbackSpec.fillOpacity))
                .clipShape(clipShape(for: fallbackSpec))
        }
    }

    private var fallbackSpec: AvatarFallbackSpec {
        .fallback(minimumTargetSize: minimumTarget)
    }

    private var imageDataSpec: AvatarFallbackSpec {
        .imageData(shape: value.shape, minimumTargetSize: minimumTarget)
    }

    private func clipShape(for spec: AvatarFallbackSpec) -> AnyShape {
        spec.clipsToCircle
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct PresentationRowView: View {
    /// Shell-minted handle so tests and automation can find a row's control
    /// without matching localized copy. Matches the iOS spelling.
    static let controlIdentifier = "presentationRowControl"

    let row: PresentationRow
    let surfaceID: String
    let minimumTarget: CGFloat
    let focusedBinding: FocusState<String?>.Binding
    let onEvent: (PresentationEvent) -> Void

    var body: some View {
        HStack {
            if let data = row.imageData, let image = NSImage(data: Data(data)) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: minimumTarget, height: minimumTarget)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
            } else if let fallback = row.fallbackText {
                Text(fallback)
                    .frame(width: minimumTarget, height: minimumTarget)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Circle())
            } else if let icon = NavigationIconMap.rowIcon(for: row.iconToken) {
                // Decorative: the row's accessibility label already names it.
                NavigationIconImage(icon, pointSize: 28, relativeTo: .headline)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading) {
                Text(row.title).font(.headline)
                if let subtitle = row.subtitle {
                    Text(subtitle).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let detail = row.detail {
                Text(detail).foregroundStyle(.secondary)
            }
            if let info = row.info {
                // Explains this one item (vauchi/private#479); Core names it
                // "About <item>" so VoiceOver says what the icon is for.
                Button {
                    activate(info)
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                .disabled(!info.enabled)
                .help(info.accessibilityLabel)
                .accessibilityLabel(info.accessibilityLabel)
            }
            controls
            if !row.secondaryActions.isEmpty {
                Menu {
                    ForEach(row.secondaryActions) { action in
                        Button(action.label) {
                            activate(action)
                        }
                        .disabled(!action.enabled)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Row actions")
            }
        }
        .padding(8)
        .background(row.selected ? Color.accentColor.opacity(0.12) : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if let action = row.activation, row.enabled, action.enabled {
                activate(action)
            }
        }
        .keyboardFocusRing(
            focusedBinding,
            equals: row.id,
            color: ThemeService.shared.focusRing
        )
        .accessibilityLabel(row.accessibility.label)
    }

    /// The controls Core attached to this row.
    ///
    /// Decoded and then discarded until 2026-08-21, exactly as on iOS,
    /// where it left six privacy settings rendering as text with no switch
    /// and no way to change them
    /// (`_private/docs/problems/2026-08-20-ios-settings-toggles-render-no-control/`).
    ///
    /// A row carrying controls has no activation of its own — Core sends
    /// the toggle instead — so the row-level tap gesture above cannot
    /// contend with the control for the same tap.
    private var controls: some View {
        ForEach(identifyPresentationNodes(row.controls)) { identified in
            PresentationNodeView(
                node: identified.node,
                surfaceID: surfaceID,
                minimumTarget: minimumTarget,
                focusedBinding: focusedBinding,
                onEvent: onEvent
            )
            .accessibilityIdentifier(Self.controlIdentifier)
        }
    }

    private func activate(_ action: PresentationAction) {
        onEvent(
            .actionActivated(
                surfaceID: surfaceID,
                interactionID: action.interactionID
            )
        )
    }
}
