// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: GPL-3.0-or-later

import VauchiPlatform

/// Typed wrappers around `PlatformAppEngine.dispatchDomainCommand` for
/// the macOS frontend.
///
/// macOS goes through `vauchi-platform-swift` like iOS does. Content
/// updates need no wrapper: Core schedules them itself once the app
/// listens (private#733).
///
/// More wrappers will be added here as macOS picks up further
/// Phase-B7 retirements; the file currently sits at exactly the
/// surface macOS needs.
extension PlatformAppEngine {
    func createIdentity(displayName: String) throws {
        _ = try dispatchDomainCommand(
            command: .createIdentity(displayName: displayName)
        )
    }
}
