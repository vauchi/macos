// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct PresentationCommandEnvelope: Decodable {
    let commands: [PresentationCommand]
}

struct RevisionedContextBar: Equatable {
    let revision: UInt64
    let bar: PresentationContextBar
}

struct RevisionedOverlay: Equatable {
    let surfaceID: String
    let revision: UInt64
    let overlay: PresentationOverlay
}

struct RevisionedNavigation: Equatable {
    let revision: UInt64
    let navigation: NavigationSpec
}

struct PresentationAlert: Decodable {
    let title: String
    let message: String
}

struct PresentationToast: Decodable {
    let message: String
}

struct PresentationExportFile: Decodable {
    let suggestedName: String
    let mimeType: String
    let data: [UInt8]

    private enum CodingKeys: String, CodingKey {
        case suggestedName = "suggested_name"
        case mimeType = "mime_type"
        case data
    }
}

indirect enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            self = try .array(container.decode([JSONValue].self))
        }
    }
}

private struct PresentationSurfaceCommandPayload: Decodable {
    let surface: PresentationSurface
}

private struct PresentationBarCommandPayload: Decodable {
    let surfaceID: String
    let revision: UInt64
    let bar: PresentationContextBar

    private enum CodingKeys: String, CodingKey {
        case surfaceID = "surface_id"
        case revision
        case bar
    }
}

private struct PresentationNavigationCommandPayload: Decodable {
    let surfaceID: String
    let revision: UInt64
    let navigation: NavigationSpec

    private enum CodingKeys: String, CodingKey {
        case surfaceID = "surface_id"
        case revision
        case navigation
    }
}

private struct PresentationOverlayCommandPayload: Decodable {
    let surfaceID: String
    let revision: UInt64
    let overlay: PresentationOverlay

    private enum CodingKeys: String, CodingKey {
        case surfaceID = "surface_id"
        case revision
        case overlay
    }
}

private struct PresentationDismissOverlayCommandPayload: Decodable {
    let surfaceID: String
    let revision: UInt64
    let kind: PresentationOverlayKind

    private enum CodingKeys: String, CodingKey {
        case surfaceID = "surface_id"
        case revision
        case kind
    }
}

private struct PresentationProfileCommandPayload: Decodable {
    let profile: PresentationProfile
}

private struct PresentationAlertCommandPayload: Decodable {
    let alert: PresentationAlert
}

private struct PresentationToastCommandPayload: Decodable {
    let toast: PresentationToast
}

private struct PresentationURLCommandPayload: Decodable {
    let url: String
}

private struct PresentationPromptCommandPayload: Decodable {
    let prompt: String
}

private struct PresentationSealCommandPayload: Decodable {
    let prompt: String
    let binding: UserPresenceBinding?

    private enum CodingKeys: String, CodingKey { case prompt, binding }

    /// An unknown binding decodes to `nil` instead of failing the whole
    /// envelope; the bridge then seals nothing (vauchi/private#778).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prompt = try container.decode(String.self, forKey: .prompt)
        binding = try? container.decode(UserPresenceBinding.self, forKey: .binding)
    }
}

/// Which OS check guards a sealed secret (Core 0.88.0, vauchi/private#778).
enum UserPresenceBinding: String, Decodable, Equatable {
    /// Only the biometrics enrolled when the secret was sealed.
    case biometry
    /// The login password.
    case deviceCredential = "device_credential"
}

private struct PresentationFileCommandPayload: Decodable {
    let file: PresentationExportFile
}

private struct PresentationNotificationCommandPayload: Decodable {
    let notification: JSONValue
}

enum PresentationCommand: Decodable {
    case replaceSurface(PresentationSurface)
    case setContextBar(RevisionedContextBar, surfaceID: String)
    case setNavigation(RevisionedNavigation, surfaceID: String)
    case presentOverlay(RevisionedOverlay)
    case dismissOverlay(surfaceID: String, revision: UInt64, kind: PresentationOverlayKind)
    case setPresentationProfile(PresentationProfile)
    case presentAlert(PresentationAlert)
    case showToast(PresentationToast)
    case openExternalURL(String)
    case exportFile(PresentationExportFile)
    case performNativeBack
    case resetApplication
    /// The lock screen's Touch ID button (Core 0.67.1). Answered with a
    /// `BiometricUnlockSucceeded` event once LocalAuthentication agrees.
    case requestBiometricUnlock
    /// Queued once a content update applied themes (core!1937): apply the
    /// selected theme again so a CDN theme takes effect (private#733).
    case reloadTheme
    /// Keep `state` per device, outside the vault, and hand it back as the
    /// render context's `restorable_state` (Core 0.90.0, vauchi/private#814).
    case saveRestorableState(String)
    /// Seal a fresh secret behind the OS user-presence check, then run the
    /// check with `prompt` as its reason (vauchi/private#712).
    case createUserPresenceSecret(prompt: String, binding: UserPresenceBinding?)
    /// Run the OS user-presence check with `prompt` and unseal that secret.
    case revealUserPresenceSecret(prompt: String)
    case postNotification(JSONValue)
    case platformEffect(variant: String, payload: JSONValue?)

