//
//  Event.swift
//  PPG_framework
//
//  Created by Adam Majczyk on 16/07/2020.
//  Copyright © 2020 Goodylabs. All rights reserved.
//

import Foundation

class Event: Codable {
    var eventType: EventType
    var timestamp: String //ISO8601 formatted timestamp
    var button: Int?
    var campaign: String
    var sentAt: Date?
    
    init() {
        let formatter = ISO8601DateFormatter()
        
        sentAt = nil
        eventType = .delivered
        timestamp = formatter.string(from: Date())
        button = nil
        campaign = ""
    }
    
    init(eventType: EventType, button: Int?, campaign: String) {
        let formatter = ISO8601DateFormatter()
        
        self.eventType = eventType
        timestamp = formatter.string(from: Date())
        self.button = button
        self.campaign = campaign
    }
    
    init(eventType: EventType, button: Int?, campaign: String, timestamp: String) {
        self.eventType = eventType
        self.timestamp = timestamp
        self.button = button
        self.campaign = campaign
    }
    
    static func ==(lhs: Event, rhs: Event) -> Bool {
        return lhs.button == rhs.button &&
        lhs.campaign == rhs.campaign &&
        lhs.eventType == rhs.eventType &&
        lhs.timestamp == rhs.timestamp
    }
    
    static func !=(lhs: Event, rhs: Event) -> Bool {
        return lhs.button != rhs.button ||
        lhs.campaign != rhs.campaign ||
        lhs.eventType != rhs.eventType ||
        lhs.timestamp != rhs.timestamp
    }
    
    func softEquals(_ other: Event) -> Bool {
        return button == other.button &&
        campaign == other.campaign &&
        eventType == other.eventType
    }
    
    func send(handler:@escaping (_ result: ActionResult) -> Void) {
        if (self.wasSent()) {
            return handler(.error("Event was sent before"))
        }
        ApiService.shared.sendEvent(event: self) { result in
            switch result {
            case .success:
                self.sentAt = Date()
                break
            case .error: break
            }
            handler(result)
        }
    }
    
    func getKey() -> String {
        return "\(eventType.rawValue)_\(button ?? 0)_\(campaign)"
    }
    
    func wasSent() -> Bool {
        return sentAt != nil
    }
    
    func canDelete() -> Bool {
        return wasSent() && isExpired()
    }
    func isExpired() -> Bool {
        if (sentAt == nil) {
            return false
        }
        return Date().timeIntervalSince(sentAt!) > 7 * 24 * 60 * 60
    }
}
