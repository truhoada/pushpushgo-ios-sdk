//
//  MatchActivityAttributes.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import Foundation
import ActivityKit

/// ActivityAttributes for the football match Live Activity template.

@available(iOS 17.2, *)
public struct MatchActivityAttributes: ActivityAttributes {
    
    // Static Properties — flat mirror of the backend `attributes` payload.
    // Layout matches `PPGFootballMatchConfiguration` + `notificationId`
    
    /// PPG Live Notification identifier (campaign id).
    public let notificationId: String
    
    /// Template discriminator (always `.footballMatchTracking` on the wire).
    public let type: PPGLiveActivityTemplate
    
    /// Static content (title, team names, badge image URLs).
    public let content: PPGFootballMatchContent
    
    /// Per-platform design (status backgrounds, progress bar colors).
    public let design: PPGFootballMatchDesign
    
    /// Per-status display labels. Keys are raw `MatchPhase` values.
    public let statusLabels: [String: String]
    
    /// Backend-defined CTA actions (URL / open app / close).
    public let actions: [PPGLiveActivityAction]
    
    /// Maximum activity lifetime hint.
    public let timeout: PPGLiveActivityTimeout
    
    // ContentState (dynamic, updated in real-time)
    
    public struct ContentState: Codable, Hashable {
        /// Home team score
        public let homeScore: Int
        
        /// Away team score
        public let awayScore: Int
        
        /// Current match phase raw value (maps to MatchPhase enum)
        public let matchPhase: String
        
        /// Current match minute display string (e.g. "45", "45+2", "90+5").
        /// Optional — backend may omit it when it's not meaningful
        /// (e.g. before kickoff or at full-time).
        public let matchMinute: String?
        
        /// Optional start date for countdown timer (e.g. before kickoff)
        public let startDate: Date?
        
        /// Optional transient hot message (e.g. "Goal cancelled after VAR").
        /// When set, the widget renders it for `durationSeconds` after the
        /// first render on the device, then auto-hides. Set to `nil` by the
        /// backend to clear it early.
        public let hotMessage: PPGHotMessage?
        
        public init(
            homeScore: Int,
            awayScore: Int,
            matchPhase: String,
            matchMinute: String? = nil,
            startDate: Date? = nil,
            hotMessage: PPGHotMessage? = nil
        ) {
            self.homeScore = homeScore
            self.awayScore = awayScore
            self.matchPhase = matchPhase
            self.matchMinute = matchMinute
            self.startDate = startDate
            self.hotMessage = hotMessage
        }
        
        /// Convenience initializer using the type-safe MatchPhase enum
        public init(
            homeScore: Int,
            awayScore: Int,
            phase: MatchPhase,
            matchMinute: String? = nil,
            startDate: Date? = nil,
            hotMessage: PPGHotMessage? = nil
        ) {
            self.homeScore = homeScore
            self.awayScore = awayScore
            self.matchPhase = phase.rawValue
            self.matchMinute = matchMinute
            self.startDate = startDate
            self.hotMessage = hotMessage
        }
        
        /// Parsed MatchPhase from the raw string
        public var phase: MatchPhase? {
            return MatchPhase(rawValue: matchPhase)
        }
        
        /// Human-readable phase display text
        public var phaseDisplayText: String {
            return phase?.displayText ?? matchPhase
        }
        
        /// Score formatted as "homeScore : awayScore"
        public var scoreDisplay: String {
            return "\(homeScore) : \(awayScore)"
        }
        
        /// Compact score formatted as "homeScore:awayScore"
        public var scoreCompact: String {
            return "\(homeScore):\(awayScore)"
        }
    }
    
    // Initializer
    
    public init(
        notificationId: String,
        type: PPGLiveActivityTemplate = .footballMatchTracking,
        content: PPGFootballMatchContent,
        design: PPGFootballMatchDesign,
        statusLabels: [String: String] = [:],
        actions: [PPGLiveActivityAction] = [],
        timeout: PPGLiveActivityTimeout
    ) {
        self.notificationId = notificationId
        self.type = type
        self.content = content
        self.design = design
        self.statusLabels = statusLabels
        self.actions = actions
        self.timeout = timeout
    }
    
    // View-facing computed properties.
    // Widget views read these instead of reaching into nested `content`.
    
    /// Alias for `notificationId` — stable id of the match.
    public var matchId: String { notificationId }
    
    /// Home team display name (from `content`).
    public var homeTeamName: String { content.homeTeamName }
    
    /// Away team display name (from `content`).
    public var awayTeamName: String { content.awayTeamName }
    
    /// URL string for the home team badge image.
    /// Empty string from backend is normalized to `nil` (no image).
    public var homeTeamBadgeUrl: String? {
        Self.nonEmpty(content.homeTeamImage)
    }
    
    /// URL string for the away team badge image.
    /// Empty string from backend is normalized to `nil` (no image).
    public var awayTeamBadgeUrl: String? {
        Self.nonEmpty(content.awayTeamImage)
    }
    
    /// Returns `value` if it's non-empty after trimming, otherwise `nil`.
    /// Backend uses empty strings as a sentinel for "no image".
    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }
    
    /// Title shown in the header of the Live Activity.
    public var title: String { content.title }
    
    /// Deep link to the match detail screen.
    /// Currently not part of backend payload; reserved for future use.
    public var deepLink: String? { nil }
    
    /// Convenience CTA text — first URL action's name, if any.
    public var ctaText: String? { firstUrlAction?.name }
    
    /// Convenience CTA deep link — first URL action's url, if any.
    public var ctaDeepLink: String? { firstUrlAction?.url }
    
    private var firstUrlAction: (name: String, url: String)? {
        actions.compactMap { action -> (String, String)? in
            if case .url(let name, let url, _) = action { return (name, url) }
            return nil
        }.first
    }
    
    // Config-aware lookup helpers
    
    /// Background color set for the given match status, taken from backend
    /// design. Falls back to `OTHER` and then to `nil` if no entry is defined.
    public func background(for status: MatchPhase) -> PPGColorSet? {
        design.ios.background(for: status)
    }
    
    /// Display label for the given match status. Falls back to
    /// `MatchPhase.displayText` when no override is provided by the backend.
    public func label(for status: MatchPhase) -> String {
        statusLabels[status.rawValue]
            ?? statusLabels[MatchPhase.other.rawValue]
            ?? status.displayText
    }
    
    // Backend DTO mapping
    
    /// Build `MatchActivityAttributes` + initial `ContentState` from a backend
    /// `PPGLiveNotificationDTO`. Returns `nil` if the DTO is not a football match
    /// template.
    ///
    /// Use this when starting a Live Activity in response to an in-app event
    /// delivered by PPG backend. The initial `ContentState` reflects the
    /// current `liveData` snapshot.
    public static func from(
        dto: PPGLiveNotificationDTO
    ) -> (attributes: MatchActivityAttributes, initialState: ContentState)? {
        guard let config = dto.footballMatchConfiguration,
              let liveData = dto.footballMatchLiveData else {
            return nil
        }
        
        let attributes = MatchActivityAttributes(
            notificationId: dto.id,
            type: config.type,
            content: config.content,
            design: config.design,
            statusLabels: config.statusLabels,
            actions: config.actions,
            timeout: config.timeout
        )
        
        let state = ContentState(
            homeScore: liveData.homeTeamScore,
            awayScore: liveData.awayTeamScore,
            phase: liveData.status,
            matchMinute: nil,
            startDate: dto.startPolicy.scheduledAt
        )
        
        return (attributes, state)
    }
}
