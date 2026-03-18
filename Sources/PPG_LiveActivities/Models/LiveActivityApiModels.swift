//
//  LiveActivityApiModels.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import Foundation

// Request Models

/// Request body for registering an ActivityKit push token with the PPG backend
@available(iOS 16.2, *)
struct RegisterPushTokenRequest: Codable {
    let activityId: String
    let templateId: String
    let pushToken: String
    let subscriberId: String?
}

/// Request body for tracking Live Activity events
@available(iOS 16.2, *)
struct LiveActivityEventRequest: Codable {
    let type: String
    let payload: LiveActivityEventPayload
}

/// Event payload with activity details
@available(iOS 16.2, *)
struct LiveActivityEventPayload: Codable {
    let activityId: String
    let templateId: String
    let timestamp: String
    let subscriberId: String?
}

/// Request body for updating activity state on the backend
@available(iOS 16.2, *)
struct UpdateActivityStateRequest: Codable {
    let activityId: String
    let state: [String: AnyCodableValue]
}

// Response Models

/// Response from push token registration
@available(iOS 16.2, *)
struct RegisterPushTokenResponse: Codable {
    let success: Bool
    let error: String?
}

/// Response from event tracking
@available(iOS 16.2, *)
struct LiveActivityEventResponse: Codable {
    let success: Bool
    let error: String?
}

// AnyCodableValue

/// A type-erased Codable value for dictionary serialization
@available(iOS 16.2, *)
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported value type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
    
    /// Create from Any value (used for dictionary -> Codable conversion)
    static func from(_ value: Any) -> AnyCodableValue {
        switch value {
        case let v as String: return .string(v)
        case let v as Int: return .int(v)
        case let v as Double: return .double(v)
        case let v as Bool: return .bool(v)
        default: return .null
        }
    }
}
