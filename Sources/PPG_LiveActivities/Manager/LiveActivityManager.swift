//
//  LiveActivityManager.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import Foundation
import ActivityKit

@available(iOS 17.2, *)
internal class LiveActivityManager {
    
    private let repository: LiveActivityRepository
    private var activeActivities: [String: LiveActivityInfo] = [:]
    private var tokenObservationTasks: [String: Task<Void, Never>] = [:]
    private static let persistenceKey = "PPGLiveActivities_Active"
    
    init(repository: LiveActivityRepository) {
        self.repository = repository
        restoreActiveActivities()
    }
    
    // Lifecycle
    
    func startActivity<T: ActivityAttributes>(
        attributes: T,
        initialState: T.ContentState,
        templateId: String
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
            LiveActivityLogger.shared.info("Activity started [\(templateId)]: \(activityId)")
            
            let info = LiveActivityInfo(
                activityId: activityId,
                templateId: templateId,
                pushToken: nil,
                startedAt: Date()
            )
            activeActivities[activityId] = info
            persistActiveActivities()
            
            observePushTokenUpdates(for: activity, templateId: templateId)
            trackEvent(.started, activityId: activityId, templateId: templateId)
            
            return activityId
        } catch {
            LiveActivityLogger.shared.error("Failed to start activity [\(templateId)]: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Update any Live Activity with a new content state.
    func updateActivity<T: ActivityAttributes>(
        _ type: T.Type,
        activityId: String,
        state: T.ContentState
    ) async {
        guard let activity = findActivity(T.self, byId: activityId) else {
            LiveActivityLogger.shared.error("Activity not found: \(activityId)")
            return
        }
        
        await activity.update(
            ActivityContent<T.ContentState>(state: state, staleDate: nil)
        )
        
        let templateId = activeActivities[activityId]?.templateId ?? "unknown"
        LiveActivityLogger.shared.debug("Activity updated [\(templateId)]: \(activityId)")
        trackEvent(.updated, activityId: activityId, templateId: templateId)
    }
    
    /// End any Live Activity.
    func endActivity<T: ActivityAttributes>(
        _ type: T.Type,
        activityId: String,
        finalState: T.ContentState?,
        dismissPolicy: LiveActivityDismissPolicy
    ) async {
        guard let activity = findActivity(T.self, byId: activityId) else {
            LiveActivityLogger.shared.error("Activity not found: \(activityId)")
            return
        }
        
        let content: ActivityContent<T.ContentState>? = finalState.map {
            ActivityContent(state: $0, staleDate: nil)
        }
        
        await activity.end(content, dismissalPolicy: dismissPolicy.toSystemPolicy())
        
        let templateId = activeActivities[activityId]?.templateId ?? "unknown"
        cleanupActivity(activityId)
        LiveActivityLogger.shared.info("Activity ended [\(templateId)]: \(activityId)")
        trackEvent(.ended, activityId: activityId, templateId: templateId)
    }
    
    /// End all running activities for a given `ActivityAttributes` type.
    func endAllActivities<T: ActivityAttributes>(ofType type: T.Type) async {
        for activity in Activity<T>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
            cleanupActivity(activity.id)
        }
        LiveActivityLogger.shared.info("All activities of type \(T.self) ended")
    }
    
    func getActiveActivities() -> [LiveActivityInfo] {
        return Array(activeActivities.values)
    }
    
    // Observer Management (push-to-start flow)
    
    private var observers: [String: Any] = [:]
    
    @available(iOS 17.2, *)
    func observeCampaign<T: ActivityAttributes>(
        _ type: T.Type,
        campaignId: String,
        templateId: String,
        onStatus: @escaping @Sendable (LiveActivityObserverStatus) -> Void
    ) {
        // Cancel any existing observer for this campaign
        stopObserving(campaignId: campaignId)
        
        let observer = LiveActivityObserver<T>(
            repository: repository,
            campaignId: campaignId,
            templateId: templateId,
            statusHandler: onStatus
        )
        observers[campaignId] = observer
        observer.start()
        
        LiveActivityLogger.shared.info("Observing campaign: \(campaignId)")
    }
    
    @available(iOS 17.2, *)
    func stopObserving(campaignId: String) {
        if observers.removeValue(forKey: campaignId) != nil {
            LiveActivityLogger.shared.info("Stopped observing campaign: \(campaignId)")
        }
    }
    
    // Push Token Management
    
    private func observePushTokenUpdates<T: ActivityAttributes>(
        for activity: Activity<T>,
        templateId: String
    ) {
        let activityId = activity.id
        tokenObservationTasks[activityId]?.cancel()
        
        let task = Task { [weak self] in
            for await tokenData in activity.pushTokenUpdates {
                guard !Task.isCancelled, let self else { break }
                
                let tokenHex = tokenData.map { String(format: "%02x", $0) }.joined()
                LiveActivityLogger.shared.debug("Push token [\(templateId)] \(activityId): \(tokenHex)")
                
                self.updateStoredToken(activityId: activityId, token: tokenHex)
                
                self.repository.registerPushToken(
                    activityId: activityId,
                    templateId: templateId,
                    pushToken: tokenHex
                ) { result in
                    switch result {
                    case .success:
                        LiveActivityLogger.shared.info("Push token registered for \(activityId)")
                    case .failure(let error):
                        LiveActivityLogger.shared.error("Push token registration failed: \(error.localizedDescription)")
                    }
                }
                
                self.trackEvent(.pushTokenRegistered, activityId: activityId, templateId: templateId)
            }
        }
        
        tokenObservationTasks[activityId] = task
    }
    
    private func updateStoredToken(activityId: String, token: String) {
        guard let existing = activeActivities[activityId] else { return }
        activeActivities[activityId] = LiveActivityInfo(
            activityId: existing.activityId,
            templateId: existing.templateId,
            pushToken: token,
            startedAt: existing.startedAt
        )
        persistActiveActivities()
    }
    
    // Activity Lookup
    
    private func findActivity<T: ActivityAttributes>(_ type: T.Type, byId activityId: String) -> Activity<T>? {
        return Activity<T>.activities.first { $0.id == activityId }
    }
    
    // Event Tracking
    
    private func trackEvent(_ eventType: LiveActivityEventType, activityId: String, templateId: String) {
        repository.trackEvent(eventType: eventType, activityId: activityId, templateId: templateId) { result in
            if case .failure(let error) = result {
                LiveActivityLogger.shared.error("Event tracking failed [\(eventType.rawValue)]: \(error.localizedDescription)")
            }
        }
    }
    
    // Persistence
    
    private func persistActiveActivities() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let items = activeActivities.values.map {
            PersistableActivityInfo(activityId: $0.activityId, templateId: $0.templateId, pushToken: $0.pushToken, startedAt: $0.startedAt)
        }
        if let data = try? encoder.encode(items) {
            UserDefaults.standard.set(data, forKey: Self.persistenceKey)
        }
    }
    
