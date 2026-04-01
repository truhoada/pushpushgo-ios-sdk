//
//  LiveActivitiesSDK.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import Foundation
import ActivityKit

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
        
        PushSDKBridge.updateLAPermissionLabel(ActivityAuthorizationInfo().areActivitiesEnabled)
        
        self.isInitialized = true
        LiveActivityLogger.shared.info("LiveActivitiesSDK initialized")
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
    
    // Observer API (push-to-start flow)

    /// On iOS 18+ the activity will subscribe to a broadcast channel (1 push → all devices).
    /// On iOS 17.2–17.x each device gets individual pushes.
    ///
    /// - Parameters:
    ///   - type: The `ActivityAttributes` type for this template
    ///   - campaignId: Campaign identifier from PPG panel / API
    ///   - templateId: Template identifier for backend tracking (e.g. "match")
    ///   - onStatus: Callback with lifecycle status updates
    @available(iOS 17.2, *)
    public func observeLiveActivity<T: ActivityAttributes>(
        _ type: T.Type,
        campaignId: String,
        templateId: String,
        onStatus: @escaping @Sendable (LiveActivityObserverStatus) -> Void
    ) {
        guard let manager = requireInitialized() else {
            onStatus(.error(.activitiesNotEnabled))
            return
        }
        
        manager.observeCampaign(type, campaignId: campaignId, templateId: templateId, onStatus: onStatus)
    }
    
    /// Stop observing a campaign. Cancels push-to-start token observation
    /// and any pending activity state tracking.
    @available(iOS 17.2, *)
    public func stopObserving(campaignId: String) {
        guard let manager = requireInitialized() else { return }
        manager.stopObserving(campaignId: campaignId)
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
