//
//  InstallationIDStore.swift
//  PPG_LiveActivities
//
//  Persistent UUIDv4 used as the `installationId` field when registering
//  Live Notification subscribers. The id is generated lazily on first
//  access and persisted in `UserDefaults.standard`. It is intentionally
//  decoupled from `PPG.subscriberId` (push subscriber) — backend treats
//  `installationId` as a per-device analytics handle, not a user identity.
//

import Foundation

@available(iOS 17.2, *)
internal final class InstallationIDStore {
    
    static let shared = InstallationIDStore()
    
    private static let storageKey = "PPGLiveActivities_InstallationID"
    private let defaults: UserDefaults
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    /// Returns the persistent installation id, generating one on first call.
    var installationId: String {
        if let existing = defaults.string(forKey: Self.storageKey),
           !existing.isEmpty {
            return existing
        }
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: Self.storageKey)
        LiveActivityLogger.shared.debug("Generated installationId: \(fresh)")
        return fresh
    }
    
    /// Reset the persisted id. Intended for diagnostics and tests.
    func reset() {
        defaults.removeObject(forKey: Self.storageKey)
    }
}
