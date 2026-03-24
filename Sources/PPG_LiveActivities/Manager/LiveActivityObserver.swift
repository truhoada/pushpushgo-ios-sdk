//
//  LiveActivityObserver.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 24/03/2026.
//

import Foundation
import ActivityKit

/// Manages the "observe" flow for remotely-started Live Activities.
///
/// Handles two paths based on iOS version:
/// - **iOS 18+**: Push-to-start token + channel subscription (broadcast updates)
/// - **iOS 17.2–17.x**: Push-to-start token per device (individual updates)
@available(iOS 17.2, *)
internal class LiveActivityObserver<T: ActivityAttributes> {
    
    private let repository: LiveActivityRepository
    private let campaignId: String
    private let templateId: String
    private let statusHandler: @Sendable (LiveActivityObserverStatus) -> Void
    
    private var pushToStartTask: Task<Void, Never>?
    private var activityStateTask: Task<Void, Never>?
    private var pushTokenUpdateTask: Task<Void, Never>?
    
    init(
        repository: LiveActivityRepository,
        campaignId: String,
        templateId: String,
        statusHandler: @escaping @Sendable (LiveActivityObserverStatus) -> Void
    ) {
        self.repository = repository
        self.campaignId = campaignId
        self.templateId = templateId
        self.statusHandler = statusHandler
    }
    
    // Main entry point
    
    func start() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            statusHandler(.error(.activitiesNotEnabled))
            return
        }
        
        observePushToStartToken()
    }
    
    func cancel() {
        pushToStartTask?.cancel()
        activityStateTask?.cancel()
        pushTokenUpdateTask?.cancel()
        pushToStartTask = nil
        activityStateTask = nil
        pushTokenUpdateTask = nil
    }
    
    // Push-to-Start Token Observation
    
    private func observePushToStartToken() {
        pushToStartTask = Task { [weak self] in
            guard let self else { return }
            
            for await tokenData in Activity<T>.pushToStartTokenUpdates {
                guard !Task.isCancelled else { break }
                
                let tokenHex = tokenData.map { String(format: "%02x", $0) }.joined()
                LiveActivityLogger.shared.debug("Push-to-start token [\(self.templateId)]: \(tokenHex)")
                
                await self.registerObserver(pushToStartToken: tokenHex)
                break
            }
        }
    }
    
    // Register with PPG backend
    
    private func registerObserver(pushToStartToken: String) async {
        let supportsChannels: Bool
        if #available(iOS 18, *) {
            supportsChannels = true
        } else {
            supportsChannels = false
        }
        
        let body = ObserveRequest(
            campaignId: campaignId,
            templateId: templateId,
            pushToStartToken: pushToStartToken,
            subscriberId: PushSDKBridge.subscriberId,
            supportsChannels: supportsChannels
        )
        
        do {
            let response = try await repository.registerObserver(body: body)
            
            guard response.status != "ended" else {
                statusHandler(.error(.campaignUnavailable))
                return
            }
            
            LiveActivityLogger.shared.info("Observer registered for campaign \(campaignId) (status: \(response.status))")
            statusHandler(.registered)
            
            // After registration, start observing for activities that get started via push
            observeActivityLifecycle()
            
        } catch {
            LiveActivityLogger.shared.error("Observer registration failed: \(error.localizedDescription)")
            statusHandler(.error(.registrationFailed(underlying: error)))
        }
    }
    
    // Observe activities started by remote push
    
    private func observeActivityLifecycle() {
        activityStateTask = Task { [weak self] in
            guard let self else { return }
            
            // Watch for new activities of this type appearing (started via push-to-start)
            for await activity in Activity<T>.activityUpdates {
                guard !Task.isCancelled else { break }
                
                let activityId = activity.id
                LiveActivityLogger.shared.info("Activity appeared [\(self.templateId)]: \(activityId)")
                self.statusHandler(.started(activityId: activityId))
                
                // Observe push-to-update token for this activity (needed for iOS 17.2-17.x)
                self.observePushTokenUpdates(for: activity)
                
                // Observe state changes (updates and end)
                self.observeContentUpdates(for: activity)
                
                break
            }
        }
    }
    
    // Observe push-to-update token (sent to backend for per-device updates on iOS <18)
    
    private func observePushTokenUpdates(for activity: Activity<T>) {
        let activityId = activity.id
        
        pushTokenUpdateTask = Task { [weak self] in
            guard let self else { return }
            
            for await tokenData in activity.pushTokenUpdates {
                guard !Task.isCancelled else { break }
                
                let tokenHex = tokenData.map { String(format: "%02x", $0) }.joined()
                LiveActivityLogger.shared.debug("Push-to-update token [\(self.templateId)] \(activityId): \(tokenHex)")
                
                self.repository.registerPushToken(
                    activityId: activityId,
                    templateId: self.templateId,
                    pushToken: tokenHex
                ) { result in
                    if case .failure(let error) = result {
                        LiveActivityLogger.shared.error("Push token registration failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // Observe activity state for end detection
    
    private func observeContentUpdates(for activity: Activity<T>) {
        Task { [weak self] in
            guard let self else { return }
            
            for await state in activity.activityStateUpdates {
                guard !Task.isCancelled else { break }
                
                switch state {
                case .ended, .dismissed:
                    LiveActivityLogger.shared.info("Activity ended [\(self.templateId)]: \(activity.id)")
                    self.statusHandler(.ended(activityId: activity.id))
                    self.cancel()
                    return
                case .active:
                    self.statusHandler(.updated(activityId: activity.id))
                default:
                    break
                }
            }
        }
    }
    
    deinit {
        cancel()
    }
}
