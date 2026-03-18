//
//  MatchActivityAttributes.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import Foundation
import ActivityKit

/// ActivityAttributes for the football match Live Activity template.
///
/// Static properties are set when creating the activity and cannot change.
/// Dynamic properties are in `ContentState` and update in real-time.
///
/// Usage in Widget Extension:
/// ```swift
/// struct MatchLiveActivity: Widget {
///     var body: some WidgetConfiguration {
///         ActivityConfiguration(for: MatchActivityAttributes.self) { context in
///             PPGMatchLockScreenView(context: context)
///         } dynamicIsland: { context in
///             PPGMatchDynamicIsland(context: context)
///         }
///     }
/// }
/// ```
@available(iOS 16.2, *)
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
        ctaDeepLink: String? = nil
    ) {
        self.matchId = matchId
        self.homeTeamName = homeTeamName
        self.awayTeamName = awayTeamName
        self.homeTeamBadgeUrl = homeTeamBadgeUrl
        self.awayTeamBadgeUrl = awayTeamBadgeUrl
        self.deepLink = deepLink
        self.ctaText = ctaText
        self.ctaDeepLink = ctaDeepLink
    }
}
