//
//  PPGLiveNotificationDTO.swift
//  PPG_LiveActivities
//
//  Top-level Live Notification DTO — union of all supported templates.
//

import Foundation

/// Template-specific configuration union.
@available(iOS 17.2, *)
public enum PPGLiveNotificationConfiguration: Codable, Sendable, Hashable {
    case footballMatchTracking(PPGFootballMatchConfiguration)
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(PPGLiveActivityTemplate.self, forKey: .type)
        switch type {
        case .footballMatchTracking:
            self = .footballMatchTracking(try PPGFootballMatchConfiguration(from: decoder))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .footballMatchTracking(let config):
            try config.encode(to: encoder)
        }
    }
}

/// Template-specific live data union.
@available(iOS 17.2, *)
public enum PPGLiveNotificationLiveData: Codable, Sendable, Hashable {
    case footballMatchTracking(PPGFootballMatchLiveData)
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(PPGLiveActivityTemplate.self, forKey: .type)
        switch type {
        case .footballMatchTracking:
            self = .footballMatchTracking(try PPGFootballMatchLiveData(from: decoder))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .footballMatchTracking(let data):
            try data.encode(to: encoder)
        }
    }
}

/// Metadata describing who created the notification.
@available(iOS 17.2, *)
public struct PPGLiveNotificationMetadata: Codable, Sendable, Hashable {
    public let createdBy: String
    
    public init(createdBy: String) {
        self.createdBy = createdBy
    }
}

/// Current lifecycle info (wraps `status` to match backend `lifecycle.status` shape).
@available(iOS 17.2, *)
public struct PPGLiveNotificationLifecycle: Codable, Sendable, Hashable {
    public let status: PPGLiveActivityLifecycleStatus
    
    public init(status: PPGLiveActivityLifecycleStatus) {
        self.status = status
    }
}

/// Full Live Notification envelope as sent by the PPG backend.
@available(iOS 17.2, *)
public struct PPGLiveNotificationDTO: Codable, Sendable, Hashable {
    public let id: String
    public let projectId: String
    public let template: PPGLiveActivityTemplate
    public let name: String
    public let configuration: PPGLiveNotificationConfiguration
    public let liveData: PPGLiveNotificationLiveData
    public let lifecycle: PPGLiveNotificationLifecycle
    public let startPolicy: PPGLiveActivityStartPolicy
    public let metadata: PPGLiveNotificationMetadata
    public let createdAt: Date
    public let updatedAt: Date
    public let deletedAt: Date?
    
    public init(
        id: String,
        projectId: String,
        template: PPGLiveActivityTemplate,
        name: String,
        configuration: PPGLiveNotificationConfiguration,
        liveData: PPGLiveNotificationLiveData,
        lifecycle: PPGLiveNotificationLifecycle,
        startPolicy: PPGLiveActivityStartPolicy,
        metadata: PPGLiveNotificationMetadata,
        createdAt: Date,
        updatedAt: Date,
        deletedAt: Date?
    ) {
        self.id = id
        self.projectId = projectId
        self.template = template
        self.name = name
        self.configuration = configuration
        self.liveData = liveData
        self.lifecycle = lifecycle
        self.startPolicy = startPolicy
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
    
    // Convenience accessors
    
    /// Returns the football match configuration if this DTO is a football match template.
    public var footballMatchConfiguration: PPGFootballMatchConfiguration? {
        if case .footballMatchTracking(let c) = configuration { return c }
        return nil
    }
    
    /// Returns the football match live data if this DTO is a football match template.
    public var footballMatchLiveData: PPGFootballMatchLiveData? {
        if case .footballMatchTracking(let d) = liveData { return d }
        return nil
    }
}