    private struct DynamicKey: CodingKey {
        let stringValue: String
        let intValue: Int? = nil

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue _: Int) {
            nil
        }
    }

    init(from decoder: Decoder) throws {
        if let variant = try? decoder.singleValueContainer().decode(String.self) {
            self = Self.decodeStringVariant(variant)
        } else {
            self = try Self.decodeObject(from: decoder)
        }
    }

    private static func decodeObject(from decoder: Decoder) throws -> Self {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        guard let key = container.allKeys.first else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Empty command")
            )
        }
        switch key.stringValue {
        case "ReplaceSurface":
            return try .replaceSurface(
                container.decode(PresentationSurfaceCommandPayload.self, forKey: key).surface
            )
        case "SetContextBar":
            let value = try container.decode(PresentationBarCommandPayload.self, forKey: key)
            return .setContextBar(
                .init(revision: value.revision, bar: value.bar),
                surfaceID: value.surfaceID
            )
        case "SetNavigation":
            let value = try container.decode(
                PresentationNavigationCommandPayload.self, forKey: key
            )
            return .setNavigation(
                .init(revision: value.revision, navigation: value.navigation),
                surfaceID: value.surfaceID
            )
        case "PresentOverlay":
            let value = try container.decode(PresentationOverlayCommandPayload.self, forKey: key)
            return .presentOverlay(
                .init(
                    surfaceID: value.surfaceID,
                    revision: value.revision,
                    overlay: value.overlay
                )
            )
        case "DismissOverlay":
            let value = try container.decode(
                PresentationDismissOverlayCommandPayload.self, forKey: key
            )
            return .dismissOverlay(
                surfaceID: value.surfaceID,
                revision: value.revision,
                kind: value.kind
            )
        default:
            return try decodeEffect(from: container, key: key)
        }
    }

    private static func decodeEffect(
        from container: KeyedDecodingContainer<DynamicKey>,
        key: DynamicKey
    ) throws -> Self {
        switch key.stringValue {
        case "SetPresentationProfile":
            return try .setPresentationProfile(
                container.decode(PresentationProfileCommandPayload.self, forKey: key).profile
            )
        case "PresentAlert":
            return try .presentAlert(
                container.decode(PresentationAlertCommandPayload.self, forKey: key).alert
            )
        case "ShowToast":
            return try .showToast(
                container.decode(PresentationToastCommandPayload.self, forKey: key).toast
            )
        case "OpenExternalUrl":
            return try .openExternalURL(
                container.decode(PresentationURLCommandPayload.self, forKey: key).url
            )
        case "ExportFile":
            return try .exportFile(
                container.decode(PresentationFileCommandPayload.self, forKey: key).file
            )
        case "CreateUserPresenceSecret":
            let payload = try container.decode(PresentationSealCommandPayload.self, forKey: key)
            return .createUserPresenceSecret(prompt: payload.prompt, binding: payload.binding)
        case "RevealUserPresenceSecret":
            return try .revealUserPresenceSecret(
                prompt: container.decode(PresentationPromptCommandPayload.self, forKey: key).prompt
            )
        case "PostNotification":
            return try .postNotification(
                container.decode(PresentationNotificationCommandPayload.self, forKey: key)
                    .notification
            )
        default:
            return .platformEffect(
                variant: key.stringValue,
                payload: try? container.decode(JSONValue.self, forKey: key)
            )
        }
    }

    private static func decodeStringVariant(_ variant: String) -> Self {
        switch variant {
        case "PerformNativeBack": .performNativeBack
        case "ResetApplication": .resetApplication
        case "RequestBiometricUnlock": .requestBiometricUnlock
        case "ReloadTheme": .reloadTheme
        default: .platformEffect(variant: variant, payload: nil)
        }
    }
}
