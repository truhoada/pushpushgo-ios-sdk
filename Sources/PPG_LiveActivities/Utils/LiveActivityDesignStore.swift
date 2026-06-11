//
//  LiveActivityDesignStore.swift
//  PPG_LiveActivities
//

import Foundation

/// Protocol adopted by `ActivityAttributes` types that carry a PPG iOS design
/// block. Enables `LiveNotificationSubscriber` to cache the design received from
/// the REST bootstrap GET — whose attributes may have been sent as `{"ios":{}}`
/// by APNs push-to-start (ActivityKit attributes are immutable after creation).
@available(iOS 17.2, *)
public protocol PPGLiveActivityDesignCacheable {
    /// Unique campaign identifier, used as the cache key.
    var liveNotificationId: String { get }
    /// The iOS design block (status backgrounds, etc.) to cache.
    var iosDesign: PPGFootballMatchIOSDesign { get }
}

@available(iOS 17.2, *)
public class LiveActivityDesignStore {
    
    public static let shared = LiveActivityDesignStore()
    
    private var appGroupId: String?
    
    private init() {}
    
    // Configuration
    
    public func configure(appGroupId: String) {
        self.appGroupId = appGroupId
    }
    
    // Write (host app)
    
    /// Persist a design for the given campaign so the widget can read it later.
    public func cacheDesign(_ design: PPGFootballMatchIOSDesign, liveNotificationId: String) {
        guard let data = try? JSONEncoder().encode(design) else { return }
        defaults()?.set(data, forKey: cacheKey(for: liveNotificationId))
    }
    
    // Read (widget extension)
    
    /// Background color set for the given phase, loaded from the cache.
    /// Returns `nil` if the cache is empty or the phase has no entry.
    public func background(for phase: MatchPhase, liveNotificationId: String) -> PPGColorSet? {
        guard let defaults = defaults(),
              let data = defaults.data(forKey: cacheKey(for: liveNotificationId)),
              let design = try? JSONDecoder().decode(PPGFootballMatchIOSDesign.self, from: data)
        else { return nil }
        return design.background(for: phase)
    }
    
    // Private
    
    private func defaults() -> UserDefaults? {
        guard let id = appGroupId else {
            LiveActivityLogger.shared.error(
                "LiveActivityDesignStore: App Group not configured. Call configure(appGroupId:) first."
            )
            return nil
        }
        return UserDefaults(suiteName: id)
    }
    
    private func cacheKey(for liveNotificationId: String) -> String {
        "ppg_la_design_\(liveNotificationId)"
    }
}
