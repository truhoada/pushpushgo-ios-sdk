//
//  ApiModels.swift
//  PPG_framework
//
//  Created by Adam Majczyk on 16/07/2020.
//  Copyright © 2020 Goodylabs. All rights reserved.
//

import Foundation

struct PPGApiError: Codable {
    let messages: [String]
}

struct SubscribeUserResponse: Codable {
    let _id: String
}

struct EventBody: Codable {
    let type: String
    let payload: EventBodyPayload
}

struct EventBodyPayload: Codable {
    let timestamp: String
    let button: Int?
    let campaign: String
    let subscriber: String
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.timestamp, forKey: .timestamp)
        try container.encodeIfPresent(self.button, forKey: .button)
        try container.encode(self.campaign, forKey: .campaign)
        try container.encode(self.subscriber, forKey: .subscriber)
    }
}

struct BeaconBody: Codable {
    var selectors: [BeaconSelector] = []
    var tags: [BeaconTag] = []
    var tagsToDelete: [BeaconTag] = []
    var customId: String = ""
    
    init(beacon: Beacon) {
        self.selectors = beacon.selectors
        self.tags = beacon.tags
        self.tagsToDelete = beacon.tagsToDelete
        self.customId = beacon.customId
    }
    
    private struct CodingKeys: CodingKey {
        var intValue: Int?
        var stringValue: String

        init?(intValue: Int) { self.intValue = intValue; self.stringValue = "\(intValue)" }
        init?(stringValue: String) { self.stringValue = stringValue }

        static let tags = CodingKeys.make(key: "tags")
        static let tagsToDelete = CodingKeys.make(key: "tagsToDelete")
        static let customId = CodingKeys.make(key: "customId")
        
        static func make(key: String) -> CodingKeys {
            return CodingKeys(stringValue: key)!
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        for s in selectors {
            switch s.selectorValue.type {
            case .string:
                try container.encode(s.selectorValue.stringValue,
                                     forKey: .make(key: s.selectorName))
            case .number:
                try container.encode(s.selectorValue.numberValue,
                                     forKey: .make(key: s.selectorName))
            case .date:
                try container.encode(s.selectorValue.dateValue,
                                     forKey: .make(key: s.selectorName))
            case .bool:
                try container.encode(s.selectorValue.boolValue,
                                     forKey: .make(key: s.selectorName))

            }

        }
        try container.encode(self.tags, forKey: .tags)
        try container.encode(self.tagsToDelete, forKey: .tagsToDelete)
        try container.encode(self.customId, forKey: .customId)
    }
    
    init(from coder: Decoder) throws {
        
    }
}
