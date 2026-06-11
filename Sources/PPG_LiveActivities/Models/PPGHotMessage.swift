//
//  PPGHotMessage.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 29/04/2026.
//

import Foundation

/// Transient, time-bounded message shown on top of a Live Activity
/// (e.g. "Goal cancelled after VAR", "Yellow card for #10").
///
/// The message is part of `ContentState`. Visibility is the **minimum**
/// of two cutoffs:
/// 1. `receivedAt + maxDisplayDuration` — SDK-controlled local cap, ensures
///    the banner never overstays the design intent (10 s).
/// 2. `expiresAt` — backend-controlled hard cutoff. After this instant the
///    message is considered stale and must not be shown, even if it was
///    just received.
///
/// Visibility is enforced via two complementary mechanisms:
/// - `PPGHotMessageView` uses a SwiftUI `TimelineView` to drop the banner
///   at the computed end instant.
/// - `LiveActivityManager` schedules a follow-up `Activity.update` that
///   clears `hotMessage` at the same instant — this is the authoritative
///   path because Live Activity `TimelineView` updates can be deferred
///   when the window is below the system's render budget. The auto-clear
///   is cancelled if the host updates the activity earlier (e.g. backend
///   pushes a new state via ActivityKit).
@available(iOS 17.2, *)
public struct PPGHotMessage: Sendable, Hashable {
    
    /// SDK-controlled maximum local display duration (seconds).
    /// Hot message should be visible for up to 10 s on iOS regardless
    /// of `expiresAt`.
    public static let maxDisplayDuration: TimeInterval = 10
    
    /// Unique identifier. A change in `id` starts a new visibility window;
    /// the same `id` across renders keeps the existing window.
    public let id: String
    
    /// The message text rendered inside the Live Activity.
    public let text: String
    
    /// Hard cutoff sent by the backend (Unix epoch seconds → `Date`).
    /// The message must not be displayed after this instant, even if it
    /// was just received.
    public let expiresAt: Date
    
    public init(id: String, text: String, expiresAt: Date) {
        self.id = id
        self.text = text
        self.expiresAt = expiresAt
    }
    
    /// Effective end-of-visibility for this message, given the instant the
    /// device first saw it. Always the earlier of:
    /// - `receivedAt + maxDisplayDuration`
    /// - `expiresAt`
    public func endDate(receivedAt: Date) -> Date {
        let localCap = receivedAt.addingTimeInterval(Self.maxDisplayDuration)
        return min(localCap, expiresAt)
    }
}

// Codable — backend wire format is `{id, text, timestamp}` where
// `timestamp` is Unix epoch seconds.
// Both `id` and `timestamp` are treated as optional for forward-compat:
// - missing `id`        → stable UUID derived from `text` (same message = same id)
// - missing `timestamp` → now + maxDisplayDuration (message visible for one local window)
@available(iOS 17.2, *)
extension PPGHotMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, text, timestamp
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
        id = try c.decodeIfPresent(String.self, forKey: .id)
            ?? UUID().uuidString
        if let epoch = try c.decodeIfPresent(Double.self, forKey: .timestamp) {
            let seconds = epoch > 1_000_000_000_000 ? epoch / 1000 : epoch
            expiresAt = Date(timeIntervalSince1970: seconds)
        } else {
            expiresAt = Date().addingTimeInterval(Self.maxDisplayDuration)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(text, forKey: .text)
        try c.encode(expiresAt.timeIntervalSince1970, forKey: .timestamp)
    }
}

/// `ContentState` types that include a `PPGHotMessage` should conform to
/// this protocol so that `LiveActivityManager` can schedule the automatic
/// follow-up update that clears the message after `durationSeconds`.
///
/// `clearingHotMessage()` must return a copy of `Self` with `hotMessage`
/// set to `nil`; all other fields should be preserved as-is.
@available(iOS 17.2, *)
public protocol PPGHotMessageCarrying {
    var hotMessage: PPGHotMessage? { get }
    func clearingHotMessage() -> Self
}
