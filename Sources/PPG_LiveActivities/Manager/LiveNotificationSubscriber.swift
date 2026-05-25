//
//  LiveNotificationSubscriber.swift
//  PPG_LiveActivities
//
//
//  Lifecycle managed here:
//   1. Listen on `Activity<T>.pushToStartTokenUpdates` and POST `/subscribers`
//      with `{installationId, endpoint:{transport:APNS, remoteStartToken}}`
//      every time the token changes. The first POST creates the subscriber;
//      subsequent calls are idempotent (backend keys by installationId).
//   2. Listen on `Activity<T>.activityUpdates` for an activity that appears
//      via push-to-start. For that activity, listen on `pushTokenUpdates`
//      and PUT `/subscribers/{installationId}/endpoint` whenever the
//      activity update token rotates, sending both `remoteStartToken`
//      and `updateToken`.
//   3. On `cancel()` (typically `LiveActivitiesSDK.unsubscribe(...)`)
//      DELETE `/subscribers/{installationId}` and tear down all tasks.
//

import Foundation
import ActivityKit

/// Type-erased handle for cancelling a subscriber without binding to its
/// generic `ActivityAttributes` parameter. Used by `LiveActivityManager`
/// to drive `unsubscribe(liveNotificationId:)` from a non-generic context.
@available(iOS 17.2, *)
internal protocol LiveNotificationSubscriberCancellable: AnyObject {
    func cancel()
}

@available(iOS 17.2, *)
internal final class LiveNotificationSubscriber<T: ActivityAttributes>: LiveNotificationSubscriberCancellable {
    
    private let repository: LiveActivityRepository
    private let liveNotificationId: String
    private let installationId: String
    private let statusHandler: @Sendable (LiveNotificationSubscriptionStatus) -> Void
    
    /// Notified when a push-to-start Activity appears for this subscriber.
    /// Used by `LiveActivityManager` to add it to its `activeActivities`
    /// registry (which otherwise only sees locally-started activities).
    private let onActivityAppeared: (@Sendable (_ activityId: String, _ templateId: String) -> Void)?
    
    /// Notified when a tracked Activity gets a new update push token.
    /// Used by `LiveActivityManager` to keep `LiveActivityInfo.pushToken`
    /// in sync for UI inspection.
    private let onActivityTokenUpdate: (@Sendable (_ activityId: String, _ token: String) -> Void)?
    
    /// Notified when a tracked Activity ends (via `event:end` push).
    /// Used by `LiveActivityManager` to remove it from `activeActivities`.
    private let onActivityCleared: (@Sendable (_ activityId: String) -> Void)?
    
    /// Notified on every ContentState change (including APNs `event:update`
    /// pushes). Used by `LiveActivityManager` to reschedule the hot-message
    /// auto-clear Task whenever a push delivers a new `hotMessage`.
    private let onContentStateUpdated: (@Sendable (_ activityId: String, _ state: T.ContentState) -> Void)?
    
    /// Called after subscriber registration when no activity is running yet.
    /// Receives the raw JSON body from `GET /live-notifications/{id}`.
    /// Return `(attributes, initialState)` to start the activity locally
    /// (campaign already ONGOING), or `nil` to do nothing (not yet started).
    private let onCampaignAlreadyActive: (@Sendable (_ payload: Data) async throws -> (T, T.ContentState)?)?
    
    private var pushToStartTask: Task<Void, Never>?
    private var activityWatchTask: Task<Void, Never>?
    private var trackedActivities: [String: ActivityTracker] = [:]
    
    /// Last known remote-start token. Required to compose PUT /endpoint
    /// requests (backend expects both tokens together).
    private var lastRemoteStartToken: String?
    
    /// Backend-assigned subscriber id (mongodb ObjectId) returned by
    /// `POST /subscribers`
    private var subscriberId: String?
    
    /// Activity update tokens that arrived before `POST /subscribers`
    /// completed. Replayed after registration so the first `PUT /endpoint`
    /// is not lost. Keyed by `activityId` — only the latest token per
    /// activity matters, since the wire format is "current state of token".
    private var pendingUpdateTokens: [String: String] = [:]
    