    private func restoreActiveActivities() {
        guard let data = UserDefaults.standard.data(forKey: Self.persistenceKey),
              let persisted = try? JSONDecoder.iso8601.decode([PersistableActivityInfo].self, from: data) else { return }
        
        // Reconcile with actually running activities (match template for now)
        let runningIds = Set(Activity<MatchActivityAttributes>.activities.map { $0.id })
        
        for info in persisted where runningIds.contains(info.activityId) {
            activeActivities[info.activityId] = LiveActivityInfo(
                activityId: info.activityId,
                templateId: info.templateId,
                pushToken: info.pushToken,
                startedAt: info.startedAt
            )
            
            if let activity = Activity<MatchActivityAttributes>.activities.first(where: { $0.id == info.activityId }) {
                observePushTokenUpdates(for: activity, templateId: info.templateId)
            }
        }
        
        persistActiveActivities()
        LiveActivityLogger.shared.debug("Restored \(activeActivities.count) active activities")
    }
    
    private func cleanupActivity(_ activityId: String) {
        activeActivities.removeValue(forKey: activityId)
        tokenObservationTasks[activityId]?.cancel()
        tokenObservationTasks.removeValue(forKey: activityId)
        HotMessageStore.shared.clear(activityID: activityId)
        persistActiveActivities()
    }
}

// Persistence helpers

@available(iOS 17.2, *)
private struct PersistableActivityInfo: Codable {
    let activityId: String
    let templateId: String
    let pushToken: String?
    let startedAt: Date
}

@available(iOS 17.2, *)
private extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
