// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: GPL-3.0-or-later

import VauchiPlatform

/// Typed wrappers around `PlatformAppEngine.dispatchDomainCommand` for
/// the macOS frontend.
///
/// macOS goes through `vauchi-platform-swift` like iOS does. Core 0.51.2
/// retired the direct content-updates methods on `VauchiPlatform`
/// (`isContentUpdatesSupported`, `checkContentUpdates`,
/// `applyContentUpdates`) in favour of `DomainCommand` dispatch (B7
/// batch 2). The three wrappers below preserve the call shapes the
/// `AppState` startup path used to call against `vauchi.X(...)`, so
/// the migration is a `vauchi.X()` → `appEngine.X()` swap at the call
/// site.
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

    func isContentUpdatesSupported() throws -> Bool {
        let result = try dispatchDomainCommand(command: .isContentUpdatesSupported)
        guard case let .bool(value) = result else {
            throw MobileError.Other(
                detail: "IsContentUpdatesSupported: unexpected result variant"
            )
        }
        return value
    }

    func checkContentUpdates() throws -> MobileUpdateStatus {
        let result = try dispatchDomainCommand(command: .checkContentUpdates)
        guard case let .updateStatus(status) = result else {
            throw MobileError.Other(
                detail: "CheckContentUpdates: unexpected result variant"
            )
        }
        return status
    }

    func applyContentUpdates() throws -> MobileApplyResult {
        let result = try dispatchDomainCommand(command: .applyContentUpdates)
        guard case let .applyResult(value) = result else {
            throw MobileError.Other(
                detail: "ApplyContentUpdates: unexpected result variant"
            )
        }
        return value
    }
}
