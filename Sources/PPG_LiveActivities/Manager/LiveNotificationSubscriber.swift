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
//  Implemented as an actor: state is mutated from several concurrent Tasks
//  (push-to-start stream, activity watcher, per-activity token/content/state
//  streams, bootstrap), so all access is serialized on the actor's executor.
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

/// Minimal envelope for decoding just `lifecycle.status` from a campaign
/// payload, used to gate bootstrap-start on the campaign being ONGOING.
@available(iOS 17.2, *)
private struct LifecycleStatusEnvelope: Decodable {
    struct Lifecycle: Decodable { let status: PPGLiveActivityLifecycleStatus }
    let lifecycle: Lifecycle
}

/// Probe helpers for the bootstrap path: tolerant extraction of the
/// campaign's APNs broadcast `channelId` and the pure start-mode decision.
@available(iOS 17.2, *)
internal enum PPGCampaignProbe {

    /// How a bootstrap-started activity registers for pushes.
    enum StartMode: Equatable {
        /// Per-activity update token (iOS 17.2+ path).
        case token
        /// APNs broadcast channel (iOS 18+, campaign has a channel).
        case channel(String)
    }

    /// Campaign payload carries one broadcast channel per transport:
    /// `"broadcastChannels": [{"type": "APNS", "channelId": "…"}]`.
    /// The array is empty until the campaign goes ONGOING (the backend
    /// creates the channel at start), which lines up with bootstrap only
    /// running for ONGOING campaigns.
    private struct ChannelEnvelope: Decodable {
        struct Channel: Decodable {
            let type: String?
            let channelId: String?
        }
        let broadcastChannels: [Channel]?
    }

    /// APNs broadcast channel id from a raw campaign payload, or `nil` when
    /// the campaign has none.
    static func channelId(from data: Data) -> String? {
        guard let channels = (try? JSONDecoder().decode(ChannelEnvelope.self, from: data))?.broadcastChannels else {
            return nil
        }
        let apns = channels.first { $0.type?.uppercased() == "APNS" }
        guard let id = apns?.channelId, !id.trimmingCharacters(in: .whitespaces).isEmpty else {
            return nil
        }
        return id
    }

    /// Broadcast is used only when the campaign has a channel AND the OS
    /// supports ActivityKit channels (iOS 18+). Empty ids fall back to token.
    static func resolveStartMode(channelId: String?, channelsSupported: Bool) -> StartMode {
        guard channelsSupported, let id = channelId, !id.isEmpty else { return .token }
        return .channel(id)
    }
}

