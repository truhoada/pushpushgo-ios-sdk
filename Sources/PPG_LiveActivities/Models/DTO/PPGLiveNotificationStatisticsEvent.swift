//
//  PPGLiveNotificationStatisticsEvent.swift
//  PPG_LiveActivities
//
//  DTOs for the Live Notification statistics events flow:
//  POST /v1/ios/projects/{project}/live-notifications/{id}/events
//
//  Mirrors backend `CollectLiveNotificationStatisticsRequestDTO` /
//  `LiveNotificationStatisticsEventRequestDTO`.
//

import Foundation

/// Type of a Live Notification statistics event reported to the backend.
/// Raw values match `LiveNotificationStatisticsCommandEventType` on the wire.
@available(iOS 17.2, *)
public enum PPGLiveNotificationStatisticsEventType: String, Codable, Sendable {
    /// The Live Activity appeared on the device (push-to-start or local start).
    case started = "started"
    /// The Live Activity ended / was dismissed.
    case closed = "closed"
    /// The user tapped the Live Activity body.
    case clicked = "clicked"
    /// The user tapped the first action button.
    case clicked1 = "clicked_1"
    /// The user tapped the second action button.
    case clicked2 = "clicked_2"
}

/// A single statistics event. `occurredAt` is an ISO-8601 timestamp string;
/// `liveDataVersion` is the `liveDataVersion` carried in the Live Activity
/// `ContentState` at the moment the event happened.
@available(iOS 17.2, *)
internal struct PPGLiveNotificationStatisticsEvent: Codable, Sendable {
    let type: PPGLiveNotificationStatisticsEventType
    let occurredAt: String
    let liveDataVersion: Int

    init(type: PPGLiveNotificationStatisticsEventType, liveDataVersion: Int, occurredAt: Date = Date()) {
        self.type = type
        self.liveDataVersion = liveDataVersion
        self.occurredAt = Self.formatter.string(from: occurredAt)
    }

    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

/// Body for `POST /v1/ios/projects/{project}/live-notifications/{id}/events`.
/// `project` and `liveNotification` travel in the path; auth is the `X-Token`
/// header — so the body only carries the subscriber identity + events.
@available(iOS 17.2, *)
internal struct PPGCollectLiveNotificationStatisticsRequest: Codable, Sendable {
    let installationId: String
    let subscriberId: String
    let events: [PPGLiveNotificationStatisticsEvent]
}

/// Implemented by `ContentState` types that carry a backend `liveDataVersion`.
/// Lets the (generic) subscriber read the version off an arbitrary
/// `ActivityAttributes.ContentState` without binding to a concrete template.
@available(iOS 17.2, *)
public protocol PPGLiveDataVersioned {
    var liveDataVersion: Int { get }
}
