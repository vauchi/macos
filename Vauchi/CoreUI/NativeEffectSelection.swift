// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Picks the platform effects out of a Core envelope, which mixes them with
/// the presentation commands the reducer applies.
enum NativeEffectSelection {
    private static let presentationVariants: Set = [
        "ReplaceSurface",
        "SetContextBar",
        "PresentOverlay",
        "SetPresentationProfile",
        "PresentAlert",
        "ShowToast",
        "OpenExternalUrl",
        "ExportFile",
        "PerformNativeBack",
        "ResetApplication",
        "RequestBiometricUnlock",
        "PostNotification",
    ]

    /// The envelope with only its platform effects, or nil when it has none.
    static func platformEffectsJSON(in envelopeJSON: Data) throws -> Data? {
        guard var root = try JSONSerialization.jsonObject(with: envelopeJSON)
            as? [String: Any],
            let commands = root["commands"] as? [Any]
        else { return nil }
        let effects = commands.filter { command in
            if let variant = command as? String {
                return !presentationVariants.contains(variant)
            }
            guard let object = command as? [String: Any],
                  let variant = object.keys.first
            else { return false }
            return !presentationVariants.contains(variant)
        }
        guard !effects.isEmpty else { return nil }
        root["commands"] = effects
        return try JSONSerialization.data(withJSONObject: root)
    }
}
