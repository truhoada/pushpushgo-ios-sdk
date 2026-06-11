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
    
    // Static Properties — exact field-for-field mirror of the backend
    // `aps.attributes` payload sent in the `event:start` APNs push.
    
    /// PPG Live Notification identifier (per-match id used for subscriber
    /// registration and REST lookups).
    public let liveNotificationId: String
    
    /// Template discriminator (always `.footballMatchTracking` on the wire).
    public let template: PPGLiveActivityTemplate
    
    /// Static content (title, team names, badge image URLs).
    public let content: PPGFootballMatchContent
    
    /// Per-platform design. iOS-only on the APNs wire; `design.android`
    /// is decoded from REST responses but not from push attributes.
    public let design: PPGFootballMatchDesign
    
    /// Per-status display labels. Keys are raw `MatchPhase` values.
    public let statusLabels: [String: String]
    
    /// Backend-defined CTA actions (URL / open app / close).
    /// Wire name is `actionSet` to match the APNs payload.
    public let actionSet: [PPGLiveActivityAction]
    
    /// Maximum activity lifetime hint.
    public let timeout: PPGLiveActivityTimeout
    
    /// Deep-link URL opened when the user taps the Live Activity background.
    public let url: String?
    
    /// Target date for the pre-match countdown (= `startPolicy.scheduledAt`).
    /// When non-nil and `status == .preMatch`, views show a countdown timer instead of the score.
    public let countdownDate: Date?
    
    /// Message displayed beneath the countdown timer (e.g. "Match will start soon").
    public let countdownMessage: String?
    
    // ContentState (dynamic, updated in real-time via APNs `event:update`)
    
    public struct ContentState: Codable, Hashable {
        /// Home team score (wire: `homeTeamScore`).
        public let homeTeamScore: Int
        
        /// Away team score (wire: `awayTeamScore`).
        public let awayTeamScore: Int
        
        /// Current match phase (wire: `status`, raw enum value).
        public let status: MatchPhase
        
        /// Optional transient hot message (e.g. "Goal cancelled after VAR").
        /// When set, the widget renders it until
        /// `min(receivedAt + PPGHotMessage.maxDisplayDuration, hotMessage.expiresAt)`,
        /// then auto-hides. Backend may also push the same content state with
        /// `hotMessage: nil` to clear it early.
        public let hotMessage: PPGHotMessage?
        
        /// Target date for the pre-match countdown (= `startPolicy.scheduledAt`).
        /// Sent by the backend in `aps.content-state` so it arrives for all subscriber types.
        public let countdownDate: Date?
        
        /// Message shown beneath the countdown timer (e.g. "Match will start soon").
        public let countdownMessage: String?
        
        /// Timestamp when the current `status` was last changed.
        /// Used to compute the live match minute client-side.
        public let statusChangedAt: Date?

        /// Backend live-data revision (wire: `liveDataVersion`). Reported with
        /// every statistics event so the backend can correlate a tap/start/close
        /// with the exact live-data snapshot the user saw. Defaults to `0` when
        /// the backend payload omits it.
        public let liveDataVersion: Int

        public init(
            homeTeamScore: Int,
            awayTeamScore: Int,
            status: MatchPhase,
            hotMessage: PPGHotMessage? = nil,
            countdownDate: Date? = nil,
            countdownMessage: String? = nil,
            statusChangedAt: Date? = nil,
            liveDataVersion: Int = 0
        ) {
            self.homeTeamScore = homeTeamScore
            self.awayTeamScore = awayTeamScore
            self.status = status
            self.hotMessage = hotMessage
            self.countdownDate = countdownDate
            self.countdownMessage = countdownMessage
            self.statusChangedAt = statusChangedAt
            self.liveDataVersion = liveDataVersion
        }
        
        /// Prefix added in front of the live `Text(timerInterval:)` clock for
        /// added-time phases (e.g. `"45+"` in `"45+2:13"`). `nil` for regular halves
        /// where the timer counts up from 0 directly, and for non-playing phases.
        public var matchMinutePrefix: String? {
            switch status {
            case .firstHalfAddedTime:           return "45+"
            case .secondHalfAddedTime:          return "90+"
            case .extraTimeFirstHalfAddedTime:  return "105+"
            case .extraTimeSecondHalfAddedTime: return "120+"
            default:                            return nil
            }
        }
        
        /// Whether to render the live `Text(timerInterval:)` match clock alongside
        /// the status label. `true` for any phase where the ball is in play.
        public var showsMatchClock: Bool {
            statusChangedAt != nil && status.isPlaying && status != .penaltyShootout
        }
        
        /// Reference date for the live `Text(timerInterval:)` clock.
        /// For regular halves it's shifted into the past so the displayed elapsed
        /// time matches the total match minute (e.g. 2nd half kickoff shows `45:00`,
        /// not `00:00`). For added time phases the timer counts up from 0 and the
        /// caller prefixes `matchMinutePrefix` ("45+", "90+", ...) in front of it.
        public var matchClockStartDate: Date? {
            guard let changedAt = statusChangedAt else { return nil }
            let offsetMinutes: Int
            switch status {
            case .firstHalf:                      offsetMinutes = 0
            case .firstHalfAddedTime:             offsetMinutes = 0
            case .secondHalf:                     offsetMinutes = -45
            case .secondHalfAddedTime:            offsetMinutes = 0
            case .extraTimeFirstHalf:             offsetMinutes = -90
            case .extraTimeFirstHalfAddedTime:    offsetMinutes = 0
            case .extraTimeSecondHalf:            offsetMinutes = -105
            case .extraTimeSecondHalfAddedTime:   offsetMinutes = 0
            default: return nil
            }
            return changedAt.addingTimeInterval(TimeInterval(offsetMinutes * 60))
        }
        
        /// Current match minute string (e.g. "23'" or "45+2'") at a given reference
        /// date, computed from `statusChangedAt` and `status`. Returns `nil` for
        /// non-playing phases or when `statusChangedAt` is unavailable.
        public func matchMinuteText(at date: Date = .now) -> String? {
            guard let changedAt = statusChangedAt else { return nil }
            let elapsed = Int(max(0, date.timeIntervalSince(changedAt)) / 60) + 1
            switch status {
            case .firstHalf:                      return "\(min(elapsed, 45))'"
            case .firstHalfAddedTime:             return "45+\(elapsed)'"
            case .secondHalf:                     return "\(min(45 + elapsed, 90))'"
            case .secondHalfAddedTime:            return "90+\(elapsed)'"
            case .extraTimeFirstHalf:             return "\(min(90 + elapsed, 105))'"
            case .extraTimeFirstHalfAddedTime:    return "105+\(elapsed)'"
            case .extraTimeSecondHalf:            return "\(min(105 + elapsed, 120))'"
            case .extraTimeSecondHalfAddedTime:   return "120+\(elapsed)'"
            default:                              return nil
            }
        }
        
        /// Human-readable phase display text
        public var phaseDisplayText: String { status.displayText }
        
        /// Score formatted as "homeTeamScore : awayTeamScore"
        public var scoreDisplay: String {
            return "\(homeTeamScore) : \(awayTeamScore)"
        }
        
        /// Compact score formatted as "homeTeamScore:awayTeamScore"
        public var scoreCompact: String {
            return "\(homeTeamScore):\(awayTeamScore)"
        }
        
        // Tolerant Codable — if `hotMessage` is present but fails to decode
        // (e.g. unexpected field names or types from the backend), log the
        // error and fall back to `nil` so the score/status update still lands.
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            homeTeamScore = try c.decode(Int.self, forKey: .homeTeamScore)
            awayTeamScore = try c.decode(Int.self, forKey: .awayTeamScore)
            status = try c.decode(MatchPhase.self, forKey: .status)
            do {
                hotMessage = try c.decodeIfPresent(PPGHotMessage.self, forKey: .hotMessage)
            } catch {
                LiveActivityLogger.shared.error(
                    "ContentState: hotMessage decode failed (falling back to nil). Error: \(error)"
                )
                hotMessage = nil
            }
            countdownDate = Self.decodeDateField(from: c, key: .countdownDate)
            countdownMessage = try c.decodeIfPresent(String.self, forKey: .countdownMessage)
            statusChangedAt = Self.decodeDateField(from: c, key: .statusChangedAt)
            // Tolerant: backend sends `liveDataVersion` as a number; ActivityKit's
            // internal round-trip after `activity.update()` may re-encode it as a
            // Double. Accept either, fall back to 0.
            if let v = try? c.decodeIfPresent(Int.self, forKey: .liveDataVersion) {
                liveDataVersion = v
            } else if let d = try? c.decodeIfPresent(Double.self, forKey: .liveDataVersion) {
                liveDataVersion = Int(d)
            } else {
                liveDataVersion = 0
            }
        }
        
        /// Shared ISO-8601 formatters — `ISO8601DateFormatter` is thread-safe
        /// and expensive to create, and this decode path runs on every push.
        private static let isoFormatterFractional: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()
        private static let isoFormatter: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f
        }()

        /// Decode a Date that may arrive as an ISO-8601 string (backend APNs) or as a
        /// Double Unix timestamp (ActivityKit's internal round-trip after `activity.update()`).
        private static func decodeDateField(
            from c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys
        ) -> Date? {
            if let raw = try? c.decodeIfPresent(String.self, forKey: key) {
                if let d = Self.isoFormatterFractional.date(from: raw) { return d }
                return Self.isoFormatter.date(from: raw)
            }
            return try? c.decodeIfPresent(Date.self, forKey: key)
        }
        
        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(homeTeamScore, forKey: .homeTeamScore)
            try c.encode(awayTeamScore, forKey: .awayTeamScore)
            try c.encode(status, forKey: .status)
            try c.encodeIfPresent(hotMessage, forKey: .hotMessage)
            try c.encodeIfPresent(countdownDate, forKey: .countdownDate)
            try c.encodeIfPresent(countdownMessage, forKey: .countdownMessage)
            try c.encodeIfPresent(statusChangedAt, forKey: .statusChangedAt)
            try c.encode(liveDataVersion, forKey: .liveDataVersion)
        }

        private enum CodingKeys: String, CodingKey {
            case homeTeamScore, awayTeamScore, status, hotMessage
            case countdownDate, countdownMessage
            case statusChangedAt
            case liveDataVersion
        }
    }
    
    // Initializer
    
    public init(
        liveNotificationId: String,
        template: PPGLiveActivityTemplate = .footballMatchTracking,
        content: PPGFootballMatchContent,
        design: PPGFootballMatchDesign,
        statusLabels: [String: String] = [:],
        actionSet: [PPGLiveActivityAction] = [],
        timeout: PPGLiveActivityTimeout,
        url: String? = nil,
        countdownDate: Date? = nil,
        countdownMessage: String? = nil
    ) {
        self.liveNotificationId = liveNotificationId
        self.template = template
        self.content = content
        self.design = design
        self.statusLabels = statusLabels
        self.actionSet = actionSet
        self.timeout = timeout
        self.url = url
        self.countdownDate = countdownDate
        self.countdownMessage = countdownMessage
    }
    
    // Tolerant Codable
    //
    // Backend's APNs `aps.attributes` payload may differ from the REST DTO
    // in subtle ways (different field names, omitted optional collections).
    // To avoid `NSCoderValueNotFoundError` killing the activity right after
    // ActivityKit creates it, we:
    //   - accept multiple wire names for the id (`liveNotificationId` / `id` /
    //     `notificationId`) and template (`template` / `type`),
    //   - default `statusLabels` and `actionSet` to empty when absent,
    //   - log a diagnostic dump of all present keys when decoding fails so
    //     we can pinpoint the missing field without guessing.
    
    private enum CodingKeys: String, CodingKey {
        case liveNotificationId, id, notificationId
        case template, type
        case content, design, statusLabels
        case actionSet, actions
        case timeout
        case url
        case startPolicy
        case countdownDate, countdownMessage
    }
    
    public init(from decoder: Decoder) throws {
        do {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            
            // id — accept any of the three known wire names.
            if let v = try c.decodeIfPresent(String.self, forKey: .liveNotificationId) {
                self.liveNotificationId = v
            } else if let v = try c.decodeIfPresent(String.self, forKey: .id) {
                self.liveNotificationId = v
            } else if let v = try c.decodeIfPresent(String.self, forKey: .notificationId) {
                self.liveNotificationId = v
            } else {
                throw DecodingError.keyNotFound(
                    CodingKeys.liveNotificationId,
                    .init(codingPath: c.codingPath, debugDescription: "Missing id/liveNotificationId/notificationId")
                )
            }
            
            // template — accept `template` or `type`.
            self.template = try c.decodeIfPresent(PPGLiveActivityTemplate.self, forKey: .template)
                ?? c.decodeIfPresent(PPGLiveActivityTemplate.self, forKey: .type)
                ?? .footballMatchTracking
            
            self.content = try c.decode(PPGFootballMatchContent.self, forKey: .content)
            self.design = try c.decode(PPGFootballMatchDesign.self, forKey: .design)
            self.statusLabels = Self.decodeStatusLabels(from: c)
            
            // actionSet — accept `actionSet` or `actions`. Each element
            // requires a `type` discriminator (URL/OPEN_APP/CLOSE). If the
            // backend's APNs payload omits `type` on any element we would
            // otherwise fail the *entire* attributes decode and the activity
            // would never appear. Fall back to an empty action list with a
            // loud warning so the activity is still rendered.
            self.actionSet = Self.decodeActionSet(from: c)
            
            self.timeout = try c.decode(PPGLiveActivityTimeout.self, forKey: .timeout)
            self.url = try c.decodeIfPresent(String.self, forKey: .url)
            let policy = try c.decodeIfPresent(StartPolicyCodable.self, forKey: .startPolicy)
            self.countdownDate = try c.decodeIfPresent(Date.self, forKey: .countdownDate) ?? policy?.scheduledAt
            self.countdownMessage = try c.decodeIfPresent(String.self, forKey: .countdownMessage) ?? policy?.countdown?.message
        } catch {
            // Dump all top-level keys present in the payload to help diagnose
            // schema mismatches between backend push payload and this model.
            if let raw = try? decoder.container(keyedBy: DynamicCodingKey.self) {
                let keys = raw.allKeys.map(\.stringValue).sorted().joined(separator: ", ")
                LiveActivityLogger.shared.error(
                    "MatchActivityAttributes decode failed: \(error). Keys present in payload: [\(keys)]"
                )
            } else {
                LiveActivityLogger.shared.error(
                    "MatchActivityAttributes decode failed and payload is not a keyed container: \(error)"
                )
            }
            throw error
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(liveNotificationId, forKey: .liveNotificationId)
        try c.encode(template, forKey: .template)
        try c.encode(content, forKey: .content)
        try c.encode(design, forKey: .design)
        // Wire format is an ordered array (one label per MatchPhase, in
        // `MatchPhase.allCases` order) — the compacted shape backend sends in
        // the APNs `attributes`. Encode in the same order so the ActivityKit
        // round-trip (encode → store → decode) stays consistent.
        let orderedLabels = MatchPhase.allCases.map { statusLabels[$0.rawValue] ?? "" }
        try c.encode(orderedLabels, forKey: .statusLabels)
        try c.encode(actionSet, forKey: .actionSet)
        try c.encode(timeout, forKey: .timeout)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encodeIfPresent(countdownDate, forKey: .countdownDate)
        try c.encodeIfPresent(countdownMessage, forKey: .countdownMessage)
    }
    
    /// Decode `actionSet` (or legacy `actions`) tolerantly. If the backend
    /// payload is malformed (e.g. missing `type` on some elements), log a
    /// detailed warning naming the offending key and return `[]` instead of
    /// failing the whole attributes decode. This trades CTA buttons for
    /// activity visibility — preferable while the backend payload is being
    /// fixed.
    /// Decode `statusLabels` from the compacted APNs wire shape: an ordered
    /// `[String]` where index `i` is the label for `MatchPhase.allCases[i]`.
    /// Empty strings are skipped so `label(for:)` keeps its `displayText`
    /// fallback. Returns `[:]` if the field is absent or not an array.
    private static func decodeStatusLabels(
        from container: KeyedDecodingContainer<CodingKeys>
    ) -> [String: String] {
        guard let labels = try? container.decodeIfPresent([String].self, forKey: .statusLabels) else {
            return [:]
        }
        let phases = MatchPhase.allCases
        var result: [String: String] = [:]
        for (index, label) in labels.enumerated() where index < phases.count && !label.isEmpty {
            result[phases[index].rawValue] = label
        }
        return result
    }

    private static func decodeActionSet(
        from container: KeyedDecodingContainer<CodingKeys>
    ) -> [PPGLiveActivityAction] {
        for key in [CodingKeys.actionSet, CodingKeys.actions] {
            guard container.contains(key) else { continue }
            do {
                return try container.decode([PPGLiveActivityAction].self, forKey: key)
            } catch {
                LiveActivityLogger.shared.warning(
                    """
                    Failed to decode `\(key.stringValue)` in APNs payload — falling back to empty action list. \
                    Activity will render without CTA buttons. Backend must include the `type` discriminator \
                    (\"URL\" / \"OPEN_APP\" / \"CLOSE\") on every element of `actionSet`. Underlying error: \(error)
                    """
                )
                return []
            }
        }
        return []
    }
    
    // View-facing computed properties.
    // Widget views read these instead of reaching into nested `content`.
    
    /// Alias for `liveNotificationId` — stable id of the match.
    public var matchId: String { liveNotificationId }
    
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
    
    /// Deep link opened when the user taps the Live Activity background
    /// (comes from `configuration.url` in the APNs attributes payload).
    public var deepLink: String? { url }
    
    /// First action of any type (URL, openApp, close) — used by views to render a CTA button.
    public var firstCTAAction: PPGLiveActivityAction? { actionSet.first }
    
    /// Convenience CTA text — name of first action (any type).
    public var ctaText: String? { firstCTAAction?.name }
    
    /// Convenience CTA deep link — first URL action's url, if any.
    public var ctaDeepLink: String? { firstUrlAction?.url }
    
    private var firstUrlAction: (name: String, url: String)? {
        actionSet.compactMap { action -> (String, String)? in
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
            liveNotificationId: dto.id,
            template: config.type,
            content: config.content,
            design: PPGFootballMatchDesign(ios: config.design.ios),
            statusLabels: config.statusLabels,
            actionSet: config.actions,
            timeout: config.timeout,
            url: config.url,
            countdownDate: dto.startPolicy.countdown != nil ? dto.startPolicy.scheduledAt : nil,
            countdownMessage: dto.startPolicy.countdown?.message
        )
        
        let state = ContentState(
            homeTeamScore: liveData.homeTeamScore,
            awayTeamScore: liveData.awayTeamScore,
            status: liveData.status,
            countdownDate: dto.startPolicy.countdown != nil ? dto.startPolicy.scheduledAt : nil,
            countdownMessage: dto.startPolicy.countdown?.message,
            statusChangedAt: liveData.statusChangedAt
        )
        
        return (attributes, state)
    }
}

