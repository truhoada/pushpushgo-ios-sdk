//
//  LiveActivityLogger.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import Foundation

/// Logger for the Live Activities SDK with debug/release mode support
@available(iOS 16.2, *)
internal class LiveActivityLogger {
    
    static let shared = LiveActivityLogger()
    
    private let tag = "PPG_LiveActivities"
    private var isDebugEnabled = false
    
    private init() {}
    
    /// Enable or disable debug logging
    func setDebugEnabled(_ enabled: Bool) {
        isDebugEnabled = enabled
    }
    
    /// Log debug messages (only in debug mode)
    func debug(_ message: String) {
        guard isDebugEnabled else { return }
        print("[\(tag)] 🔍 \(message)")
    }
    
    /// Log info messages (always visible)
    func info(_ message: String) {
        print("[\(tag)] ℹ️ \(message)")
    }
    
    /// Log warning messages (always visible)
    func warning(_ message: String) {
        print("[\(tag)] ⚠️ \(message)")
    }
    
    /// Log error messages (always visible)
    func error(_ message: String) {
        print("[\(tag)] ❌ \(message)")
    }
}
