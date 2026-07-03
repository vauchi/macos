// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: GPL-3.0-or-later

import VauchiPlatform

/// Typed wrappers around `PlatformAppEngine.dispatchDomainCommand` for
/// the macOS frontend.
///
/// macOS goes through `vauchi-platform-swift` like iOS does. The
/// content-update cycle (check → apply → screen invalidation) runs
/// entirely in core (`DomainCommand::RunContentUpdateCycle`, core
/// 0.51.69); the frontend dispatches it and reads a presentation-only
/// outcome. This replaced the per-step `isContentUpdatesSupported` /
/// `checkContentUpdates` / `applyContentUpdates` wrappers, whose
/// domain sequencing had been duplicated on the `AppState` side.
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

    func runContentUpdateCycle() throws -> MobileContentCycleOutcome {
        let result = try dispatchDomainCommand(command: .runContentUpdateCycle)
        guard case let .contentUpdateCycle(outcome) = result else {
            throw MobileError.Other(
                detail: "RunContentUpdateCycle: unexpected result variant"
            )
        }
        return outcome
    }
}
