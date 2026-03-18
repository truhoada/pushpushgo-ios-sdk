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
/// Provides both generic methods (for any template) and type-safe convenience
/// methods for specific templates (e.g., football match).
///
/// Usage:
/// ```swift
/// // Initialize once at app launch
/// LiveActivitiesSDK.shared.initialize(
///     apiKey: "YOUR_API_KEY",
///     projectId: "YOUR_PROJECT_ID"
/// )
///
/// // Start a match activity
/// let activityId = LiveActivitiesSDK.shared.startMatchActivity(
///     attributes: MatchActivityAttributes(
///         matchId: "match-123",
///         homeTeamName: "Team A",
///         awayTeamName: "Team B"
///     ),
///     initialState: .init(homeScore: 0, awayScore: 0, phase: .preMatch, matchMinute: "0")
/// )
/// ```
@available(iOS 16.2, *)
public class LiveActivitiesSDK {
    
    // Singleton
    
    public static let shared = LiveActivitiesSDK()
    
    // Properties
    
    private var isInitialized = false
    private var config: LiveActivityConfig?
    private var manager: LiveActivityManager?
    private var repository: LiveActivityRepository?
    
    private init() {}
    
    // Initialization
    
    /// Initialize the Live Activities SDK with API credentials
    /// - Parameters:
    ///   - apiKey: API key for PPG authentication
    ///   - projectId: Project ID for the PPG project
    ///   - isProduction: Use production or test environment (default: true)
    ///   - isDebug: Enable debug logging (default: false)
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
        
        guard !apiKey.isEmpty else {
            LiveActivityLogger.shared.error("apiKey cannot be empty")
            return
        }
        guard !projectId.isEmpty else {
            LiveActivityLogger.shared.error("projectId cannot be empty")
            return
        }
        
        self.config = LiveActivityConfig(
            apiKey: apiKey,
            projectId: projectId,
            isProduction: isProduction,
            isDebug: isDebug
        )
        
        self.repository = LiveActivityRepository(
            apiKey: apiKey,
            projectId: projectId,
            isProduction: isProduction
        )
        self.manager = LiveActivityManager(repository: repository!)
        
        // Update Live Activities permission label via UserDefaults bridge
        let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
        UserDefaults.standard.set(enabled, forKey: "_PushPushGoSDK_la_permission_enabled_")
        
        self.isInitialized = true
        LiveActivityLogger.shared.info("LiveActivitiesSDK initialized (activities enabled: \(enabled))")
    }
    
    // Generic API (works with any template)
    
    /// Start a Live Activity using dictionary-based data
    /// - Parameters:
    ///   - templateId: Template identifier (e.g. "match")
    ///   - attributes: Static attributes as dictionary
    ///   - initialState: Initial dynamic state as dictionary
    /// - Returns: Activity ID if successful, nil otherwise
    public func startActivity(
        templateId: String,
        attributes: [String: Any],
        initialState: [String: Any]
    ) -> String? {
        guard isInitialized, let manager = manager else {
            LiveActivityLogger.shared.error("SDK not initialized. Call initialize() first.")
            return nil
        }
        
        return manager.startActivity(
            templateId: templateId,
            attributes: attributes,
            initialState: initialState
        )
    }
    
    /// Update a Live Activity using dictionary-based data
    /// - Parameters:
    ///   - activityId: The activity to update
    ///   - state: New dynamic state as dictionary
    public func updateActivity(activityId: String, state: [String: Any]) {
        guard isInitialized, let manager = manager else {
            LiveActivityLogger.shared.error("SDK not initialized. Call initialize() first.")
            return
        }
        
        Task {
            await manager.updateActivity(activityId: activityId, state: state)
        }
    }
    
    /// End a Live Activity
    /// - Parameters:
    ///   - activityId: The activity to end
    ///   - finalState: Optional final state to display (as dictionary)
    ///   - dismissPolicy: When to remove from Lock Screen
    public func endActivity(
        activityId: String,
        finalState: [String: Any]? = nil,
        dismissPolicy: LiveActivityDismissPolicy = .default
    ) {
        guard isInitialized, let manager = manager else {
            LiveActivityLogger.shared.error("SDK not initialized. Call initialize() first.")
            return
        }
        
        Task {
            await manager.endActivity(
                activityId: activityId,
                finalState: finalState,
                dismissPolicy: dismissPolicy
            )
        }
    }
    
    /// End all active Live Activities
    public func endAllActivities() {
        guard isInitialized, let manager = manager else {
            LiveActivityLogger.shared.error("SDK not initialized. Call initialize() first.")
            return
        }
        
        Task {
            await manager.endAllActivities()
        }
    }
    
    /// Get information about all currently active Live Activities
    /// - Returns: Array of LiveActivityInfo
    public func getActiveActivities() -> [LiveActivityInfo] {
        guard isInitialized, let manager = manager else {
            LiveActivityLogger.shared.error("SDK not initialized. Call initialize() first.")
            return []
        }
        
        return manager.getActiveActivities()
    }
    
    /// Check if Live Activities are enabled on this device
    /// - Returns: true if the user has granted permission
    public func areActivitiesEnabled() -> Bool {
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }
    
    // Match Template (Type-Safe Convenience)
    
    /// Start a football match Live Activity
    /// - Parameters:
    ///   - attributes: Static match attributes (teams, badges, deep links)
    ///   - initialState: Initial match state (score 0:0, PRE_MATCH)
    /// - Returns: Activity ID if successful, nil otherwise
    public func startMatchActivity(
        attributes: MatchActivityAttributes,
        initialState: MatchActivityAttributes.ContentState
    ) -> String? {
        guard isInitialized, let manager = manager else {
            LiveActivityLogger.shared.error("SDK not initialized. Call initialize() first.")
            return nil
        }
        
        return manager.startMatchActivity(
            attributes: attributes,
            initialState: initialState
        )
    }
    
    /// Update a football match Live Activity with new state
    /// - Parameters:
    ///   - activityId: The match activity to update
    ///   - state: New match state (score, phase, minute)
    public func updateMatchActivity(
        activityId: String,
        state: MatchActivityAttributes.ContentState
    ) {
        guard isInitialized, let manager = manager else {
            LiveActivityLogger.shared.error("SDK not initialized. Call initialize() first.")
            return
        }
        
        Task {
            await manager.updateMatchActivity(activityId: activityId, state: state)
        }
    }
    
    /// End a football match Live Activity
    /// - Parameters:
    ///   - activityId: The match activity to end
    ///   - finalState: Optional final state (final score, MATCH_ENDED)
    ///   - dismissPolicy: When to remove from Lock Screen (default: system default ~4h)
    public func endMatchActivity(
        activityId: String,
        finalState: MatchActivityAttributes.ContentState? = nil,
        dismissPolicy: LiveActivityDismissPolicy = .default
    ) {
        guard isInitialized, let manager = manager else {
            LiveActivityLogger.shared.error("SDK not initialized. Call initialize() first.")
            return
        }
        
        Task {
            await manager.endMatchActivity(
                activityId: activityId,
                finalState: finalState,
                dismissPolicy: dismissPolicy
            )
        }
    }
}