/// Pass-through `CodingKey` that accepts any string. Used to dump the top
/// level keys present in a payload during decode-failure diagnostics.
@available(iOS 17.2, *)
private struct StartPolicyCodable: Codable {
    let scheduledAt: Date
    let countdown: PPGLiveActivityCountdown?
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

// PPGHotMessageCarrying conformance enables `LiveActivityManager` to schedule
// the deterministic auto-clear `Activity.update` after `durationSeconds`.
@available(iOS 17.2, *)
extension MatchActivityAttributes.ContentState: PPGHotMessageCarrying {
    public func clearingHotMessage() -> Self {
        Self(
            homeTeamScore: homeTeamScore,
            awayTeamScore: awayTeamScore,
            status: status,
            hotMessage: nil,
            countdownDate: countdownDate,
            countdownMessage: countdownMessage,
            statusChangedAt: statusChangedAt,
            liveDataVersion: liveDataVersion
        )
    }
}

// PPGLiveDataVersioned — lets the generic subscriber read the live-data
// revision off this ContentState when reporting statistics events.
@available(iOS 17.2, *)
extension MatchActivityAttributes.ContentState: PPGLiveDataVersioned {}

// PPGLiveActivityDesignCacheable

@available(iOS 17.2, *)
extension MatchActivityAttributes: PPGLiveActivityDesignCacheable {
    public var iosDesign: PPGFootballMatchIOSDesign { design.ios }
}

// PPGLiveActivityImagePrefetchable

@available(iOS 17.2, *)
extension MatchActivityAttributes: PPGLiveActivityImagePrefetchable {
    public var imageCampaignId: String { liveNotificationId }

    public var prefetchableImages: [PPGLiveActivityImageType: String] {
        var images: [PPGLiveActivityImageType: String] = [:]
        if let url = content.homeTeamImage, !url.isEmpty { images[.homeTeamBadge] = url }
        if let url = content.awayTeamImage, !url.isEmpty { images[.awayTeamBadge] = url }
        return images
    }
}
