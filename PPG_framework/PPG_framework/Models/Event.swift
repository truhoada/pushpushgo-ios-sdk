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
    
    init() {
        let formatter = ISO8601DateFormatter()
        
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
    
    func send(handler:@escaping (_ result: ActionResult) -> Void) {
        ApiService.shared.sendEvent(event: self) { result in
            handler(result)
        }
    }
}
