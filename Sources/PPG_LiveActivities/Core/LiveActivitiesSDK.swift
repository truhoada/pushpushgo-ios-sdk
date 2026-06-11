//
//  LiveActivitiesSDK.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import Foundation
import ActivityKit
import UIKit

/// Main entry point for the PushPushGo Live Activities SDK.

@available(iOS 17.2, *)
public class LiveActivitiesSDK {
    
    public static let shared = LiveActivitiesSDK()
    
    private var isInitialized = false
    private var manager: LiveActivityManager?
    
    private init() {}
    
    // Initialization
    
    /// Initialize the Live Activities SDK.
    /// Must be called once before any other method.
    /// - Parameters:
    ///   - apiKey: PPG API key
    ///   - projectId: PPG project identifier
    ///   - appGroupId: App Group identifier shared between main app and widget extension (required for badge images)
    ///   - isProduction: Use production API (default: true)
    ///   - isDebug: Enable debug logging (default: false)
    public func initialize(
        apiKey: String,
        projectId: String,
        appGroupId: String,
        isProduction: Bool = true,
        isDebug: Bool = false
    ) {
        LiveActivityLogger.shared.setDebugEnabled(isDebug)
        
        guard !isInitialized else {
            LiveActivityLogger.shared.info("LiveActivitiesSDK already initialized")
            return
        }
        
        guard !apiKey.isEmpty, !projectId.isEmpty else {
            LiveActivityLogger.shared.error("apiKey and projectId cannot be empty")
            return
        }
        
        let repository = LiveActivityRepository(apiKey: apiKey, projectId: projectId, isProduction: isProduction)
        self.manager = LiveActivityManager(repository: repository)
        
        LiveActivityImageManager.shared.configure(appGroupId: appGroupId)
        LiveActivityImageManager.shared.cleanExpiredAssets()
        
        HotMessageStore.shared.configure(appGroupId: appGroupId)
        LiveActivityDesignStore.shared.configure(appGroupId: appGroupId)
        
        PushSDKBridge.updateLAPermissionLabel(ActivityAuthorizationInfo().areActivitiesEnabled)
        
        self.isInitialized = true
        LiveActivityLogger.shared.info("LiveActivitiesSDK initialized")
    }
    
    // Widget Extension Configuration
    
    /// Configure SDK stores that the widget extension process needs in order
    /// to render Live Activities correctly. The widget runs in a separate
    /// process and does not inherit configuration from the host app, so this
    /// must be called from the widget's `init()`.
    ///
    /// Wires up:
    /// - `LiveActivityImageManager` — shared image cache for badge URLs.
    /// - `HotMessageStore` — persistent `receivedAt` timestamp store used to
    ///   keep transient hot-message windows stable across widget re-renders.
    ///
    /// Use the same `appGroupId` you pass to `initialize(...)` in the host app.
    public static func configureWidgetExtension(appGroupId: String) {
        LiveActivityImageManager.shared.configure(appGroupId: appGroupId)
        HotMessageStore.shared.configure(appGroupId: appGroupId)
        LiveActivityDesignStore.shared.configure(appGroupId: appGroupId)
    }
    
    // Generic Lifecycle API
    
    /// Start a Live Activity for any template.
    /// - Parameters:
    ///   - attributes: Static attributes (defines the template type via generics)
    ///   - initialState: Initial dynamic state
    ///   - templateId: Template identifier for backend tracking (e.g. "match")
    /// - Returns: Activity ID if successful, nil otherwise
    public func startActivity<T: ActivityAttributes>(
        attributes: T,
        initialState: T.ContentState,
        templateId: String
    ) -> String? {
        guard let manager = requireInitialized() else { return nil }
        return manager.startActivity(attributes: attributes, initialState: initialState, templateId: templateId)
    }
    
    /// Update a Live Activity with new state.
    public func updateActivity<T: ActivityAttributes>(
        _ type: T.Type,
        activityId: String,
        state: T.ContentState
    ) {
        guard let manager = requireInitialized() else { return }
        Task {
            await manager.updateActivity(type, activityId: activityId, state: state)
        }
    }
    
    /// End a Live Activity.
    public func endActivity<T: ActivityAttributes>(
        _ type: T.Type,
        activityId: String,
        finalState: T.ContentState? = nil,
        dismissPolicy: LiveActivityDismissPolicy = .default
    ) {
        guard let manager = requireInitialized() else { return }
        Task {
            await manager.endActivity(type, activityId: activityId, finalState: finalState, dismissPolicy: dismissPolicy)
        }
    }
    
    /// End all running activities of a given type.
    public func endAllActivities<T: ActivityAttributes>(ofType type: T.Type) {
        guard let manager = requireInitialized() else { return }
        Task {
            await manager.endAllActivities(ofType: type)
        }
    }
    
    /// Get info about all currently tracked activities.
    public func getActiveActivities() -> [LiveActivityInfo] {
        guard let manager = requireInitialized() else { return [] }
        return manager.getActiveActivities()
    }
    
    /// Check if Live Activities are enabled on this device.
    public func areActivitiesEnabled() -> Bool {
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }
    
    // Subscriber API (per-notification push-to-start flow)
    
