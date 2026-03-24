//
//  LiveActivityObserverModels.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 24/03/2026.
//

import Foundation

/// Status updates emitted by `observeLiveActivity` to inform the caller about lifecycle changes.
@available(iOS 17.2, *)
public enum LiveActivityObserverStatus: Sendable {
    /// Observer registered — push-to-start token sent to PPG backend.
    /// The campaign may not have started yet.
    case registered
    
    /// The Live Activity has been started on this device (via push-to-start).
    /// `activityId` is the local ActivityKit identifier.
    case started(activityId: String)
    
    /// The Live Activity received a content update (via push or channel).
    case updated(activityId: String)
    
    /// The Live Activity has ended.
    case ended(activityId: String)
    
    /// An error occurred during observation.
    case error(LiveActivityObserverError)
}

/// Errors specific to the observer flow.
@available(iOS 17.2, *)
public enum LiveActivityObserverError: Error, Sendable {
    /// Live Activities are not enabled on this device.
    case activitiesNotEnabled
    /// Failed to obtain push-to-start token.
    case pushToStartTokenUnavailable
    /// Failed to fetch channel information from PPG backend.
    case channelFetchFailed(underlying: Error)
    /// Failed to register observer with PPG backend.
    case registrationFailed(underlying: Error)
    /// The campaign was not found or has already ended.
    case campaignUnavailable
}

/// Response from PPG backend when registering an observer.
@available(iOS 17.2, *)
struct ObserveResponse: Codable {
    /// Current campaign status: "scheduled", "live", "ended"
    let status: String
    /// Channel ID for iOS 18+ broadcast updates (nil on older iOS or if not available)
    let channelId: String?
}

/// Request body for registering as a Live Activity observer.
@available(iOS 17.2, *)
struct ObserveRequest: Codable {
    let campaignId: String
    let templateId: String
    let pushToStartToken: String
    let subscriberId: String?
    /// true if the device supports channel-based updates (iOS 18+)
    let supportsChannels: Bool
}
