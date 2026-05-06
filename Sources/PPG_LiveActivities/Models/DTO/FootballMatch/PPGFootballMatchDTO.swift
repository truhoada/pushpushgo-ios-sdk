//
//  PPGFootballMatchDTO.swift
//  PPG_LiveActivities
//
//  Codable DTOs for the football match tracking Live Notification template.
//

import Foundation

// Live Data (dynamic state — sent via push updates)

/// Dynamic, real-time data for the football match Live Notification.
@available(iOS 17.2, *)
public struct PPGFootballMatchLiveData: Codable, Sendable, Hashable {
    /// Discriminator (always `FOOTBALL_MATCH_TRACKING` on the wire).
    public let type: PPGLiveActivityTemplate
    public let homeTeamScore: Int
    public let awayTeamScore: Int
    public let status: MatchPhase
    
    public init(
        type: PPGLiveActivityTemplate = .footballMatchTracking,
        homeTeamScore: Int,
        awayTeamScore: Int,
        status: MatchPhase
    ) {
        self.type = type
        self.homeTeamScore = homeTeamScore
        self.awayTeamScore = awayTeamScore
        self.status = status
    }
}

// Configuration (static — set at campaign creation)

/// Text & image content for the football match Live Notification.
@available(iOS 17.2, *)
public struct PPGFootballMatchContent: Codable, Sendable, Hashable {
    public let title: String
    public let homeTeamName: String
    public let homeTeamImage: String?
    public let awayTeamName: String
    public let awayTeamImage: String?
    
    public init(
        title: String,
        homeTeamName: String,
        homeTeamImage: String?,
        awayTeamName: String,
        awayTeamImage: String?
    ) {
        self.title = title
        self.homeTeamName = homeTeamName
        self.homeTeamImage = homeTeamImage
        self.awayTeamName = awayTeamName
        self.awayTeamImage = awayTeamImage
    }
}

/// iOS-specific design for the football match template.
@available(iOS 17.2, *)
public struct PPGFootballMatchIOSDesign: Codable, Sendable, Hashable {
    /// Background color (or gradient) rendered for each match status.
    /// Keys are raw `MatchPhase` values (e.g. `"PRE_MATCH"`).
    /// `nil` means the SDK should use its default background.
    public let statusBackgrounds: [String: PPGColorSet]?
    
    public init(statusBackgrounds: [String: PPGColorSet]?) {
        self.statusBackgrounds = statusBackgrounds
    }
    
    /// Resolved background for a given match status, with `.other` fallback.
    public func background(for status: MatchPhase) -> PPGColorSet? {
        guard let map = statusBackgrounds else { return nil }
        return map[status.rawValue] ?? map[MatchPhase.other.rawValue]
    }
}

/// Android-specific design for the football match template.
/// Included for DTO completeness; not used by iOS SDK directly.
@available(iOS 17.2, *)
public struct PPGFootballMatchAndroidDesign: Codable, Sendable, Hashable {
    public let hasTrackerIcon: Bool
    public let progressBarColor: PPGBasicColorSet
    public let breakTimeBarColor: PPGBasicColorSet?
    
    public init(
        hasTrackerIcon: Bool,
        progressBarColor: PPGBasicColorSet,
        breakTimeBarColor: PPGBasicColorSet?
    ) {
        self.hasTrackerIcon = hasTrackerIcon
        self.progressBarColor = progressBarColor
        self.breakTimeBarColor = breakTimeBarColor
    }
}

/// Full design block (both iOS and Android sections).
@available(iOS 17.2, *)
public struct PPGFootballMatchDesign: Codable, Sendable, Hashable {
    public let android: PPGFootballMatchAndroidDesign
    public let ios: PPGFootballMatchIOSDesign
    
    public init(
        android: PPGFootballMatchAndroidDesign,
        ios: PPGFootballMatchIOSDesign
    ) {
        self.android = android
        self.ios = ios
    }
}

/// Full configuration for the football match tracking Live Notification.
@available(iOS 17.2, *)
public struct PPGFootballMatchConfiguration: Codable, Sendable, Hashable {
    /// Discriminator (always `FOOTBALL_MATCH_TRACKING` on the wire).
    public let type: PPGLiveActivityTemplate
    public let content: PPGFootballMatchContent
    public let design: PPGFootballMatchDesign
    /// Per-status labels. Keys are raw `MatchPhase` values (e.g. `"PRE_MATCH"`).
    public let statusLabels: [String: String]
    public let actions: [PPGLiveActivityAction]
    public let timeout: PPGLiveActivityTimeout
    
    public init(
        type: PPGLiveActivityTemplate = .footballMatchTracking,
        content: PPGFootballMatchContent,
        design: PPGFootballMatchDesign,
        statusLabels: [String: String],
        actions: [PPGLiveActivityAction],
        timeout: PPGLiveActivityTimeout
    ) {
        self.type = type
        self.content = content
        self.design = design
        self.statusLabels = statusLabels
        self.actions = actions
        self.timeout = timeout
    }
    
    // Lookup Helpers
    
    /// Background color set for a given match status, falling back to `.other` if missing.
    public func background(for status: MatchPhase) -> PPGColorSet? {
        design.ios.background(for: status)
    }
    
    /// Label for a given match status, falling back to the built-in `displayText`.
    public func label(for status: MatchPhase) -> String {
        statusLabels[status.rawValue] ?? statusLabels[MatchPhase.other.rawValue] ?? status.displayText
    }
}
