//
//  LiveActivityLogger.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import Foundation
import os

/// Logger for the Live Activities SDK with debug mode support.
///
/// Uses `os.Logger` with subsystem `co.pushpushgo.PPG_LiveActivities` so that
/// log lines from both the app process and the widget extension process are
/// captured by `OSLog` and can be inspected in Console.app with filter
/// `subsystem:co.pushpushgo.PPG_LiveActivities`. We also emit `print` lines
/// so that Xcode's debug console keeps showing them.
@available(iOS 17.2, *)
internal class LiveActivityLogger {
    
    static let shared = LiveActivityLogger()
    
    static let subsystem = "co.pushpushgo.PPG_LiveActivities"
    private let tag = "PPG_LiveActivities"
    private let osLog = Logger(subsystem: subsystem, category: "LiveActivities")
    private var isDebugEnabled = false
    
    private init() {}
    
    /// Enable or disable debug logging
    func setDebugEnabled(_ enabled: Bool) {
        isDebugEnabled = enabled
    }
    
    /// Log debug messages
    func debug(_ message: String) {
        guard isDebugEnabled else { return }
        osLog.debug("\(message, privacy: .public)")
        print("[\(tag)] 🔍 \(message)")
    }
    
    /// Log info messages
    func info(_ message: String) {
        osLog.info("\(message, privacy: .public)")
        print("[\(tag)] ℹ️ \(message)")
    }
    
    /// Log warning messages
    func warning(_ message: String) {
        osLog.warning("\(message, privacy: .public)")
        print("[\(tag)] ⚠️ \(message)")
    }
    
    /// Log error messages
    func error(_ message: String) {
        osLog.error("\(message, privacy: .public)")
        print("[\(tag)] ❌ \(message)")
    }
}
