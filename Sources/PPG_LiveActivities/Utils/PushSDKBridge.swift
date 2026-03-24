//
//  PushSDKBridge.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import Foundation

/// Bridge for communication with PPG_framework (Push SDK) without direct dependency.
/// Uses UserDefaults shared keys and NotificationCenter for loose coupling.
@available(iOS 17.2, *)
internal class PushSDKBridge {
    
    // Shared Keys (match PPG_framework's SharedData and PushNotificationStatusProvider)
    
    private static let isSubscribedKey = "_PushPushGoSDK_is_subscribed_"
    private static let areNotificationsBlockedKey = "_PushPushGoSDK_notifications_blocked_"
    private static let subscriberIdKey = "PPGSubscriberId"
    
    /// Live Activities permission label (written by this SDK, readable by push SDK for segmentation)
    private static let laPermissionEnabledKey = "_PushPushGoSDK_la_permission_enabled_"
    
    // Read Push SDK State
    
    /// Check if user is subscribed to push notifications
    static var isPushSubscribed: Bool {
        return UserDefaults.standard.bool(forKey: isSubscribedKey)
    }
    
    /// Check if push notifications are blocked at system level
    static var arePushNotificationsBlocked: Bool {
        return UserDefaults.standard.bool(forKey: areNotificationsBlockedKey)
    }
    
    /// Get the push subscriber ID (if available)
    static var subscriberId: String? {
        let id = UserDefaults.standard.string(forKey: subscriberIdKey) ?? ""
        return id.isEmpty ? nil : id
    }
    
    // Write Live Activities State (for Push SDK segmentation)
    
    /// Update the Live Activities permission enabled label
    /// This allows push SDK to segment users who have LA enabled
    static func updateLAPermissionLabel(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: laPermissionEnabledKey)
        LiveActivityLogger.shared.debug("LA permission label updated: \(enabled)")
    }
}
