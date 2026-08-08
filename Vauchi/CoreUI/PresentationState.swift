// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum PresentationStateError: Error, Equatable {
    case staleSurface(String)
    case mismatchedContextBar(String)
    case mismatchedOverlay(String)
    case unknownProfileSurface(String)
}

struct PresentationState {
    private(set) var surfaces: [String: PresentationSurface] = [:]
    private(set) var bars: [String: RevisionedContextBar] = [:]
    private(set) var profile: PresentationProfile?
    private(set) var overlay: RevisionedOverlay?

    mutating func apply(
        _ commands: [PresentationCommand]
    ) throws -> [PresentationCommand] {
        var next = self
        var effects: [PresentationCommand] = []

        for command in commands {
            switch command {
            case let .replaceSurface(surface):
                // Core's revision advances only on user actions, so racing
                // full rebuilds (wakeup re-load, invalidation dispatch)
                // legitimately re-emit the same surface at the same
                // revision. Only a strictly older revision is stale; equal
                // re-applies, last-writer wins.
                //
                // Mirrors iOS, which has always compared strictly. macOS
                // rejected equal, and because transactions apply atomically
                // that discarded every command batched with it — the same
                // defect Android shipped (vauchi/android!610), where it
                // failed on every cold launch.
                if let previous = next.surfaces[surface.surfaceID],
                   surface.revision < previous.revision
                {
                    throw PresentationStateError.staleSurface(surface.surfaceID)
                }
                next.surfaces[surface.surfaceID] = surface
                next.bars.removeValue(forKey: surface.surfaceID)
                if next.overlay?.surfaceID == surface.surfaceID {
                    next.overlay = nil
                }
            case let .setContextBar(bar, surfaceID):
                guard next.surfaces[surfaceID]?.revision == bar.revision else {
                    throw PresentationStateError.mismatchedContextBar(surfaceID)
                }
                next.bars[surfaceID] = bar
            case let .presentOverlay(overlay):
                guard next.surfaces[overlay.surfaceID]?.revision == overlay.revision else {
                    throw PresentationStateError.mismatchedOverlay(overlay.surfaceID)
                }
                next.overlay = overlay
            case let .dismissOverlay(surfaceID, _, kind):
                // Core rewrites a repeat PresentOverlay into this so the
                // context-bar buttons toggle. Matching on kind as well as
                // surface keeps a stale dismiss from closing an overlay
                // Core has since replaced.
                if let open = next.overlay,
                   open.surfaceID == surfaceID,
                   open.overlay.kind == kind
                {
                    next.overlay = nil
                }
            case let .setPresentationProfile(profile):
                next.profile = profile
            default:
                effects.append(command)
            }
        }

        if let profile = next.profile {
            let referenced = [
                profile.primarySurface,
                profile.activeSurface,
                profile.detailSurface,
            ].compactMap { $0 }
            if let missing = referenced.first(where: { next.surfaces[$0] == nil }) {
                throw PresentationStateError.unknownProfileSurface(missing)
            }
        }

        self = next
        return effects
    }

    mutating func dismissOverlay() {
        overlay = nil
    }

    var activeSurfaceID: String? {
        profile?.activeSurface ?? surfaces.keys.sorted().first
    }

    var activeBar: PresentationContextBar? {
        activeSurfaceID.flatMap { bars[$0]?.bar }
    }

    /// The overlay, but only while the surface it was raised over is still the
    /// active one at the revision it was raised at.
    ///
    /// Core clears its own open-overlay state on every dispatch, so it expects
    /// an overlay to die with its surface and sends no dismissal when an item
    /// inside it navigates. `apply` already nils an overlay whose *own* surface
    /// is replaced; the case that survives is navigation to a different surface
    /// id, which left the menu drawn over the destination on iOS.
    var activeOverlay: RevisionedOverlay? {
        guard let overlay,
              overlay.surfaceID == activeSurfaceID,
              surfaces[overlay.surfaceID]?.revision == overlay.revision
        else {
            return nil
        }
        return overlay
    }

    var visibleSurfaceIDs: [String] {
        guard let profile else {
            return activeSurfaceID.map { [$0] } ?? []
        }
        if profile.paneLayout == .single {
            return [profile.activeSurface]
        }
        return [
            profile.primarySurface,
            profile.detailSurface,
        ].compactMap { $0 }
    }
}
