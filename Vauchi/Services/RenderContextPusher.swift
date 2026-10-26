// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Pushes `LocalizationService`'s locale and Core's kept restorable state to
// core's `RenderContext` via `setRenderContextJson`. Mirrors Android's
// `RenderContextPusher.kt`. S4 of `2026-05-16-settings-storage-by-sensitivity`.

import Foundation

#if canImport(VauchiPlatform)
    import VauchiPlatform

    /// Push the render context to core via `setRenderContextJson`.
    ///
    /// A JSON push replaces the whole context, so every push carries every
    /// field: the picked locale, the OS language and the restorable state
    /// Core asked the shell to keep (vauchi/private#814). The theme travels
    /// only inside that state; Core owns the pick.
    func pushRenderContext(engine: PlatformAppEngine?) {
        guard let engine else { return }
        let locale = LocalizationService.shared
        let json = buildRenderContextJson(
            locale: locale.followSystem ? nil : locale.selectedLocaleCode,
            systemLocale: Locale.preferredLanguages.first,
            restorableState: RestorableStateStore.standard.state
        )
        do {
            try engine.setRenderContextJson(json: json)
        } catch {
            NSLog("[RenderContextPusher] Failed: \(type(of: error))")
        }
    }

    /// Build a minimal JSON object for `RenderContext`. Omits keys whose
    /// effective value is `nil` ("follow system" semantic per ADR-047).
    /// `systemLocale` is the OS language, sent on every push: on "Follow
    /// system" no `locale` goes out, and core renders the system language
    /// only if it is told what it is (vauchi/private#721).
    func buildRenderContextJson(
        locale: String?,
        systemLocale: String?,
        restorableState: String?
    ) -> String {
        var parts: [String] = []
        if let locale {
            parts.append("\"locale\":\(jsonString(locale))")
        }
        if let systemLocale {
            parts.append("\"system_locale\":\(jsonString(systemLocale))")
        }
        if let restorableState {
            parts.append("\"restorable_state\":\(jsonString(restorableState))")
        }
        return "{" + parts.joined(separator: ",") + "}"
    }

    /// A JSON string literal; JSONEncoder escapes control characters too,
    /// which the restorable state may carry since Core owns its content.
    private func jsonString(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let literal = String(data: data, encoding: .utf8)
        else { return "\"\"" }
        return literal
    }

#endif
