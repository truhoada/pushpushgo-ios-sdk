//
//  LiveActivityError.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import Foundation

/// Errors that can occur during Live Activity operations
@available(iOS 17.2, *)
internal enum LiveActivityError: LocalizedError {
    case encodingFailed
    case invalidURL
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode request body"
        case .invalidURL:
            return "Invalid API URL"
        case .serverError(let code):
            return "Server error: HTTP \(code)"
        }
    }
}
