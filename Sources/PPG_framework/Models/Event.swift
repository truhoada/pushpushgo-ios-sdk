//
//  Event.swift
//  PPG_framework
//
//  Created by Adam Majczyk on 16/07/2020.
//  Copyright 2020 Goodylabs. All rights reserved.
//

import Foundation

// Protocol defining the method for sending events.
protocol EventSender {
    func send(event: Event, handler: @escaping (_ result: ActionResult) -> Void)
}

public class Event: Codable {

    public var eventType: EventType
    public var timestamp: String  // ISO8601 formatted timestamp
    public var button: Int?
    public var campaign: String
    public var sentAt: Date?

    enum CodingKeys: String, CodingKey {
        case eventType
        case timestamp
        case button
        case campaign
        case sentAt
    }

    // Custom ISO8601DateFormatter with options to handle fractional seconds and Zulu timezone.
    static let iso8601DateFormatter: ISO8601DateFormatter =
        {
            var options: ISO8601DateFormatter.Options = [
                .withInternetDateTime,
                .withColonSeparatorInTimeZone,
            ]
            if #available(iOS 11.0, *) {
                options.insert(.withFractionalSeconds)
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = options
            return formatter
        }()

    init(
        eventType: EventType = .delivered, button: Int? = nil,
        campaign: String = "", sender: EventSender? = DefaultEventSender()
    ) {
        self.eventType = eventType
        self.timestamp = Event.iso8601DateFormatter.string(from: Date())
        self.button = button
        self.campaign = campaign
        self.sentAt = nil
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventType = try container.decode(EventType.self, forKey: .eventType)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        button = try container.decodeIfPresent(Int.self, forKey: .button)
        campaign = try container.decode(String.self, forKey: .campaign)
        sentAt = try container.decodeIfPresent(Date.self, forKey: .sentAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(button, forKey: .button)
        try container.encode(campaign, forKey: .campaign)
        try container.encodeIfPresent(sentAt, forKey: .sentAt)
    }

    func getKey() -> String {
        return "\(eventType.rawValue)_\(button ?? 0)_\(campaign)"
    }

    func send(
        sender: EventSender, handler: @escaping (_ result: ActionResult) -> Void
    ) {
        print("Sending event: \(self.getKey()), wasSent: \(self.wasSent())")
        if self.wasSent() {
            print("Event was already sent. Returning error.")
            DispatchQueue.main.async {
                handler(.error("Event was sent before"))
            }
            return
        }
        sender.send(event: self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.sentAt = Date()
                    handler(result)
                case .error:
                    handler(result)
                }
            }
        }
    }

    func wasSent() -> Bool {
        return sentAt != nil
    }

    func canDelete() -> Bool {
        return wasSent() && isExpired()
    }

    func isExpired() -> Bool {
        guard let sentAt = self.sentAt else { return false }
        return Date().timeIntervalSince(sentAt) > 7 * 24 * 60 * 60  // 7 days
    }

    func debug() {
        print(getKey(), sentAt as Any, wasSent(), isExpired())
    }

    static func == (lhs: Event, rhs: Event) -> Bool {
        return lhs.button == rhs.button && lhs.campaign == rhs.campaign
            && lhs.eventType == rhs.eventType && lhs.timestamp == rhs.timestamp
    }

    func softEquals(_ other: Event) -> Bool {
        return button == other.button && campaign == other.campaign
            && eventType == other.eventType
    }
}

// Default implementation of EventSender using the production API service.
class DefaultEventSender: EventSender {
    func send(event: Event, handler: @escaping (_ result: ActionResult) -> Void)
    {
        ApiService.shared.sendEvent(event: event, handler: handler)
    }
}

class MockEventSender: EventSender {
    func send(event: Event, handler: @escaping (_ result: ActionResult) -> Void)
    {
        // Simulate asynchronous success after a short delay.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            handler(.success)
        }
    }
}
