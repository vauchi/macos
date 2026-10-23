// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import Network

#if canImport(VauchiPlatform)
    import VauchiPlatform

    /// What a download costs on the current network path, for Core's
    /// content updates, which hold back on a metered network (private#733,
    /// D6).
    final class NetworkCostMonitor: ObservableObject {
        static let shared = NetworkCostMonitor()

        @Published private(set) var cost: MobileNetworkCost = .unknown

        private let monitor = NWPathMonitor()

        private init() {
            monitor.pathUpdateHandler = { [weak self] path in
                let cost = Self.cost(
                    isSatisfied: path.status == .satisfied,
                    isExpensive: path.isExpensive,
                    isConstrained: path.isConstrained
                )
                DispatchQueue.main.async {
                    self?.cost = cost
                }
            }
            monitor.start(queue: DispatchQueue(label: "app.vauchi.networkcost"))
        }

        static func cost(isSatisfied: Bool, isExpensive: Bool, isConstrained: Bool) -> MobileNetworkCost {
            guard isSatisfied else { return .unknown }
            return isExpensive || isConstrained ? .metered : .unmetered
        }
    }
#endif
