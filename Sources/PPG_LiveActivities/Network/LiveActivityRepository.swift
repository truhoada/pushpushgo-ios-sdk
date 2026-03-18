//
//  LiveActivityRepository.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import Foundation

/// Repository for Live Activity API communication with PPG backend.
/// All network calls go through `performRequest` to avoid code duplication.
@available(iOS 16.2, *)
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
    
    /// Register an ActivityKit push token with the PPG backend.
    func registerPushToken(
        activityId: String,
        templateId: String,
        pushToken: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let body = RegisterPushTokenRequest(
            activityId: activityId,
            templateId: templateId,
            pushToken: pushToken,
            subscriberId: PushSDKBridge.subscriberId
        )
        performRequest(path: "live-activity/register", body: body, completion: completion)
    }
    
    /// Track a Live Activity event.
    func trackEvent(
        eventType: LiveActivityEventType,
        activityId: String,
        templateId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let body = LiveActivityEventRequest(
            type: eventType.rawValue,
            payload: LiveActivityEventPayload(
                activityId: activityId,
                templateId: templateId,
                timestamp: ISO8601DateFormatter().string(from: Date()),
                subscriberId: PushSDKBridge.subscriberId
            )
        )
        performRequest(path: "live-activity/event", body: body, completion: completion)
    }
    
    // Shared HTTP logic (DRY)
    
    private func performRequest<T: Encodable>(
        path: String,
        body: T,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let encoded = try? JSONEncoder().encode(body) else {
            completion(.failure(LiveActivityError.encodingFailed))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/v1/ios/\(projectId)/\(path)") else {
            completion(.failure(LiveActivityError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Token")
        request.httpBody = encoded
        
        session.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(LiveActivityError.serverError(code)))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
}
