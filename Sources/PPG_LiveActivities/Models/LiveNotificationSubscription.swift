//
//  LiveNotificationSubscription.swift
//  PPG_LiveActivities
//
//  DTOs and status types for the per-notification subscriber flow:
//  POST   /core/projects/{project}/live-notifications/{id}/subscribers
//  PUT    /core/projects/{project}/live-notifications/{id}/subscribers/{installationId}/endpoint
//  DELETE /core/projects/{project}/live-notifications/{id}/subscribers/{installationId}
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Lifecycle status emitted by the per-notification subscriber to inform
/// callers of `LiveActivitiesSDK.subscribe(...)` about state changes.
@available(iOS 17.2, *)
public enum LiveNotificationSubscriptionStatus: Sendable {
    /// Subscriber registered with PPG backend (POST /subscribers OK).
    /// The notification has not necessarily started yet — backend may push
    /// the `event:start` later.
    case registered
    
    /// Backend pushed `event:start` and ActivityKit created a Live Activity
    /// on this device. `activityId` is the local ActivityKit identifier.
    case activityStarted(activityId: String)
    
    /// Activity-specific update token (`activity.pushTokenUpdates`) was sent
    /// to the backend so subsequent `event:update` pushes can target this
    /// device.
    case updateTokenSent(activityId: String)
    
    /// Local Live Activity ended (either via `event:end` push or manually).
    case activityEnded(activityId: String)
    
    /// Unsubscribed from the notification (DELETE /subscribers/{id} OK).
    case unsubscribed
    
    /// An error occurred during subscription / token forwarding.
    case error(LiveNotificationSubscriptionError)
}

/// Errors specific to the subscriber flow.
@available(iOS 17.2, *)
public enum LiveNotificationSubscriptionError: Error, Sendable {
    /// Live Activities are not enabled on this device.
    case activitiesNotEnabled
    /// POST /subscribers failed.
    case registrationFailed(underlying: Error)
    /// PUT /subscribers/{id}/endpoint failed.
    case endpointUpdateFailed(underlying: Error)
    /// DELETE /subscribers/{id} failed.
    case unregistrationFailed(underlying: Error)
}

// Wire DTOs

/// Subscriber endpoint — `transport` + push tokens. iOS uses `APNS` and
/// supplies one or both tokens (push-to-start + activity update).
@available(iOS 17.2, *)
internal struct PPGLiveNotificationSubscriberEndpoint: Codable, Sendable {
    let transport: String
    let remoteStartToken: String
    let updateToken: String?
    
    init(remoteStartToken: String, updateToken: String? = nil) {
        self.transport = "APNS"
        self.remoteStartToken = remoteStartToken
        self.updateToken = updateToken
    }
}

/// Static metadata included in subscriber requests for backend analytics.
@available(iOS 17.2, *)
internal struct PPGLiveNotificationInstallationMetadata: Codable, Sendable {
    let sdkVersion: String
    let osVersion: String
    
    static let current: PPGLiveNotificationInstallationMetadata = {
        #if canImport(UIKit)
        let os = UIDevice.current.systemVersion
        #else
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        #endif
        return PPGLiveNotificationInstallationMetadata(
            sdkVersion: PPGLiveActivitiesVersion.current,
            osVersion: os
        )
    }()
}

/// Body for `POST /live-notifications/{id}/subscribers`.
@available(iOS 17.2, *)
internal struct PPGSubscribeLiveNotificationRequest: Codable, Sendable {
    let installationId: String
    let installationMetadata: PPGLiveNotificationInstallationMetadata
    let endpoint: PPGLiveNotificationSubscriberEndpoint
}

/// Response from `POST /live-notifications/{id}/subscribers`. The returned
/// `id` is the backend-side subscriber identifier (mongodb ObjectId) and
/// MUST be used as the `{subscriberId}` path component in subsequent
/// `PUT /endpoint` and `DELETE` calls
@available(iOS 17.2, *)
internal struct PPGSubscribeLiveNotificationResponse: Decodable, Sendable {
    let id: String
}

/// Body for `PUT /live-notifications/{id}/subscribers/{subscriberId}/endpoint`.
@available(iOS 17.2, *)
internal struct PPGUpdateLiveNotificationEndpointRequest: Codable, Sendable {
    let installationMetadata: PPGLiveNotificationInstallationMetadata
    let endpoint: PPGLiveNotificationSubscriberEndpoint
}

/// SDK version string used in request `installationMetadata.sdkVersion`.
/// Update on every release tag.
@available(iOS 17.2, *)
internal enum PPGLiveActivitiesVersion {
    static let current = "0.1.0"
}
