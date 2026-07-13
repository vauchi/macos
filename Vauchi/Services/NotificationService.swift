// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UserNotifications
import VauchiPlatform

/// Service for managing local OS notifications on macOS.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        registerCategories()
    }

    /// Relays a tapped notification's core-supplied deep-link URI to the app,
    /// which forwards it to core as `UserAction::LinkOpened`. Humble: the service
    /// never interprets the URI — core owns routing. Buffers a cold-launch tap
    /// until the app wires the handler.
    var onDeepLinkTapped: ((String) -> Void)? {
        didSet {
            guard let uri = pendingDeepLinkUri, let handler = onDeepLinkTapped else { return }
            pendingDeepLinkUri = nil
            handler(uri)
        }
    }

    private var pendingDeepLinkUri: String?

    /// Extracts the deep-link URI stashed in `userInfo` at display time. Pure so
    /// it is unit-testable without a live `UNUserNotificationCenter`.
    static func deepLinkUri(from userInfo: [AnyHashable: Any]) -> String? {
        userInfo["deep_link_uri"] as? String
    }

    /// Request notification permissions from the user.
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("NotificationService: requestAuthorization failed: \(error)")
            }

            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    /// Register notification categories and actions.
    func registerCategories() {
        // TODO(HUMBLE): T — maps NotificationCategory to OS category IDs and
        // builds userInfo payload (see _private problem record
        // 2026-07-06-desktop-tui-web-domain-shell-violations).
        let center = UNUserNotificationCenter.current()

        let emergencyCategory = UNNotificationCategory(
            identifier: "emergencyAlert",
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        let updateCategory = UNNotificationCategory(
            identifier: "contactAdded",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([emergencyCategory, updateCategory])
    }

    /// Display a single notification.
    func showNotification(_ notification: MobilePendingNotification) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        var userInfo: [String: Any] = [
            "contact_id": notification.contactId,
            "event_key": notification.eventKey,
        ]
        // Core supplies the tap target (`vauchi://contact/<id>`); stash it so
        // `didReceive` can relay it back to core as `LinkOpened`.
        if let deepLinkUri = notification.deepLinkUri {
            userInfo["deep_link_uri"] = deepLinkUri
        }
        content.userInfo = userInfo

        switch notification.category {
        case .emergencyAlert:
            content.categoryIdentifier = "emergencyAlert"
        case .contactAdded:
            content.categoryIdentifier = "contactAdded"
        case .cardUpdate:
            content.categoryIdentifier = "cardUpdated"
        case .duressAlert:
            content.categoryIdentifier = "duressAlert"
        }

        let request = UNNotificationRequest(
            identifier: notification.eventKey,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("NotificationService: Failed to add notification: \(error)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let uri = Self.deepLinkUri(from: response.notification.request.content.userInfo) {
            if let handler = onDeepLinkTapped {
                handler(uri)
            } else {
                pendingDeepLinkUri = uri // cold launch: flush once the app wires the handler
            }
        }

        completionHandler()
    }
}
