//
//  LiveActivityConfig.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import Foundation
import ActivityKit

/// Configuration for the Live Activities SDK
@available(iOS 17.2, *)
public struct LiveActivityConfig {
    /// API key for PPG authentication
    public let apiKey: String
    
    /// Project ID for the PPG project
    public let projectId: String
    
    /// Use production or test environment
    public let isProduction: Bool
    
    /// Enable debug logging
    public let isDebug: Bool
    
    public init(
        apiKey: String,
        projectId: String,
        isProduction: Bool = true,
        isDebug: Bool = false
    ) {
        self.apiKey = apiKey
        self.projectId = projectId
        self.isProduction = isProduction
        self.isDebug = isDebug
    }
}

/// Policy for dismissing a Live Activity from the Lock Screen after ending
@available(iOS 17.2, *)
public enum LiveActivityDismissPolicy: Sendable {
    /// Remove immediately from Lock Screen
    case immediate
    /// Keep on Lock Screen until the specified date, then remove
    case after(Date)
    /// Use system default (up to 4 hours on Lock Screen)
    case `default`
    
    func toSystemPolicy() -> ActivityUIDismissalPolicy {
        switch self {
        case .immediate: return .immediate
        case .after(let date): return .after(date)
        case .default: return .default
        }
    }
}

/// Information about an active Live Activity
@available(iOS 17.2, *)
public struct LiveActivityInfo: Sendable {
    /// The activity identifier
    public let activityId: String
    
    /// The template ID used to create this activity
    public let templateId: String
    
    /// The ActivityKit push token (hex string) for server-driven updates
    public let pushToken: String?
    
    /// When the activity was started
    public let startedAt: Date
    
    public init(
        activityId: String,
        templateId: String,
        pushToken: String?,
        startedAt: Date
    ) {
        self.activityId = activityId
        self.templateId = templateId
        self.pushToken = pushToken
        self.startedAt = startedAt
    }
}

/// Events tracked for Live Activity analytics
@available(iOS 17.2, *)
public enum LiveActivityEventType: String, Codable, Sendable {
    case started = "la.started"
    case updated = "la.updated"
    case ctaClicked = "la.cta_clicked"
    case ended = "la.ended"
    case dismissed = "la.dismissed"
    case pushTokenRegistered = "la.push_token_registered"
}
