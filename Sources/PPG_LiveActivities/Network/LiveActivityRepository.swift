//
//  LiveActivityRepository.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import Foundation

/// Repository for Live Activity API communication with PPG backend.
@available(iOS 17.2, *)
internal class LiveActivityRepository {
    
    private let apiKey: String
    private let projectId: String
    private let baseURL: String
    private let session: URLSession
    
    init(apiKey: String, projectId: String, isProduction: Bool = true) {
        self.apiKey = apiKey
        self.projectId = projectId
        self.baseURL = isProduction ? "https://api.pushpushgo.com" : "https://api.master1.qappg.co"
        self.session = URLSession.shared
    }
    
    // Live Notification Subscribers
    
    /// `POST /core/projects/{project}/live-notifications/{id}/subscribers`
    /// Idempotent on `installationId` (request body) — calling again with
    /// the same id updates the stored `endpoint` instead of creating a
    /// duplicate. Returns the backend-assigned `subscriberId` (mongodb
    /// ObjectId) which MUST be used as the path component for any
    /// subsequent `PUT /endpoint` / `DELETE` — see
    /// `PPGSubscribeLiveNotificationResponse`.
    func subscribe(
        liveNotificationId: String,
        installationId: String,
        remoteStartToken: String,
        updateToken: String?
    ) async throws -> String {
        let body = PPGSubscribeLiveNotificationRequest(
            installationId: installationId,
            installationMetadata: .current,
            endpoint: PPGLiveNotificationSubscriberEndpoint(
                remoteStartToken: remoteStartToken,
                updateToken: updateToken
            )
        )
        let response: PPGSubscribeLiveNotificationResponse = try await performLiveNotificationRequest(
            method: "POST",
            path: "live-notifications/\(liveNotificationId)/subscribers",
            body: body
        )
        return response.id
    }
    
    /// `PUT /core/projects/{project}/live-notifications/{id}/subscribers/{subscriberId}/endpoint`
    /// Refreshes the stored push tokens for an existing subscriber. Used
    /// when ActivityKit rotates the `updateToken` mid-activity.
    /// `subscriberId` is the value returned by `subscribe(...)`.
    func updateSubscriberEndpoint(
        liveNotificationId: String,
        subscriberId: String,
        remoteStartToken: String,
        updateToken: String?
    ) async throws {
        let body = PPGUpdateLiveNotificationEndpointRequest(
            installationMetadata: .current,
            endpoint: PPGLiveNotificationSubscriberEndpoint(
                remoteStartToken: remoteStartToken,
                updateToken: updateToken
            )
        )
        try await performLiveNotificationRequest(
            method: "PUT",
            path: "live-notifications/\(liveNotificationId)/subscribers/\(subscriberId)/endpoint",
            body: body
        )
    }
    
    /// `GET /core/projects/{project}/live-notifications/{id}`
    /// Returns the raw JSON body for the campaign so the SDK can bootstrap
    /// a locally-started Live Activity when the campaign is already ONGOING.
    func fetchCampaign(liveNotificationId: String) async throws -> Data {
        return try await performLiveNotificationRequestRaw(
            method: "GET",
            path: "live-notifications/\(liveNotificationId)",
            body: Optional<EmptyBody>.none
        )
    }
    
    /// `DELETE /core/projects/{project}/live-notifications/{id}/subscribers/{subscriberId}`
    func unsubscribe(
        liveNotificationId: String,
        subscriberId: String
    ) async throws {
        try await performLiveNotificationRequest(
            method: "DELETE",
            path: "live-notifications/\(liveNotificationId)/subscribers/\(subscriberId)",
            body: Optional<EmptyBody>.none
        )
    }
    
    // Shared HTTP logic
    
    /// Marker type for empty request bodies.
    private struct EmptyBody: Encodable {}
    
    /// Build a request hitting `/core/projects/{projectId}/{path}` (the
    /// public Live Notifications API). Body is optional — pass `nil` for
    /// methods like DELETE that have no payload.
    private func buildLiveNotificationRequest<T: Encodable>(
        method: String,
        path: String,
        body: T?
    ) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/core/projects/\(projectId)/\(path)") else {
            throw LiveActivityError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Token")
        
        if let body = body {
            guard let encoded = try? JSONEncoder().encode(body) else {
                throw LiveActivityError.encodingFailed
            }
            request.httpBody = encoded
        }
        
        return request
    }
    
    /// Fire a Live Notifications API request and validate HTTP status.
    /// Doesn't decode the body — for endpoints that return empty payloads.
    private func performLiveNotificationRequest<T: Encodable>(
        method: String,
        path: String,
        body: T?
    ) async throws {
        _ = try await performLiveNotificationRequestRaw(method: method, path: path, body: body)
    }
    
    /// Variant that decodes the response body as `R`. Use for endpoints
    /// that return a payload (currently `POST /subscribers` returning
    /// `{ "id": "..." }`).
    private func performLiveNotificationRequest<T: Encodable, R: Decodable>(
        method: String,
        path: String,
        body: T?
    ) async throws -> R {
        let data = try await performLiveNotificationRequestRaw(method: method, path: path, body: body)
        do {
            return try JSONDecoder().decode(R.self, from: data)
        } catch {
            throw LiveActivityError.serverError(
                code: -1,
                body: "Failed to decode response as \(R.self): \(error). Raw body: \(String(data: data, encoding: .utf8) ?? "<binary>")"
            )
        }
    }
    
    private func performLiveNotificationRequestRaw<T: Encodable>(
        method: String,
        path: String,
        body: T?
    ) async throws -> Data {
        let request = try buildLiveNotificationRequest(method: method, path: path, body: body)
        if let bodyData = request.httpBody,
           let bodyString = String(data: bodyData, encoding: .utf8) {
            LiveActivityLogger.shared.debug(
                "→ \(method) \(request.url?.path ?? "") body: \(bodyString)"
            )
        }
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
            LiveActivityLogger.shared.debug(
                "← HTTP \(statusCode) body: \(responseString)"
            )
        }
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw LiveActivityError.serverError(code: statusCode, body: body)
        }
        return data
    }
    
}
