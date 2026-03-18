//
//  LiveActivityRepository.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import Foundation

/// Repository for Live Activity API communication with PPG backend
@available(iOS 16.2, *)
internal class LiveActivityRepository {
    
    // Properties
    
    private let apiKey: String
    private let projectId: String
    private let isProduction: Bool
    private let session: URLSession
    
    private var baseURL: String {
        return isProduction ? "https://api.pushpushgo.com" : "https://api.master1.qappg.co"
    }
    
    // Subscriber ID bridge — reads from PPG_framework's UserDefaults without direct dependency
    private var subscriberId: String? {
        let id = UserDefaults.standard.string(forKey: "PPGSubscriberId") ?? ""
        return id.isEmpty ? nil : id
    }
    
    // Initialization
    
    init(apiKey: String, projectId: String, isProduction: Bool = true) {
        self.apiKey = apiKey
        self.projectId = projectId
        self.isProduction = isProduction
        self.session = URLSession.shared
    }
    
    // Push Token Registration
    
    /// Register an ActivityKit push token with the PPG backend
    /// This allows the backend to send push-to-update payloads to the Live Activity
    func registerPushToken(
        activityId: String,
        templateId: String,
        pushToken: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let requestBody = RegisterPushTokenRequest(
            activityId: activityId,
            templateId: templateId,
            pushToken: pushToken,
            subscriberId: subscriberId
        )
        
        guard let encoded = try? JSONEncoder().encode(requestBody) else {
            completion(.failure(LiveActivityError.encodingFailed))
            return
        }
        
        let endpoint = "\(baseURL)/v1/ios/\(projectId)/live-activity/register"
        guard let url = URL(string: endpoint) else {
            completion(.failure(LiveActivityError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Token")
        request.httpBody = encoded
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(LiveActivityError.serverError(
                    (response as? HTTPURLResponse)?.statusCode ?? -1
                )))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
    
    // Event Tracking
    
    /// Track a Live Activity event (started, updated, clicked, ended, dismissed)
    func trackEvent(
        eventType: LiveActivityEventType,
        activityId: String,
        templateId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        let requestBody = LiveActivityEventRequest(
            type: eventType.rawValue,
            payload: LiveActivityEventPayload(
                activityId: activityId,
                templateId: templateId,
                timestamp: timestamp,
                subscriberId: subscriberId
            )
        )
        
        guard let encoded = try? JSONEncoder().encode(requestBody) else {
            completion(.failure(LiveActivityError.encodingFailed))
            return
        }
        
        let endpoint = "\(baseURL)/v1/ios/\(projectId)/live-activity/event"
        guard let url = URL(string: endpoint) else {
            completion(.failure(LiveActivityError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Token")
        request.httpBody = encoded
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
}

// Error Types

@available(iOS 16.2, *)
internal enum LiveActivityError: LocalizedError {
    case encodingFailed
    case invalidURL
    case serverError(Int)
    case activityNotFound
    case activitiesNotEnabled
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode request body"
        case .invalidURL:
            return "Invalid API URL"
        case .serverError(let code):
            return "Server error: HTTP \(code)"
        case .activityNotFound:
            return "Activity not found"
        case .activitiesNotEnabled:
            return "Live Activities are not enabled on this device"
        }
    }
}
