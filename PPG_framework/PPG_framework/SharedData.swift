//
//  SharedData.swift
//  PPG_framework
//
//  Created by Adam Majczyk on 14/07/2020.
//  Copyright © 2020 Goodylabs. All rights reserved.
//

import Foundation
import UserNotifications

public class SharedData {

    static var shared = SharedData()
    public var appGroupId: String = ""
    var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupId)
    }

    var projectId: String {
        get {
            return sharedDefaults?.string(forKey: "PPGProjectId") ?? ""
        }
        set {
            sharedDefaults?.set(newValue, forKey: "PPGProjectId")
        }
    }

    var apiToken: String {
        get {
            return sharedDefaults?.string(forKey: "PPGAPIToken") ?? ""
        }
        set {
            sharedDefaults?.set(newValue, forKey: "PPGAPIToken")
        }
    }

    var subscriberId: String {
        get {
            return sharedDefaults?.string(forKey: "PPGSubscriberId")
                // Legacy supported value
                ?? UserDefaults.standard.string(forKey: "PPGSubscriberId") ?? ""
        }
        set {
            sharedDefaults?.set(newValue, forKey: "PPGSubscriberId")
        }
    }

    var deviceToken: String {
        get {
            return sharedDefaults?.string(forKey: "PPGDeviceToken") ?? ""
        }
        set {
            sharedDefaults?.set(newValue, forKey: "PPGDeviceToken")
        }
    }

    var eventManager: EventManager {
        return EventManager(sharedData: self)
    }

    var center: UNUserNotificationCenter!
}
