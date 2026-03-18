//
//  LiveActivitiesSDK.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import Foundation
import ActivityKit

/// Main entry point for the PushPushGo Live Activities SDK.
///
/// All lifecycle methods are generic — they work with any `ActivityAttributes` type.
/// Adding a new template only requires defining a new model; the SDK API stays unchanged.
///
/// Usage:
/// ```swift
/// LiveActivitiesSDK.shared.initialize(apiKey: "KEY", projectId: "ID")
///
/// let id = LiveActivitiesSDK.shared.startActivity(
///     attributes: MatchActivityAttributes(matchId: "123", homeTeamName: "A", awayTeamName: "B"),
///     initialState: .init(homeScore: 0, awayScore: 0, phase: .preMatch, matchMinute: "0"),
///     templateId: "match"
/// )
/// ```
@available(iOS 16.2, *)
public class LiveActivitiesSDK {
    
    public static let shared = LiveActivitiesSDK()
    
    private var isInitialized = false
    private var manager: LiveActivityManager?
    
    private init() {}
    
    // Initialization
    
    /// Initialize the Live Activities SDK.
    /// Must be called once before any other method.
    public func initialize(
        apiKey: String,
        projectId: String,
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
    
    // Initialization guard (DRY)
    
    private func requireInitialized() -> LiveActivityManager? {
        guard isInitialized, let manager = manager else {
            LiveActivityLogger.shared.error("SDK not initialized. Call initialize() first.")
            return nil
        }
        return manager
    }
}
