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
    
    // Static Properties (set at creation, never change)
    
    /// Unique identifier for the match event on PPG backend
    public let matchId: String
    
    /// Home team display name
    public let homeTeamName: String
    
    /// Away team display name
    public let awayTeamName: String
    
    /// URL string for the home team badge/crest image
    public let homeTeamBadgeUrl: String?
    
    /// URL string for the away team badge/crest image
    public let awayTeamBadgeUrl: String?
    
    /// Deep link URL to the match detail screen in the host app
    public let deepLink: String?
    
    /// Call-to-action button text (e.g. "Statistics", "Watch Live")
    public let ctaText: String?
    
    /// Call-to-action deep link URL
    public let ctaDeepLink: String?
    
    /// Backend-provided PPG Live Notification identifier (campaign id).
    /// Present when this Activity was created from a `PPGLiveNotificationDTO`.
    public let notificationId: String?
    
    /// Full backend-driven configuration (status colors, labels, actions, timeout).
    public let configuration: PPGFootballMatchConfiguration?
    
    // ContentState (dynamic, updated in real-time)
    
    public struct ContentState: Codable, Hashable {
        /// Home team score
        public let homeScore: Int
        
        /// Away team score
        public let awayScore: Int
        
        /// Current match phase raw value (maps to MatchPhase enum)
        public let matchPhase: String
        
        /// Current match minute display string (e.g. "45", "45+2", "90+5")
        public let matchMinute: String
        
        /// Optional start date for countdown timer (e.g. before kickoff)
        public let startDate: Date?
        
        public init(
            homeScore: Int,
            awayScore: Int,
            matchPhase: String,
            matchMinute: String,
            startDate: Date? = nil
        ) {
            self.homeScore = homeScore
            self.awayScore = awayScore
            self.matchPhase = matchPhase
            self.matchMinute = matchMinute
            self.startDate = startDate
        }
        
        /// Convenience initializer using the type-safe MatchPhase enum
        public init(
            homeScore: Int,
            awayScore: Int,
            phase: MatchPhase,
            matchMinute: String,
            startDate: Date? = nil
        ) {
            self.homeScore = homeScore
            self.awayScore = awayScore
            self.matchPhase = phase.rawValue
            self.matchMinute = matchMinute
            self.startDate = startDate
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
        matchId: String,
        homeTeamName: String,
        awayTeamName: String,
        homeTeamBadgeUrl: String? = nil,
        awayTeamBadgeUrl: String? = nil,
        deepLink: String? = nil,
        ctaText: String? = nil,
        ctaDeepLink: String? = nil,
        notificationId: String? = nil,
        configuration: PPGFootballMatchConfiguration? = nil
    ) {
        self.matchId = matchId
        self.homeTeamName = homeTeamName
        self.awayTeamName = awayTeamName
        self.homeTeamBadgeUrl = homeTeamBadgeUrl
        self.awayTeamBadgeUrl = awayTeamBadgeUrl
        self.deepLink = deepLink
        self.ctaText = ctaText
        self.ctaDeepLink = ctaDeepLink
        self.notificationId = notificationId
        self.configuration = configuration
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
        
        // First URL action is promoted to the built-in CTA slot for backward
        // compatibility with older widgets that only render a single CTA.
        let firstUrlAction: (name: String, url: String)? = config.actions.compactMap { action -> (String, String)? in
            if case .url(let name, let url, _) = action { return (name, url) }
            return nil
        }.first
        
        let attributes = MatchActivityAttributes(
            matchId: dto.id,
            homeTeamName: config.content.homeTeamName,
            awayTeamName: config.content.awayTeamName,
            homeTeamBadgeUrl: config.content.homeTeamImage,
            awayTeamBadgeUrl: config.content.awayTeamImage,
            deepLink: nil,
            ctaText: firstUrlAction?.name,
            ctaDeepLink: firstUrlAction?.url,
            notificationId: dto.id,
            configuration: config
        )
        
        let state = ContentState(
            homeScore: liveData.homeTeamScore,
            awayScore: liveData.awayTeamScore,
            phase: liveData.status,
            matchMinute: "",
            startDate: dto.startPolicy.scheduledAt
        )
        
        return (attributes, state)
    }
    
    // Config-aware convenience helpers
    
    /// Background color set for the given match status.
    public func background(for status: MatchPhase) -> PPGColorSet? {
        configuration?.background(for: status)
    }
    
    /// Display label for the given match status.
    public func label(for status: MatchPhase) -> String {
        configuration?.label(for: status) ?? status.displayText
    }
    
    /// All backend-defined actions (URL / open app / close) for this activity.
    public var actions: [PPGLiveActivityAction] {
        configuration?.actions ?? []
    }
    
    /// Title shown in the header of the Live Activity.
    public var title: String {
        configuration?.content.title ?? ""
    }
}
