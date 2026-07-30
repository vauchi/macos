// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum PresentationInputValue {
    case text(String)
    case boolean(Bool)
    case choice(String?)
    case number(Double)
}

private struct PresentationSurfaceEventPayload: Encodable {
    let surfaceID: String

    private enum CodingKeys: String, CodingKey {
        case surfaceID = "surface_id"
    }
}

private struct PresentationActionEventPayload: Encodable {
    let surfaceID: String
    let interactionID: String

    private enum CodingKeys: String, CodingKey {
        case surfaceID = "surface_id"
        case interactionID = "interaction_id"
    }
}

private struct PresentationValueEventPayload: Encodable {
    let surfaceID: String
    let bindingID: String
    let value: PresentationInputValue

    private enum CodingKeys: String, CodingKey {
        case surfaceID = "surface_id"
        case bindingID = "binding_id"
        case value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(surfaceID, forKey: .surfaceID)
        try container.encode(bindingID, forKey: .bindingID)
        try value.encode(to: container.superEncoder(forKey: .value))
    }
}

private struct PresentationOverlayEventPayload: Encodable {
    let surfaceID: String
    let kind: PresentationOverlayKind

    private enum CodingKeys: String, CodingKey {
        case surfaceID = "surface_id"
        case kind
    }
}

private struct PresentationEnvironmentEventPayload: Encodable {
    let availableWidth: UInt32
    let availableHeight: UInt32
    let inputModes: [PresentationInputMode]
    let motion: PresentationMotion

    private enum CodingKeys: String, CodingKey {
        case availableWidth = "available_width"
        case availableHeight = "available_height"
        case inputModes = "input_modes"
        case motion
    }
}

private struct PresentationDeepLinkEventPayload: Encodable {
    let uri: String
}

enum PresentationEvent: Encodable {
    case surfaceActivated(surfaceID: String)
    case actionActivated(surfaceID: String, interactionID: String)
    case valueChanged(
        surfaceID: String,
        bindingID: String,
        value: PresentationInputValue
    )
    case backRequested(surfaceID: String)
    case overlayDismissed(surfaceID: String, kind: PresentationOverlayKind)
    case environmentChanged(
        availableWidth: UInt32,
        availableHeight: UInt32,
        inputModes: [PresentationInputMode],
        motion: PresentationMotion
    )
    case deepLinkOpened(uri: String)
    case appBackgrounded
    case presentationInvalidated

    fileprivate struct DynamicKey: CodingKey {
        let stringValue: String
        let intValue: Int? = nil

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue _: Int) {
            nil
        }
    }

    func encode(to encoder: Encoder) throws {
        if case .appBackgrounded = self {
            var container = encoder.singleValueContainer()
            try container.encode("AppBackgrounded")
            return
        }
        if case .presentationInvalidated = self {
            var container = encoder.singleValueContainer()
            try container.encode("PresentationInvalidated")
            return
        }

        try encodePayload(to: encoder)
    }

    private func encodePayload(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        switch self {
        case let .surfaceActivated(surfaceID):
            try encodePayloadValue(
                PresentationSurfaceEventPayload(surfaceID: surfaceID),
                variant: "SurfaceActivated",
                into: &container
            )
        case let .actionActivated(surfaceID, interactionID):
            try encodePayloadValue(
                PresentationActionEventPayload(
                    surfaceID: surfaceID,
                    interactionID: interactionID
                ),
                variant: "ActionActivated",
                into: &container
            )
        case let .valueChanged(surfaceID, bindingID, value):
            try encodePayloadValue(
                PresentationValueEventPayload(
                    surfaceID: surfaceID,
                    bindingID: bindingID,
                    value: value
                ),
                variant: "ValueChanged",
                into: &container
            )
        case let .backRequested(surfaceID):
            try encodePayloadValue(
                PresentationSurfaceEventPayload(surfaceID: surfaceID),
                variant: "BackRequested",
                into: &container
            )
        case .overlayDismissed, .environmentChanged, .deepLinkOpened, .appBackgrounded,
             .presentationInvalidated:
            try encodeSecondaryPayload(into: &container)
        }
    }

    private func encodeSecondaryPayload(
        into container: inout KeyedEncodingContainer<DynamicKey>
    ) throws {
        switch self {
        case let .overlayDismissed(surfaceID, kind):
            try encodePayloadValue(
                PresentationOverlayEventPayload(surfaceID: surfaceID, kind: kind),
                variant: "OverlayDismissed",
                into: &container
            )
        case let .environmentChanged(width, height, inputModes, motion):
            try encodePayloadValue(
                PresentationEnvironmentEventPayload(
                    availableWidth: width,
                    availableHeight: height,
                    inputModes: inputModes,
                    motion: motion
                ),
                variant: "PresentationEnvironmentChanged",
                into: &container
            )
        case let .deepLinkOpened(uri):
            try encodePayloadValue(
                PresentationDeepLinkEventPayload(uri: uri),
                variant: "DeepLinkOpened",
                into: &container
            )
        case .appBackgrounded:
            break
        default:
            break
        }
    }

    private func encodePayloadValue(
        _ value: some Encodable,
        variant: String,
        into container: inout KeyedEncodingContainer<DynamicKey>
    ) throws {
        try container.encode(value, forKey: .init(stringValue: variant)!)
    }
}

private extension PresentationInputValue {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: PresentationEvent.DynamicKey.self)
        switch self {
        case let .text(value):
            try container.encode(
                value,
                forKey: .init(stringValue: "Text")!
            )
        case let .boolean(value):
            try container.encode(
                value,
                forKey: .init(stringValue: "Boolean")!
            )
        case let .choice(value):
            try container.encode(
                value,
                forKey: .init(stringValue: "Choice")!
            )
        case let .number(value):
            try container.encode(
                value,
                forKey: .init(stringValue: "Number")!
            )
        }
    }
}