    /// Subscribe this device to a specific Live Notification on the PPG
    /// backend. On registration the SDK:
    ///
    /// 1. Generates (or reuses) a persistent `installationId` UUIDv4.
    /// 2. Listens on `Activity<T>.pushToStartTokenUpdates`. On each new token
    ///    it POSTs `{ installationId, endpoint:{transport:APNS, remoteStartToken} }`
    ///    to `/core/projects/{project}/live-notifications/{id}/subscribers`.
    /// 3. When the backend pushes `event:start`, the OS creates a Live
    ///    Activity locally. The SDK then forwards every rotated
    ///    `activity.pushTokenUpdates` token via PUT `/subscribers/{id}/endpoint`
    ///    so subsequent `event:update` pushes can target this device.
    ///
    /// **Late-subscriber bootstrap**: if the campaign is already ONGOING when
    /// the device subscribes (e.g. user opens the app mid-match), no
    /// push-to-start will arrive. 
    ///
    /// - Parameters:
    ///   - type: The `ActivityAttributes` type matching the backend template
    ///     (e.g. `MatchActivityAttributes.self`).
    ///   - liveNotificationId: Identifier returned by the backend after the
    ///     match notification is created (`POST /football-match-tracking`).
    ///   - onCampaignAlreadyActive: Optional closure for late-subscriber
    ///     bootstrap. Receives raw JSON (`Data`) from `GET /live-notifications/{id}`.
    ///     Return `(attributes, initialState)` to start the activity locally,
    ///     or `nil` if the campaign is not yet active.
    ///   - onStatus: Lifecycle callback. Useful for diagnostics, in-app UI,
    ///     and forwarding errors. May fire from any thread.
    public func subscribe<T: ActivityAttributes>(
        _ type: T.Type,
        liveNotificationId: String,
        onCampaignAlreadyActive: (@Sendable (_ payload: Data) async throws -> (T, T.ContentState)?)? = nil,
        onStatus: @escaping @Sendable (LiveNotificationSubscriptionStatus) -> Void
    ) {
        guard let manager = requireInitialized() else {
            onStatus(.error(.activitiesNotEnabled))
            return
        }
        manager.subscribe(
            type,
            liveNotificationId: liveNotificationId,
            onCampaignAlreadyActive: onCampaignAlreadyActive,
            onStatus: onStatus
        )
    }
    
    /// Cancel an active subscription. Tears down local task observers and
    /// deletes the subscriber on the backend (`DELETE /subscribers/{id}`).
    public func unsubscribe(liveNotificationId: String) {
        guard let manager = requireInitialized() else { return }
        manager.unsubscribe(liveNotificationId: liveNotificationId)
    }
    
    // URL routing
    
    /// SDK-owned URL scheme used by CLOSE-type action buttons.
    /// Add this to your app's `CFBundleURLTypes` in Info.plist once:
    /// `<string>ppg-la</string>`
    public static let urlScheme = "ppg-la"
    
    /// Handle a URL delivered to the host app from a Live Activity action button
    /// or a body-tap `widgetURL`.
    ///
    /// Call this from your `onOpenURL` handler (SwiftUI) or
    /// `application(_:open:options:)` (UIKit). Returns `true` if the SDK
    /// handled the URL, or `false` if it is a custom-scheme deep link
    /// the app should route itself.
    ///
    /// - `http`/`https` — opened directly in the default browser.
    /// - `ppg-la://close?id=<liveNotificationId>` — emitted by CLOSE action
    ///   buttons; SDK calls `closeHandler` so the host app can end the activity.
    ///
    /// ```swift
    /// .onOpenURL { url in
    ///     if !LiveActivitiesSDK.handleURL(url, closeHandler: { id in
    ///         LiveActivitiesSDK.shared.endAllActivities(ofType: MatchActivityAttributes.self)
    ///     }) {
    ///         // handle your own deep-link scheme here
    ///     }
    /// }
    /// ```
    @discardableResult
    public static func handleURL(
        _ url: URL,
        closeHandler: ((String) -> Void)? = nil
    ) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }

        // `ppg-la://click?...` — a Live Activity tap. Record the statistics
        // event, then forward to the real destination carried in `to` (a body
        // tap with no deep link simply has no destination).
        if let click = LiveActivityClickURL.parse(url) {
            shared.manager?.reportClickEvent(
                liveNotificationId: click.liveNotificationId,
                type: click.type,
                liveDataVersion: click.liveDataVersion
            )
            guard let destination = click.destination else { return true }
            // http/https and `ppg-la://close` are handled here directly; a
            // custom-scheme deep link is re-opened so the host app routes it
            // (its own `onOpenURL` only ever saw the wrapper `ppg-la://click`).
            if handleURL(destination, closeHandler: closeHandler) {
                return true
            }
            UIApplication.shared.open(destination)
            return true
        }

        if scheme == "http" || scheme == "https" {
            UIApplication.shared.open(url)
            return true
        }
        
        if scheme == "ppg-la", url.host?.lowercased() == "close" {
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let liveNotifId = comps?.queryItems?.first(where: { $0.name == "id" })?.value ?? ""
            closeHandler?(liveNotifId)
            return true
        }
        
        return false
    }
    
    // Initialization guard (DRY)
    
    private func requireInitialized() -> LiveActivityManager? {
        guard isInitialized, let manager = manager else {
            LiveActivityLogger.shared.error("SDK not initialized. Call initialize() first.")
            return nil
        }
        return manager
    }
}
