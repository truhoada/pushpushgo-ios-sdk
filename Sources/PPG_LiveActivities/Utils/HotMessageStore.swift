//
//  HotMessageStore.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 29/04/2026.
//

import Foundation

/// Persistent per-Activity `receivedAt` timestamp store for hot messages.
///
/// The backend sends only `durationSeconds` in the push payload. To hide a
/// hot message deterministically after that many seconds, the widget needs
/// to remember **when** it first saw a given `hotMessage.id`. This store
/// persists that timestamp in the App Group shared between the host app
/// and the widget extension, keyed by ActivityKit's system-generated
/// `activityID` so that multiple concurrent Live Activities stay isolated.
///
/// Behaviour:
/// - First call with `(activityID, hotMessageId)` stores `now` and returns it.
/// - Subsequent calls with the same `(activityID, hotMessageId)` return the
///   previously stored value (idempotent — prevents re-starting the countdown
///   when the widget is re-rendered mid-window).
/// - A new `hotMessageId` for the same `activityID` overwrites the entry —
///   last-wins semantics.
/// - Only the latest entry per `activityID` is kept, so storage stays bounded.
@available(iOS 17.2, *)
public final class HotMessageStore {
    
    public static let shared = HotMessageStore()
    
    private var appGroupId: String?
    
    private init() {}
    
    /// Configure the store with your App Group identifier.
    /// Must be called before the widget attempts to read/write timestamps.
    /// `LiveActivitiesSDK.initialize` wires this automatically.
    public func configure(appGroupId: String) {
        self.appGroupId = appGroupId
    }
    
    /// Return the `receivedAt` timestamp for the given `(activityID, hotMessageId)`
    /// pair. On first call for that pair, records `now` and returns it.
    /// When the `hotMessageId` changes for an existing `activityID`, resets
    /// the timestamp to `now` and returns it.
    ///
    /// Thread-safe for widget read/write via UserDefaults.
    public func receivedAt(activityID: String, hotMessageId: String) -> Date {
        guard let defaults = defaults() else {
            // App Group not configured — fall back to ephemeral `now`.
            // The hot message will still render but duration tracking is
            // best-effort across renders.
            return Date()
        }
        
        let key = storageKey(activityID: activityID)
        if let stored = defaults.dictionary(forKey: key),
           let storedId = stored[Keys.id] as? String,
           let storedAt = stored[Keys.at] as? Date,
           storedId == hotMessageId {
            return storedAt
        }
        
        let now = Date()
        defaults.set([Keys.id: hotMessageId, Keys.at: now], forKey: key)
        return now
    }
    
    /// Remove the stored entry for the given `activityID`.
    /// Called by the SDK when the Live Activity ends to keep storage tidy.
    public func clear(activityID: String) {
        defaults()?.removeObject(forKey: storageKey(activityID: activityID))
    }
    
    // Internals
    
    private enum Keys {
        static let id = "id"
        static let at = "at"
    }
    
    private func defaults() -> UserDefaults? {
        guard let appGroupId = appGroupId else {
            LiveActivityLogger.shared.error("HotMessageStore: App Group not configured. Call configure(appGroupId:) first.")
            return nil
        }
        return UserDefaults(suiteName: appGroupId)
    }
    
    private func storageKey(activityID: String) -> String {
        "ppg_hot_msg_\(activityID)"
    }
}
