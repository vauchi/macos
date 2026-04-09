// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UserNotifications
import VauchiPlatform

/// Service for managing local OS notifications on macOS.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        registerCategories()
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
    
    /// Poll for and display OS notifications (E).
    func pollAndDisplayNotifications(repository: VauchiRepository?) {
        guard let notifications = repository?.pollNotifications(), !notifications.isEmpty else { return }
        
        for notification in notifications {
            showNotification(notification)
        }
    }
    
    /// Display a single notification.
    func showNotification(_ notification: MobilePendingNotification) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.userInfo = [
            "contact_id": notification.contactId,
            "event_key": notification.eventKey
        ]
        
        switch notification.category {
        case .emergencyAlert:
            content.categoryIdentifier = "emergencyAlert"
        case .contactAdded:
            content.categoryIdentifier = "contactAdded"
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
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .list, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        #if DEBUG
        let userInfo = response.notification.request.content.userInfo
        let contactId = userInfo["contact_id"] as? String
        print("NotificationService: User tapped notification for contact: \(contactId ?? "nil")")
        #endif
        
        completionHandler()
    }
}
