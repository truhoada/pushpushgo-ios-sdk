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
    /// Timestamp when the current status was last changed (ISO-8601).
    /// Used client-side to calculate the current match minute.
    public let statusChangedAt: Date?
    
    public init(
        type: PPGLiveActivityTemplate = .footballMatchTracking,
        homeTeamScore: Int,
        awayTeamScore: Int,
        status: MatchPhase,
        statusChangedAt: Date? = nil
    ) {
        self.type = type
        self.homeTeamScore = homeTeamScore
        self.awayTeamScore = awayTeamScore
        self.status = status
        self.statusChangedAt = statusChangedAt
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
    /// Single background color (or gradient) applied to the Live Activity
    /// regardless of match status. `nil` means "device system" mode — the SDK
    /// renders the iOS system-adaptive background. Backend compacted the old
    /// per-status `statusBackgrounds` map into this one field to shrink the
    /// APNs `attributes` payload (4 KB limit).
    public let statusBackground: PPGColorSet?

    public init(statusBackground: PPGColorSet?) {
        self.statusBackground = statusBackground
    }

    /// Resolved background. The same color is used for every phase now, so
    /// `status` is ignored — kept in the signature for call-site stability.
    public func background(for status: MatchPhase) -> PPGColorSet? {
        statusBackground
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

/// Full design block. The iOS section is always present; the Android
/// section is only delivered in REST responses (`GET /live-notifications/{id}`)
/// — APNs `attributes` payloads contain only `ios` to keep wire size small.
@available(iOS 17.2, *)
public struct PPGFootballMatchDesign: Codable, Sendable, Hashable {
    public let android: PPGFootballMatchAndroidDesign?
    public let ios: PPGFootballMatchIOSDesign
    
    public init(
        android: PPGFootballMatchAndroidDesign? = nil,
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
    /// Deep-link URL opened when the user taps the Live Activity background.
    public let url: String?
    
    public init(
        type: PPGLiveActivityTemplate = .footballMatchTracking,
        content: PPGFootballMatchContent,
        design: PPGFootballMatchDesign,
        statusLabels: [String: String],
        actions: [PPGLiveActivityAction],
        timeout: PPGLiveActivityTimeout,
        url: String? = nil
    ) {
        self.type = type
        self.content = content
        self.design = design
        self.statusLabels = statusLabels
        self.actions = actions
        self.timeout = timeout
        self.url = url
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