    init(
        repository: LiveActivityRepository,
        liveNotificationId: String,
        installationId: String,
        statusHandler: @escaping @Sendable (LiveNotificationSubscriptionStatus) -> Void,
        onActivityAppeared: (@Sendable (String, String) -> Void)? = nil,
        onActivityTokenUpdate: (@Sendable (String, String) -> Void)? = nil,
        onActivityCleared: (@Sendable (String) -> Void)? = nil,
        onContentStateUpdated: (@Sendable (String, T.ContentState) -> Void)? = nil,
        onCampaignAlreadyActive: (@Sendable (Data) async throws -> (T, T.ContentState)?)? = nil
    ) {
        self.repository = repository
        self.liveNotificationId = liveNotificationId
        self.installationId = installationId
        self.statusHandler = statusHandler
        self.onActivityAppeared = onActivityAppeared
        self.onActivityTokenUpdate = onActivityTokenUpdate
        self.onActivityCleared = onActivityCleared
        self.onContentStateUpdated = onContentStateUpdated
        self.onCampaignAlreadyActive = onCampaignAlreadyActive
    }
    
    deinit {
        cancelTasks()
    }
    
    // Public lifecycle
    
    func start() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            statusHandler(.error(.activitiesNotEnabled))
            return
        }
        
        observePushToStartToken()
        observeActivityLifecycle()
    }
    
    /// Cancel local observation and unregister with backend.
    func cancel() {
        cancelTasks()
        Task { [weak self] in
            await self?.unregisterWithBackend()
        }
    }
    
    private func cancelTasks() {
        pushToStartTask?.cancel()
        pushToStartTask = nil
        activityWatchTask?.cancel()
        activityWatchTask = nil
        for tracker in trackedActivities.values {
            tracker.cancel()
        }
        trackedActivities.removeAll()
    }
    
    // Push-to-start token
    
    private func observePushToStartToken() {
        pushToStartTask = Task { [weak self] in
            guard let self else { return }
            
            for await tokenData in Activity<T>.pushToStartTokenUpdates {
                if Task.isCancelled { break }
                
                let tokenHex = Self.hexString(tokenData)
                LiveActivityLogger.shared.debug(
                    "Push-to-start token [\(self.liveNotificationId)]: \(tokenHex)"
                )
                self.lastRemoteStartToken = tokenHex
                // Only POST once — if we already have a subscriberId, the
                // backend knows this device. Subsequent token rotations are
                // forwarded via PUT /endpoint when the update-token changes.
                guard self.subscriberId == nil else { continue }
                await self.registerWithBackend(remoteStartToken: tokenHex)
            }
        }
    }
    
    private func registerWithBackend(remoteStartToken: String) async {
        do {
            let id = try await repository.subscribe(
                liveNotificationId: liveNotificationId,
                installationId: installationId,
                remoteStartToken: remoteStartToken,
                updateToken: nil
            )
            self.subscriberId = id
            LiveActivityLogger.shared.info(
                "Subscriber registered for liveNotification \(liveNotificationId) (subscriberId=\(id))"
            )
            statusHandler(.registered)
            await flushPendingUpdateTokens()
            await bootstrapIfCampaignActive()
        } catch {
            LiveActivityLogger.shared.error(
                "Subscriber registration failed: \(error.localizedDescription)"
            )
            statusHandler(.error(.registrationFailed(underlying: error)))
        }
    }
    
    private func unregisterWithBackend() async {
        guard let subscriberId else {
            LiveActivityLogger.shared.debug(
                "Skipping unsubscribe — no subscriberId (registration never completed)"
            )
            return
        }
        do {
            try await repository.unsubscribe(
                liveNotificationId: liveNotificationId,
                subscriberId: subscriberId
            )
            LiveActivityLogger.shared.info(
                "Unsubscribed from liveNotification \(liveNotificationId)"
            )
            statusHandler(.unsubscribed)
        } catch {
            LiveActivityLogger.shared.error(
                "Unsubscribe failed: \(error.localizedDescription)"
            )
            statusHandler(.error(.unregistrationFailed(underlying: error)))
        }
    }
    
    // Late-subscriber bootstrap
    
    /// Called after successful registration when the subscriber may have
    /// joined a campaign that is already ONGOING. Fetches the current
    /// campaign payload, delegates parsing and activity-start decision to
    /// `onCampaignAlreadyActive`, then wires up the new activity for token
    /// forwarding exactly like a push-to-start activity.
    private func bootstrapIfCampaignActive() async {
        guard let onCampaignAlreadyActive else { return }
        do {
            let data = try await repository.fetchCampaign(liveNotificationId: liveNotificationId)
            guard let (attrs, state) = try await onCampaignAlreadyActive(data) else {
                LiveActivityLogger.shared.debug(
                    "Bootstrap: campaign \(liveNotificationId) not yet active"
                )
                return
            }
            // Cache the iOS design from the REST response — APNs push-to-start delivers
            // `"design":{"ios":{}}` (empty) and ActivityKit attributes are immutable,
            // so the widget reads design from this shared-container cache instead.
            if let cacheable = attrs as? any PPGLiveActivityDesignCacheable {
                LiveActivityDesignStore.shared.cacheDesign(
                    cacheable.iosDesign,
                    liveNotificationId: liveNotificationId
                )
            }
            
            if let existing = Activity<T>.activities.first {
                // Activity was already started by APNs push-to-start (possibly without countdown
                // or other REST-only fields). Patch its ContentState with the full state from REST.
                await existing.update(ActivityContent(state: state, staleDate: nil))
                LiveActivityLogger.shared.info(
                    "Bootstrap: patched existing activity \(existing.id) with REST state for \(liveNotificationId)"
                )
            } else {
                guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
                let activity = try Activity.request(
                    attributes: attrs,
                    content: ActivityContent(state: state, staleDate: nil, relevanceScore: 50),
                    pushType: .token
                )
                LiveActivityLogger.shared.info(
                    "Bootstrap: started activity \(activity.id) for \(liveNotificationId)"
                )
                onActivityAppeared?(activity.id, liveNotificationId)
                statusHandler(.activityStarted(activityId: activity.id))
                trackActivity(activity)
            }
        } catch {
            LiveActivityLogger.shared.error(
                "Bootstrap failed for \(liveNotificationId): \(error.localizedDescription)"
            )
        }
    }
    
    // Activity lifecycle (push-to-start activities)
    
    private func observeActivityLifecycle() {
        activityWatchTask = Task { [weak self] in
            guard let self else { return }
            
            for await activity in Activity<T>.activityUpdates {
                if Task.isCancelled { break }
                
                let activityId = activity.id
                
                // activityUpdates fires on every ContentState change too — only
                // treat the activity as "new" if we are not already tracking it.
                guard self.trackedActivities[activityId] == nil else { continue }
                
                LiveActivityLogger.shared.info(
                    "Activity appeared [\(self.liveNotificationId)]: \(activityId)"
                )
                Self.logIncomingPayload(activity: activity)
                self.onActivityAppeared?(activityId, self.liveNotificationId)
                self.statusHandler(.activityStarted(activityId: activityId))
                self.trackActivity(activity)
            }
        }
    }
    
    private func trackActivity(_ activity: Activity<T>) {
        let activityId = activity.id
        trackedActivities[activityId]?.cancel()
        
        let tracker = ActivityTracker(
            activity: activity,
            onTokenUpdate: { [weak self] tokenHex in
                guard let self else { return }
                self.onActivityTokenUpdate?(activityId, tokenHex)
                await self.forwardActivityUpdateToken(activityId: activityId, updateToken: tokenHex)
            },
            onEnd: { [weak self] in
                guard let self else { return }
                self.onActivityCleared?(activityId)
                self.statusHandler(.activityEnded(activityId: activityId))
                self.trackedActivities.removeValue(forKey: activityId)
            },
            onContentUpdate: { [weak self] state in
                self?.onContentStateUpdated?(activityId, state)
            }
        )
        trackedActivities[activityId] = tracker
        tracker.start()
    }
    
    /// Replay any update tokens that were captured before
    /// `POST /subscribers` returned a `subscriberId`.
    private func flushPendingUpdateTokens() async {
        guard !pendingUpdateTokens.isEmpty else { return }
        let queued = pendingUpdateTokens
        pendingUpdateTokens.removeAll()
        for (activityId, token) in queued {
            await forwardActivityUpdateToken(activityId: activityId, updateToken: token)
        }
    }
    
    private func forwardActivityUpdateToken(activityId: String, updateToken: String) async {
        // Backend's PUT /endpoint requires `remoteStartToken` to be sent
        // alongside `updateToken`. If we never saw a push-to-start token
        // (e.g. activity was started locally for testing), bail out.
        guard let remoteStartToken = lastRemoteStartToken else {
            LiveActivityLogger.shared.debug(
                "Skipping update-token forward — no remoteStartToken yet"
            )
            return
        }
        

        // ActivityKit emits the activity update token a moment after the
        // push-to-start token, so the POST may still be in flight here —
        // queue the latest token per activity and replay once registered.
        guard let subscriberId else {
            pendingUpdateTokens[activityId] = updateToken
            LiveActivityLogger.shared.debug(
                "Queued update-token for \(activityId) — waiting for subscriberId"
            )
            return
        }
        
        do {
            try await repository.updateSubscriberEndpoint(
                liveNotificationId: liveNotificationId,
                subscriberId: subscriberId,
                remoteStartToken: remoteStartToken,
                updateToken: updateToken
            )
            LiveActivityLogger.shared.info(
                "Update token forwarded for activity \(activityId)"
            )
            statusHandler(.updateTokenSent(activityId: activityId))
        } catch {
            LiveActivityLogger.shared.error(
                "Update-token forward failed: \(error.localizedDescription)"
            )
            statusHandler(.error(.endpointUpdateFailed(underlying: error)))
        }
    }
    
    // Helpers
    
    private static func hexString(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Diagnostic log for the payload that ActivityKit handed to us when a
    /// push-to-start activity appears:
    ///   - the `attributes` and `contentState` JSON received over APNs match
    ///     what they sent on the wire,
    ///   - the APNs `aps.stale-date` and `aps.relevance-score` reached the
    ///     activity (`staleDate` / `relevanceScore` not nil). When either is
    ///     `nil` or in the past, iOS marks the activity as
    ///     `Activity is no longer relevant` ~1s after creation and dismisses
    ///     it, which is the most common cause of "push delivered but LA does
    ///     not show on Lock Screen".
    fileprivate static func logIncomingPayload(activity: Activity<T>) {
        let attributesJSON = jsonString(activity.attributes) ?? "<unencodable>"
        let stateJSON = jsonString(activity.content.state) ?? "<unencodable>"
        let stale = activity.content.staleDate.map { "\($0)" } ?? "nil"
        let relevance = "\(activity.content.relevanceScore)"
        
        LiveActivityLogger.shared.info(
            """
            APNs payload received for activity \(activity.id):
              attributes = \(attributesJSON)
              contentState = \(stateJSON)
              staleDate = \(stale)
              relevanceScore = \(relevance)
            """
        )
        
        if activity.content.staleDate == nil {
            LiveActivityLogger.shared.warning(
                "APNs payload missing `aps.stale-date`. iOS will likely mark the activity as no-longer-relevant within ~1s. Backend must send `aps.stale-date` (unix seconds, e.g. now + 7200) on `event=start`."
            )
        }
        if activity.content.relevanceScore == 0 {
            LiveActivityLogger.shared.warning(
                "APNs payload `aps.relevance-score` is 0 (or missing). Recommend sending 100 to ensure visibility."
            )
        }
    }
    
    private static func jsonString<V: Encodable>(_ value: V) -> String? {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        guard let data = try? enc.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// Per-activity tracker — own its tasks so cancellation is granular.
@available(iOS 17.2, *)
private final class ActivityTracker {
    
    private let activityId: String
    private let onTokenUpdate: @Sendable (String) async -> Void
    private let onEnd: @Sendable () -> Void
    private var tokenTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?
    private var contentTask: Task<Void, Never>?
    private let startTokenStream: () -> Task<Void, Never>
    private let startStateStream: () -> Task<Void, Never>
    private let startContentStream: () -> Task<Void, Never>
    
    init<T: ActivityAttributes>(
        activity: Activity<T>,
        onTokenUpdate: @escaping @Sendable (String) async -> Void,
        onEnd: @escaping @Sendable () -> Void,
        onContentUpdate: @escaping @Sendable (T.ContentState) -> Void
    ) {
        self.activityId = activity.id
        self.onTokenUpdate = onTokenUpdate
        self.onEnd = onEnd
        
        // Capture activity in closures so we don't expose generics on ActivityTracker.
        self.startTokenStream = {
            Task {
                for await tokenData in activity.pushTokenUpdates {
                    if Task.isCancelled { break }
                    let tokenHex = tokenData.map { String(format: "%02x", $0) }.joined()
                    await onTokenUpdate(tokenHex)
                }
            }
        }
        self.startStateStream = {
            Task {
                for await state in activity.activityStateUpdates {
                    if Task.isCancelled { break }
                    if state == .ended || state == .dismissed {
                        onEnd()
                        return
                    }
                }
            }
        }
        self.startContentStream = {
            Task {
                for await content in activity.contentUpdates {
                    if Task.isCancelled { break }
                    onContentUpdate(content.state)
                }
            }
        }
    }
    
    func start() {
        tokenTask = startTokenStream()
        stateTask = startStateStream()
        contentTask = startContentStream()
    }
    
    func cancel() {
        tokenTask?.cancel()
        stateTask?.cancel()
        contentTask?.cancel()
        tokenTask = nil
        stateTask = nil
        contentTask = nil
    }
    
    deinit {
        cancel()
    }
}
