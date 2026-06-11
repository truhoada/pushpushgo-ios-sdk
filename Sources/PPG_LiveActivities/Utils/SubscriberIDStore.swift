//
//  SubscriberIDStore.swift
//  PPG_LiveActivities
//
//  Persists the backend-assigned `subscriberId` (mongodb ObjectId) per
//  `liveNotificationId`. Needed because statistics click events are reported
//  from `LiveActivitiesSDK.handleURL(...)` — which may run after an app
//  relaunch, when the in-memory `LiveNotificationSubscriber` no longer holds
//  the id. Lives in `UserDefaults.standard` (host-process only; the widget
//  never reports events).
//

import Foundation

@available(iOS 17.2, *)
internal final class SubscriberIDStore {

    static let shared = SubscriberIDStore()

    private static let storageKey = "PPGLiveActivities_SubscriberIDs"
    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Backend `subscriberId` for the given live notification, if known.
    func subscriberId(for liveNotificationId: String) -> String? {
        map()[liveNotificationId]
    }

    func set(_ subscriberId: String, for liveNotificationId: String) {
        var current = map()
        current[liveNotificationId] = subscriberId
        defaults.set(current, forKey: Self.storageKey)
    }

    func remove(for liveNotificationId: String) {
        var current = map()
        current.removeValue(forKey: liveNotificationId)
        defaults.set(current, forKey: Self.storageKey)
    }

    private func map() -> [String: String] {
        defaults.dictionary(forKey: Self.storageKey) as? [String: String] ?? [:]
    }
}
