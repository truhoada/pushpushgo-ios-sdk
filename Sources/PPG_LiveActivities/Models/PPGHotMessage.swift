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
/// The message is part of `ContentState` and is rendered by the widget
/// for `durationSeconds` after the first time the widget sees this `id`.
/// Visibility is enforced via two complementary mechanisms:
/// 1. `PPGHotMessageView` uses a SwiftUI `TimelineView` to drop the banner
///    at `receivedAt + durationSeconds`.
/// 2. `LiveActivityManager` schedules a follow-up `Activity.update` that
///    clears `hotMessage` at the same instant — this is the authoritative
///    path because Live Activity `TimelineView` updates can be deferred
///    when the window is below the system's render budget.
///    The auto-clear is cancelled if the host updates the activity
///    earlier (e.g. backend pushes a new state via ActivityKit).
@available(iOS 17.2, *)
public struct PPGHotMessage: Codable, Sendable, Hashable {
    /// Unique identifier. A change in `id` starts a new visibility window;
    /// the same `id` across renders keeps the existing window.
    public let id: String
    
    /// The message text rendered inside the Live Activity.
    public let text: String
    
    /// How long (in seconds) the message stays visible after the first
    /// render on the device. Typical values: 5-15 seconds.
    public let durationSeconds: Int
    
    public init(id: String, text: String, durationSeconds: Int) {
        self.id = id
        self.text = text
        self.durationSeconds = durationSeconds
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
