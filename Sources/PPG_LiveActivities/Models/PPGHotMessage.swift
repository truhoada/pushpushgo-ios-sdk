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
/// Visibility is enforced locally via SwiftUI `TimelineView` — the system
/// automatically re-renders at `receivedAt + durationSeconds` and the
/// message disappears deterministically without requiring a second push.
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