@available(iOS 17.2, *)
internal actor LiveNotificationSubscriber<T: ActivityAttributes>: LiveNotificationSubscriberCancellable {

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

    /// Latest `liveDataVersion` seen per tracked activity. Reported alongside
    /// the `closed` statistics event (and used as the value at `started`).
    private var lastLiveDataVersion: [String: Int] = [:]

    /// `(activityId, eventType)` keys already reported, so a single
    /// start/close is never POSTed twice (bootstrap + watcher can race).
    private var reportedEventKeys: Set<String> = []

    /// Last known remote-start token. Required to compose PUT /endpoint
    /// requests (backend expects both tokens together).
    private var lastRemoteStartToken: String?

    /// Backend-assigned subscriber id (mongodb ObjectId) returned by
    /// `POST /subscribers`
    private var subscriberId: String?

    /// Activity update tokens that arrived before `POST /subscribers`
    /// completed (or before the push-to-start token was known). Replayed
    /// later so the first `PUT /endpoint` is not lost. Keyed by `activityId`
    /// — only the latest token per activity matters, since the wire format
    /// is "current state of token".
    private var pendingUpdateTokens: [String: String] = [:]

    /// Campaign's APNs broadcast channel id, probed from the GET payload
    /// during bootstrap. Used only to pick the bootstrap start mode — the
    /// unsubscribe path deliberately does not depend on it (see
    /// `endCampaignActivities`).
    private var campaignChannelId: String?

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

    // Public lifecycle

    func start() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            statusHandler(.error(.activitiesNotEnabled))
            return
        }

        observePushToStartToken()
        observeActivityLifecycle()
        adoptExistingActivities()
    }

    /// Track activities that were already running when this subscriber
    /// started (e.g. app relaunch mid-campaign). `Activity<T>.activityUpdates`
    /// only emits NEW activities, so without this pass a pre-existing
    /// activity's `pushTokenUpdates` would never be observed and rotated
    /// update tokens would never reach the backend. Deliberately does NOT
    /// report a `started` statistics event — the activity started in a
    /// previous app session and was reported then.
    private func adoptExistingActivities() {
        for activity in Activity<T>.activities where trackedActivities[activity.id] == nil {
            LiveActivityLogger.shared.info(
                "Adopted existing activity [\(liveNotificationId)]: \(activity.id)"
            )
            onActivityAppeared?(activity.id, liveNotificationId)
            trackActivity(activity)
            prefetchImages(for: activity)
        }
    }

    /// Cancel local observation and unregister with backend. Nonisolated so
    /// `LiveActivityManager` can call it through the type-erased protocol;
    /// the Task holds `self` strongly until the backend DELETE completes —
    /// otherwise removing the subscriber from the manager's dictionary could
    /// deallocate it before the request is ever sent.
    nonisolated func cancel() {
        Task { await self.shutdown() }
    }

    private func shutdown() async {
        await endCampaignActivities()
        cancelTasks()
        await unregisterWithBackend()
    }

    /// End (immediately) this campaign's activities when the host app
    /// unsubscribes.
    ///
    /// Deliberately unconditional. A channel-backed activity keeps receiving
    /// broadcast updates for as long as it lives — a broadcast reaches every
    /// channel subscriber and the backend cannot exclude one device — so
    /// honoring an unsubscribe requires ending it locally. Distinguishing
    /// channel-backed from token-backed activities is not reliably possible
    /// on the client: ActivityKit exposes no getter for an activity's push
    /// registration, and the only indirect signal (no update token observed)
    /// cannot tell "never gets a token" apart from "token hasn't arrived
    /// yet".
    ///
    /// Runs before `cancelTasks()` so the regular end flow (closed event,
    /// manager cleanup) still fires.
    private func endCampaignActivities() async {
        for activity in Activity<T>.activities where belongsToThisCampaign(activity) {
            await activity.end(nil, dismissalPolicy: .immediate)
            LiveActivityLogger.shared.info(
                "Unsubscribe: ended activity \(activity.id) for \(liveNotificationId)"
            )
        }
    }

    /// Best-effort campaign check for activities of the shared attributes
    /// type. `PPGLiveActivityImagePrefetchable.imageCampaignId` carries the
    /// `liveNotificationId` for PPG templates; attributes that don't conform
    /// fall back to the subscriber's single-campaign assumption (`true`).
    private func belongsToThisCampaign(_ activity: Activity<T>) -> Bool {
        guard let prefetchable = activity.attributes as? PPGLiveActivityImagePrefetchable else {
            return true
        }
        return prefetchable.imageCampaignId == liveNotificationId
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

            // Seed from the current token first — after an app relaunch the
            // async stream may emit late or not at all (known ActivityKit
            // behavior), while the token is already available synchronously.
            if let current = Activity<T>.pushToStartToken {
                await self.handlePushToStartToken(current.ppgHexString)
            }

            for await tokenData in Activity<T>.pushToStartTokenUpdates {
                if Task.isCancelled { break }
                await self.handlePushToStartToken(tokenData.ppgHexString)
            }
        }
    }

    private func handlePushToStartToken(_ tokenHex: String) async {
        LiveActivityLogger.shared.debug(
            "Push-to-start token [\(liveNotificationId)]: \(tokenHex)"
        )
        lastRemoteStartToken = tokenHex
        if subscriberId == nil {
            // First token registers the subscriber; registration replays any
            // queued update tokens once the backend returns a subscriberId.
            await registerWithBackend(remoteStartToken: tokenHex)
        } else {
            // Already registered — replay update tokens that were queued
            // while no remoteStartToken was known. Rotated push-to-start
            // tokens reach the backend with the next PUT /endpoint.
            await flushPendingUpdateTokens()
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
            // Persist so statistics click events reported from
            // `LiveActivitiesSDK.handleURL(...)` can find the subscriberId even
            // after an app relaunch (when this subscriber is gone).
            SubscriberIDStore.shared.set(id, for: liveNotificationId)
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

            // Remember the campaign's broadcast channel (if any) — selects the
            // bootstrap start mode below and identifies channel-backed
            // activities at unsubscribe time.
            campaignChannelId = PPGCampaignProbe.channelId(from: data)
            if let channelId = campaignChannelId {
                LiveActivityLogger.shared.debug(
                    "Campaign \(liveNotificationId) exposes broadcast channel \(channelId)"
                )
            }

            // Only bootstrap-start when the campaign is actually ONGOING.
            // For PENDING / scheduled campaigns the OS will start the activity
            // via push-to-start at `scheduledAt` — starting it here too would
            // produce a duplicate Live Activity (one at subscribe time, one at
            // the scheduled time).
            if let status = Self.decodeLifecycleStatus(from: data), status != .ongoing {
                LiveActivityLogger.shared.debug(
                    "Bootstrap: campaign \(liveNotificationId) is \(status.rawValue), not ONGOING — leaving start to push-to-start"
                )
                return
            }

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
                prefetchImages(for: existing)
            } else {
                guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
                let activity = try startBootstrapActivity(attributes: attrs, state: state)
                onActivityAppeared?(activity.id, liveNotificationId)
                statusHandler(.activityStarted(activityId: activity.id))
                trackActivity(activity)
                prefetchImages(for: activity)
                reportEvent(.started, liveDataVersion: liveDataVersion(of: state), activityId: activity.id)
            }
        } catch {
            LiveActivityLogger.shared.error(
                "Bootstrap failed for \(liveNotificationId): \(error.localizedDescription)"
            )
        }
    }

    /// Request the bootstrap activity with the right push registration:
    /// broadcast channel on iOS 18+ when the campaign has one, otherwise the
    /// per-activity update token (unchanged 17.2+ behavior).
    private func startBootstrapActivity(attributes: T, state: T.ContentState) throws -> Activity<T> {
        let content = ActivityContent(state: state, staleDate: nil, relevanceScore: 50)
        let mode = PPGCampaignProbe.resolveStartMode(
            channelId: campaignChannelId,
            channelsSupported: PPGChannelCapability.isSupported
        )
        if #available(iOS 18.0, *), case .channel(let channelId) = mode {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: .channel(channelId)
            )
            LiveActivityLogger.shared.info(
                "Bootstrap: started activity \(activity.id) via broadcast channel \(channelId) for \(liveNotificationId)"
            )
            return activity
        }
        let activity = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: .token
        )
        LiveActivityLogger.shared.info(
            "Bootstrap: started activity \(activity.id) via update token for \(liveNotificationId)"
        )
        return activity
    }

    // Activity lifecycle (push-to-start activities)

    private func observeActivityLifecycle() {
        activityWatchTask = Task { [weak self] in
            guard let self else { return }

            for await activity in Activity<T>.activityUpdates {
                if Task.isCancelled { break }
                await self.handleActivityAppeared(activity)
            }
        }
    }

    private func handleActivityAppeared(_ activity: Activity<T>) {
        let activityId = activity.id

        // activityUpdates fires on every ContentState change too — only
        // treat the activity as "new" if we are not already tracking it.
        guard trackedActivities[activityId] == nil else { return }

        LiveActivityLogger.shared.info(
            "Activity appeared [\(liveNotificationId)]: \(activityId)"
        )
        Self.logIncomingPayload(activity: activity)
        onActivityAppeared?(activityId, liveNotificationId)
        statusHandler(.activityStarted(activityId: activityId))
        trackActivity(activity)
        prefetchImages(for: activity)
        reportEvent(.started, liveDataVersion: liveDataVersion(of: activity.content.state), activityId: activityId)
    }

    /// Download badge images referenced by the activity's attributes into the
    /// shared App Group cache, then nudge a same-content re-render so the
    /// widget swaps placeholders for the real badges. Required for the
    /// push-to-start path: it has no REST bootstrap, so the host app never
    /// gets a chance to prefetch and the cache for a fresh campaign is empty.
    private func prefetchImages(for activity: Activity<T>) {
        guard let prefetchable = activity.attributes as? PPGLiveActivityImagePrefetchable else { return }
        let images = prefetchable.prefetchableImages
        guard !images.isEmpty else { return }
        let campaignId = prefetchable.imageCampaignId
        Task {
            var cachedAny = false
            for (type, url) in images {
                let ok = await LiveActivityImageManager.shared.prefetch(
                    from: url,
                    imageType: type,
                    campaignId: campaignId
                )
                cachedAny = cachedAny || ok
            }
            guard cachedAny else { return }
            await activity.update(activity.content)
            LiveActivityLogger.shared.debug(
                "Prefetched \(images.count) badge image(s) for \(campaignId); re-rendered activity \(activity.id)"
            )
        }
    }

    private func trackActivity(_ activity: Activity<T>) {
        let activityId = activity.id
        trackedActivities[activityId]?.cancel()
        lastLiveDataVersion[activityId] = liveDataVersion(of: activity.content.state)

        let tracker = ActivityTracker(
            activity: activity,
            onTokenUpdate: { [weak self] tokenHex in
                await self?.handleTokenUpdate(activityId: activityId, tokenHex: tokenHex)
            },
            onEnd: { [weak self] in
                await self?.handleActivityEnded(activityId: activityId)
            },
            onContentUpdate: { [weak self] state in
                await self?.handleContentUpdate(activityId: activityId, state: state)
            }
        )
        trackedActivities[activityId] = tracker
        tracker.start()

        // Seed from the current update token — `pushTokenUpdates` does not
        // re-emit a token that was issued before this observer attached.
        if let tokenData = activity.pushToken {
            let tokenHex = tokenData.ppgHexString
            Task { [weak self] in
                await self?.handleTokenUpdate(activityId: activityId, tokenHex: tokenHex)
            }
        }
    }

    private func handleTokenUpdate(activityId: String, tokenHex: String) async {
        onActivityTokenUpdate?(activityId, tokenHex)
        await forwardActivityUpdateToken(activityId: activityId, updateToken: tokenHex)
    }

    private func handleActivityEnded(activityId: String) {
        reportEvent(.closed, liveDataVersion: lastLiveDataVersion[activityId] ?? 0, activityId: activityId)
        onActivityCleared?(activityId)
        statusHandler(.activityEnded(activityId: activityId))
        trackedActivities.removeValue(forKey: activityId)
        lastLiveDataVersion.removeValue(forKey: activityId)
    }

    private func handleContentUpdate(activityId: String, state: T.ContentState) {
        lastLiveDataVersion[activityId] = liveDataVersion(of: state)
        onContentStateUpdated?(activityId, state)
    }

    // Statistics events

    /// Read the backend `liveDataVersion` off a content state, if the template
    /// exposes it. Returns `0` for templates that don't carry a version.
    private func liveDataVersion(of state: T.ContentState) -> Int {
        (state as? PPGLiveDataVersioned)?.liveDataVersion ?? 0
    }

    /// Fire-and-forget POST of a single statistics event. No-op until the
    /// subscriber is registered (we need a `subscriberId`). De-duplicated per
    /// `(activityId, type)` — bootstrap-start and the `activityUpdates` watcher
    /// can both observe the same new activity, so without this guard a single
    /// start would be reported twice.
    private func reportEvent(
        _ type: PPGLiveNotificationStatisticsEventType,
        liveDataVersion: Int,
        activityId: String
    ) {
        guard let subscriberId else {
            LiveActivityLogger.shared.debug(
                "Skipping \(type.rawValue) event — no subscriberId yet"
            )
            return
        }
        let dedupeKey = "\(activityId):\(type.rawValue)"
        guard reportedEventKeys.insert(dedupeKey).inserted else {
            LiveActivityLogger.shared.debug(
                "Skipping duplicate \(type.rawValue) event for \(activityId)"
            )
            return
        }
        let event = PPGLiveNotificationStatisticsEvent(type: type, liveDataVersion: liveDataVersion)
        let repository = self.repository
        let liveNotificationId = self.liveNotificationId
        let installationId = self.installationId
        Task {
            do {
                try await repository.collectEvents(
                    liveNotificationId: liveNotificationId,
                    installationId: installationId,
                    subscriberId: subscriberId,
                    events: [event]
                )
                LiveActivityLogger.shared.info(
                    "Reported \(type.rawValue) event for \(liveNotificationId) (v=\(liveDataVersion))"
                )
            } catch {
                LiveActivityLogger.shared.error(
                    "Failed to report \(type.rawValue) event: \(error.localizedDescription)"
                )
            }
        }
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
        // alongside `updateToken`. ActivityKit can emit the activity update
        // token BEFORE the push-to-start token (notably after an app
        // relaunch, where `pushToStartTokenUpdates` may fire late or not at
        // all) — queue the token instead of dropping it and replay once the
        // push-to-start token arrives.
        guard let remoteStartToken = lastRemoteStartToken else {
            pendingUpdateTokens[activityId] = updateToken
            LiveActivityLogger.shared.debug(
                "Queued update-token for \(activityId) — waiting for remoteStartToken"
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

    /// Decode just `lifecycle.status` from the raw campaign payload so we can
    /// gate bootstrap-start without depending on the template-specific
    /// `onCampaignAlreadyActive` parsing. Returns `nil` if the field is absent
    /// or unparseable (in which case the caller falls back to the closure).
    private static func decodeLifecycleStatus(from data: Data) -> PPGLiveActivityLifecycleStatus? {
        return try? JSONDecoder().decode(LifecycleStatusEnvelope.self, from: data).lifecycle.status
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
    private var tokenTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?
    private var contentTask: Task<Void, Never>?
    private let startTokenStream: () -> Task<Void, Never>
    private let startStateStream: () -> Task<Void, Never>
    private let startContentStream: () -> Task<Void, Never>

    init<T: ActivityAttributes>(
        activity: Activity<T>,
        onTokenUpdate: @escaping @Sendable (String) async -> Void,
        onEnd: @escaping @Sendable () async -> Void,
        onContentUpdate: @escaping @Sendable (T.ContentState) async -> Void
    ) {
        self.activityId = activity.id

        // Capture activity in closures so we don't expose generics on ActivityTracker.
        self.startTokenStream = {
            Task {
                for await tokenData in activity.pushTokenUpdates {
                    if Task.isCancelled { break }
                    await onTokenUpdate(tokenData.ppgHexString)
                }
            }
        }
        self.startStateStream = {
            Task {
                for await state in activity.activityStateUpdates {
                    if Task.isCancelled { break }
                    if state == .ended || state == .dismissed {
                        await onEnd()
                        return
                    }
                }
            }
        }
        self.startContentStream = {
            Task {
                for await content in activity.contentUpdates {
                    if Task.isCancelled { break }
                    await onContentUpdate(content.state)
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
