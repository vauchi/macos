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
            Text(value.content)
                .font(font(for: value.style))
                .foregroundStyle(
                    value.style == .muted ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary)
                )
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
        case let .choice(value):
            Picker(
                value.label,
                selection: Binding(
                    get: { value.selected },
                    set: { changed in
                        sendValue(value.bindingID, .choice(changed))
                    }
                )
            ) {
                Text("—").tag(String?.none)
                ForEach(value.options) { option in
                    Text(option.label).tag(String?.some(option.id))
                }
            }
            .disabled(!value.enabled)
            .accessibilityLabel(value.accessibility.label)
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
                    .foregroundStyle(.red)
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
        let content = PresentationImageContent(value: value)
            .frame(minWidth: minimumTarget, minHeight: minimumTarget)
        if let action = value.activation {
            Button {
                sendAction(action)
            } label: {
                content
            }
            .buttonStyle(.plain)
            .disabled(!action.enabled)
            .accessibilityLabel(action.accessibilityLabel)
        } else {
            content.accessibilityLabel(value.accessibility.label)
        }
    }

    private func status(_ value: PresentationStatusNode) -> some View {
        HStack {
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
               let payload = value.payloads.first,
               let image = qrImage(payload)
            {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240, maxHeight: 240)
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
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(value.accessibility.label)
    }

    private func actionButton(_ action: PresentationAction) -> some View {
        Button(action.label) {
            sendAction(action)
        }
        .disabled(!action.enabled)
        .accessibilityLabel(action.accessibilityLabel)
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

    private func font(for style: PresentationTextStyle) -> Font {
        switch style {
        case .heading: .title2.bold()
        case .body: .body
        case .caption: .caption
        case .monospace: .system(.body, design: .monospaced)
        case .muted: .body
        }
    }

    private func toneColor(_ tone: PresentationTone) -> Color {
        switch tone {
        case .neutral: .secondary
        case .accent: .accentColor
        case .success: .green
        case .warning: .orange
        case .error: .red
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

    private func qrImage(_ value: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        guard let output = filter.outputImage else { return nil }
        let representation = CIContext().createCGImage(
            output.transformed(by: .init(scaleX: 10, y: 10)),
            from: output.extent.applying(.init(scaleX: 10, y: 10))
        )
        return representation.map {
            NSImage(cgImage: $0, size: .init(width: 240, height: 240))
        }
    }
}

private struct PresentationImageContent: View {
    let value: PresentationImageNode

    var body: some View {
        Group {
            if let data = value.data, let image = NSImage(data: Data(data)) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .brightness(Double(value.brightness - 1))
            } else {
                Text(value.fallbackText ?? "")
            }
        }
        .clipShape(
            value.shape == .circle
                ? AnyShape(Circle())
                : AnyShape(RoundedRectangle(cornerRadius: 8))
        )
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
