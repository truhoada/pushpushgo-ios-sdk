//
//  PPGLiveActivityEnums.swift
//  PPG_LiveActivities
//
//  Shared enums mirroring backend DTOs.
//

import Foundation

/// Template identifier for the Live Notification.
@available(iOS 17.2, *)
public enum PPGLiveActivityTemplate: String, Codable, Sendable {
    case footballMatchTracking = "FOOTBALL_MATCH_TRACKING"
}

/// Current lifecycle status of the Live Notification on the backend.
@available(iOS 17.2, *)
public enum PPGLiveActivityLifecycleStatus: String, Codable, Sendable {
    case draft = "DRAFT"
    case pending = "PENDING"
    case ongoing = "ONGOING"
    case stopped = "STOPPED"
    case expired = "EXPIRED"
}

/// Image slot identifiers used within a Live Notification template.
@available(iOS 17.2, *)
public enum PPGLiveActivityImageType: String, Codable, Sendable {
    case logo = "live_notification_logo"
}

/// Countdown shown before the activity goes live.
@available(iOS 17.2, *)
public struct PPGLiveActivityCountdown: Codable, Sendable, Hashable {
    public let message: String
    public let seconds: Int
    
    public init(message: String, seconds: Int) {
        self.message = message
        self.seconds = seconds
    }
}

/// Policy describing when the Live Notification should start.
@available(iOS 17.2, *)
public struct PPGLiveActivityStartPolicy: Codable, Sendable, Hashable {
    /// ISO-8601 scheduled start timestamp (backend sends as string).
    public let scheduledAt: Date
    public let countdown: PPGLiveActivityCountdown?
    
    public init(scheduledAt: Date, countdown: PPGLiveActivityCountdown?) {
        self.scheduledAt = scheduledAt
        self.countdown = countdown
    }
}

/// Timeout expressed in minutes.
@available(iOS 17.2, *)
public struct PPGLiveActivityTimeout: Codable, Sendable, Hashable {
    public let minutes: Int
    
    public init(minutes: Int) {
        self.minutes = minutes
    }
}
