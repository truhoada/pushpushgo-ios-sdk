//
//  LiveActivityManager.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import Foundation
import ActivityKit

/// Internal manager handling the lifecycle of Live Activities
/// Responsible for starting, updating, ending activities and managing push tokens
@available(iOS 16.2, *)
internal class LiveActivityManager {
    
    // Properties
    
    private let repository: LiveActivityRepository
    
    /// Tracks active activities: activityId -> LiveActivityInfo
    private var activeActivities: [String: LiveActivityInfo] = [:]
    
    /// Push token observation tasks
    private var tokenObservationTasks: [String: Task<Void, Never>] = [:]
    
    /// Persistence key for active activities
    private static let activeActivitiesKey = "PPGLiveActivities_Active"
    
    /// Template ID for the match template
    static let matchTemplateId = "match"
    
    // Initialization
    
    init(repository: LiveActivityRepository) {
        self.repository = repository
        restoreActiveActivities()
    }
    
    // Match Activity (Type-Safe Convenience)
    
    /// Start a new match Live Activity
    /// - Parameters:
    ///   - attributes: Static match attributes
    ///   - initialState: Initial match content state
    /// - Returns: Activity ID if successful, nil otherwise
    func startMatchActivity(
        attributes: MatchActivityAttributes,
        initialState: MatchActivityAttributes.ContentState
    ) -> String? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            LiveActivityLogger.shared.error("Live Activities are not enabled on this device")
            return nil
        }
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: .token
            )
            
            let activityId = activity.id
            LiveActivityLogger.shared.info("Match activity started: \(activityId)")
            
            // Track this activity
            let info = LiveActivityInfo(
                activityId: activityId,
                templateId: Self.matchTemplateId,
                pushToken: nil,
                startedAt: Date()
            )
            activeActivities[activityId] = info
            persistActiveActivities()
            
            // Start observing push token updates
            observePushTokenUpdates(for: activity, matchId: attributes.matchId)
            
            // Track event
            trackEvent(.started, activityId: activityId, templateId: Self.matchTemplateId)
            
            return activityId
            
        } catch {
            LiveActivityLogger.shared.error("Failed to start match activity: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Update a match Live Activity with new state
    /// - Parameters:
    ///   - activityId: The activity to update
    ///   - state: New content state
    func updateMatchActivity(
        activityId: String,
        state: MatchActivityAttributes.ContentState
    ) async {
        guard let activity = getMatchActivity(byId: activityId) else {
            LiveActivityLogger.shared.error("Match activity not found: \(activityId)")
            return
        }
        
        await activity.update(
            ActivityContent<MatchActivityAttributes.ContentState>(
                state: state,
                staleDate: nil
            )
        )
        
        LiveActivityLogger.shared.debug("Match activity updated: \(activityId)")
        trackEvent(.updated, activityId: activityId, templateId: Self.matchTemplateId)
    }
    
    /// End a match Live Activity
    /// - Parameters:
    ///   - activityId: The activity to end
    ///   - finalState: Optional final state to display
    ///   - dismissPolicy: When to remove from Lock Screen
    func endMatchActivity(
        activityId: String,
        finalState: MatchActivityAttributes.ContentState?,
        dismissPolicy: LiveActivityDismissPolicy
    ) async {
        guard let activity = getMatchActivity(byId: activityId) else {
            LiveActivityLogger.shared.error("Match activity not found: \(activityId)")
            return
        }
        
        let content: ActivityContent<MatchActivityAttributes.ContentState>?
        if let state = finalState {
            content = ActivityContent(state: state, staleDate: nil)
        } else {
            content = nil
        }
        
        let policy = mapDismissPolicy(dismissPolicy)
        
        await activity.end(content, dismissalPolicy: policy)
        
        // Clean up tracking
        cleanupActivity(activityId)
        
        LiveActivityLogger.shared.info("Match activity ended: \(activityId)")
        trackEvent(.ended, activityId: activityId, templateId: Self.matchTemplateId)
    }
    
    // Generic Activity Support
    
    /// Start a generic activity using dictionary-based data
    /// Used for future templates where type-safe wrappers don't exist yet
    /// - Parameters:
    ///   - templateId: Template identifier
    ///   - attributes: Static attributes as dictionary
    ///   - initialState: Initial state as dictionary
    /// - Returns: Activity ID if successful, nil otherwise
    func startActivity(
        templateId: String,
        attributes: [String: Any],
        initialState: [String: Any]
    ) -> String? {
        // For now, route known template IDs to their type-safe implementations
        if templateId == Self.matchTemplateId {
            guard let matchAttributes = decodeMatchAttributes(from: attributes),
                  let matchState = decodeMatchContentState(from: initialState) else {
                LiveActivityLogger.shared.error("Failed to decode match data from dictionary")
                return nil
            }
            return startMatchActivity(attributes: matchAttributes, initialState: matchState)
        }
        
        LiveActivityLogger.shared.error("Unknown template ID: \(templateId). Use type-safe methods or register template first.")
        return nil
    }
    
    /// Update a generic activity using dictionary-based data
    func updateActivity(activityId: String, state: [String: Any]) async {
        guard let info = activeActivities[activityId] else {
            LiveActivityLogger.shared.error("Activity not found: \(activityId)")
            return
        }
        
        if info.templateId == Self.matchTemplateId {
            guard let matchState = decodeMatchContentState(from: state) else {
                LiveActivityLogger.shared.error("Failed to decode match state from dictionary")
                return
            }
            await updateMatchActivity(activityId: activityId, state: matchState)
            return
        }
        
        LiveActivityLogger.shared.error("Unknown template ID for activity: \(info.templateId)")
    }
    
    /// End a generic activity
    func endActivity(
        activityId: String,
        finalState: [String: Any]?,
        dismissPolicy: LiveActivityDismissPolicy
    ) async {
        guard let info = activeActivities[activityId] else {
            LiveActivityLogger.shared.error("Activity not found: \(activityId)")
            return
        }
        
        if info.templateId == Self.matchTemplateId {
            var matchState: MatchActivityAttributes.ContentState? = nil
            if let stateDict = finalState {
                matchState = decodeMatchContentState(from: stateDict)
            }
            await endMatchActivity(activityId: activityId, finalState: matchState, dismissPolicy: dismissPolicy)
            return
        }
        
        LiveActivityLogger.shared.error("Unknown template ID for activity: \(info.templateId)")
    }
    
    /// End all active Live Activities
    func endAllActivities() async {
        for activity in Activity<MatchActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
            cleanupActivity(activity.id)
        }
        
        activeActivities.removeAll()
        persistActiveActivities()
        LiveActivityLogger.shared.info("All activities ended")
    }
    
    /// Get all currently active activities
    func getActiveActivities() -> [LiveActivityInfo] {
        return Array(activeActivities.values)
    }
    
    /// Check if Live Activities are available on this device
    func areActivitiesEnabled() -> Bool {
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }
    
    // Push Token Management
    
    /// Observe push token updates for a match activity and register with PPG backend
    private func observePushTokenUpdates(for activity: Activity<MatchActivityAttributes>, matchId: String) {
        let activityId = activity.id
        
        // Cancel any existing observation for this activity
        tokenObservationTasks[activityId]?.cancel()
        
        let task = Task {
            for await tokenData in activity.pushTokenUpdates {
                guard !Task.isCancelled else { break }
                
                let tokenHex = tokenData.map { String(format: "%02x", $0) }.joined()
                LiveActivityLogger.shared.debug("Push token for activity \(activityId): \(tokenHex)")
                
                // Update stored info with new token
                if let info = self.activeActivities[activityId] {
                    let updatedInfo = LiveActivityInfo(
                        activityId: info.activityId,
                        templateId: info.templateId,
                        pushToken: tokenHex,
                        startedAt: info.startedAt
                    )
                    self.activeActivities[activityId] = updatedInfo
                    self.persistActiveActivities()
                }
                
                // Register token with PPG backend
                self.repository.registerPushToken(
                    activityId: activityId,
                    templateId: Self.matchTemplateId,
                    pushToken: tokenHex
                ) { result in
                    switch result {
                    case .success:
                        LiveActivityLogger.shared.info("Push token registered for activity \(activityId)")
                    case .failure(let error):
                        LiveActivityLogger.shared.error("Failed to register push token: \(error.localizedDescription)")
                    }
                }
                
                self.trackEvent(.pushTokenRegistered, activityId: activityId, templateId: Self.matchTemplateId)
            }
        }
        
        tokenObservationTasks[activityId] = task
    }
    
    // Activity Lookup
    
    /// Find a running match activity by its ID
    private func getMatchActivity(byId activityId: String) -> Activity<MatchActivityAttributes>? {
        return Activity<MatchActivityAttributes>.activities.first { $0.id == activityId }
    }
    
    // Event Tracking
    
    private func trackEvent(_ eventType: LiveActivityEventType, activityId: String, templateId: String) {
        repository.trackEvent(
            eventType: eventType,
            activityId: activityId,
            templateId: templateId
        ) { result in
            if case .failure(let error) = result {
                LiveActivityLogger.shared.error("Failed to track event \(eventType.rawValue): \(error.localizedDescription)")
            }
        }
    }
    
    // Dismiss Policy Mapping
    
    private func mapDismissPolicy(_ policy: LiveActivityDismissPolicy) -> ActivityUIDismissalPolicy {
        switch policy {
        case .immediate:
            return .immediate
        case .after(let date):
            return .after(date)
        case .default:
            return .default
        }
    }
    
    // Dictionary Decoding Helpers
    
    private func decodeMatchAttributes(from dict: [String: Any]) -> MatchActivityAttributes? {
        guard let matchId = dict["matchId"] as? String,
              let homeTeamName = dict["homeTeamName"] as? String,
              let awayTeamName = dict["awayTeamName"] as? String else {
            return nil
        }
        
        return MatchActivityAttributes(
            matchId: matchId,
            homeTeamName: homeTeamName,
            awayTeamName: awayTeamName,
            homeTeamBadgeUrl: dict["homeTeamBadgeUrl"] as? String,
            awayTeamBadgeUrl: dict["awayTeamBadgeUrl"] as? String,
            deepLink: dict["deepLink"] as? String,
            ctaText: dict["ctaText"] as? String,
            ctaDeepLink: dict["ctaDeepLink"] as? String
        )
    }
    
    private func decodeMatchContentState(from dict: [String: Any]) -> MatchActivityAttributes.ContentState? {
        guard let homeScore = dict["homeScore"] as? Int,
              let awayScore = dict["awayScore"] as? Int,
              let matchPhase = dict["matchPhase"] as? String,
              let matchMinute = dict["matchMinute"] as? String else {
            return nil
        }
        
        return MatchActivityAttributes.ContentState(
            homeScore: homeScore,
            awayScore: awayScore,
            matchPhase: matchPhase,
            matchMinute: matchMinute,
            startDate: dict["startDate"] as? Date
        )
    }
    
    // Persistence
    
    private func persistActiveActivities() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let persistable = activeActivities.map { (key, value) in
            PersistableActivityInfo(
                activityId: value.activityId,
                templateId: value.templateId,
                pushToken: value.pushToken,
                startedAt: value.startedAt
            )
        }
        
        if let data = try? encoder.encode(persistable) {
            UserDefaults.standard.set(data, forKey: Self.activeActivitiesKey)
        }
    }
    
    private func restoreActiveActivities() {
        guard let data = UserDefaults.standard.data(forKey: Self.activeActivitiesKey) else { return }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let persisted = try? decoder.decode([PersistableActivityInfo].self, from: data) else { return }
        
        // Reconcile with actually running activities
        let runningActivityIds = Set(Activity<MatchActivityAttributes>.activities.map { $0.id })
        
        for info in persisted {
            if runningActivityIds.contains(info.activityId) {
                activeActivities[info.activityId] = LiveActivityInfo(
                    activityId: info.activityId,
                    templateId: info.templateId,
                    pushToken: info.pushToken,
                    startedAt: info.startedAt
                )
                
                // Re-observe push token updates for restored match activities
                if info.templateId == Self.matchTemplateId,
                   let activity = Activity<MatchActivityAttributes>.activities.first(where: { $0.id == info.activityId }) {
                    observePushTokenUpdates(for: activity, matchId: "")
                }
            }
        }
        
        // Clean up stale entries
        persistActiveActivities()
        
        LiveActivityLogger.shared.debug("Restored \(activeActivities.count) active activities")
    }
    
    private func cleanupActivity(_ activityId: String) {
        activeActivities.removeValue(forKey: activityId)
        tokenObservationTasks[activityId]?.cancel()
        tokenObservationTasks.removeValue(forKey: activityId)
        persistActiveActivities()
    }
}

// Persistence Model

@available(iOS 16.2, *)
private struct PersistableActivityInfo: Codable {
    let activityId: String
    let templateId: String
    let pushToken: String?
    let startedAt: Date
}
