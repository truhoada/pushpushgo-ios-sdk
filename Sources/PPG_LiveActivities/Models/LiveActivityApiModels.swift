//
//  LiveActivityApiModels.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import Foundation

// Request Models

/// Request body for registering an ActivityKit push token with the PPG backend
@available(iOS 16.2, *)
struct RegisterPushTokenRequest: Codable {
    let activityId: String
    let templateId: String
    let pushToken: String
    let subscriberId: String?
}

/// Request body for tracking Live Activity events
@available(iOS 16.2, *)
struct LiveActivityEventRequest: Codable {
    let type: String
    let payload: LiveActivityEventPayload
}

/// Event payload with activity details
@available(iOS 16.2, *)
struct LiveActivityEventPayload: Codable {
    let activityId: String
    let templateId: String
    let timestamp: String
    let subscriberId: String?
}
