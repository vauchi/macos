// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Picks the platform effects out of a Core envelope, which mixes them with
/// the presentation commands the reducer applies.
///
/// The reducer's own decoder decides, not a list kept beside it: a list
/// missed SetNavigation and DismissOverlay, which then reached the hardware
/// dispatcher as unknown commands and were answered as unavailable
/// (vauchi/private#707), as RequestBiometricUnlock once was.
enum NativeEffectSelection {
    /// The envelope with only its platform effects, or nil when it has none.
    static func platformEffectsJSON(in envelopeJSON: Data) throws -> Data? {
        guard var root = try JSONSerialization.jsonObject(with: envelopeJSON)
            as? [String: Any],
            let commands = root["commands"] as? [Any]
        else { return nil }
        let decoded = try JSONDecoder()
            .decode(PresentationCommandEnvelope.self, from: envelopeJSON)
            .commands
        let effects = zip(commands, decoded).compactMap { raw, command -> Any? in
            guard case .platformEffect = command else { return nil }
            return raw
        }
        guard !effects.isEmpty else { return nil }
        root["commands"] = effects
        return try JSONSerialization.data(withJSONObject: root)
    }
}
