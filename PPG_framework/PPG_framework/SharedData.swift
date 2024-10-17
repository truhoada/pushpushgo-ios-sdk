//
//  SharedData.swift
//  PPG_framework
//
//  Created by Adam Majczyk on 14/07/2020.
//  Copyright © 2020 Goodylabs. All rights reserved.
//

import Foundation
import UserNotifications

class SharedData {

    static var shared = SharedData()

    var projectId: String {
        get {
            let sharedDefaults = UserDefaults(suiteName: "group.ppg.sharedDataPPG")
            return sharedDefaults?.string(forKey: "PPGProjectId") ?? ""
        }
        set {
            let sharedDefaults = UserDefaults(suiteName: "group.ppg.sharedDataPPG")
            sharedDefaults?.set(newValue, forKey: "PPGProjectId")
        }
    }

    var apiToken: String {
        get {
            let sharedDefaults = UserDefaults(suiteName: "group.ppg.sharedDataPPG")
            return sharedDefaults?.string(forKey: "PPGAPIToken") ?? ""
        }
        set {
            let sharedDefaults = UserDefaults(suiteName: "group.ppg.sharedDataPPG")
            sharedDefaults?.set(newValue, forKey: "PPGAPIToken")
        }
    }

    var subscriberId: String {
        get {
            let sharedDefaults = UserDefaults(suiteName: "group.ppg.sharedDataPPG")
            return sharedDefaults?.string(forKey: "PPGSubscriberId") ??
            // Legacy supported value
            UserDefaults.standard.string(forKey: "PPGSubscriberId") ?? ""
        }
        set {
            let sharedDefaults = UserDefaults(suiteName: "group.ppg.sharedDataPPG")
            sharedDefaults?.set(newValue, forKey: "PPGSubscriberId")
        }
    }

    var deviceToken: String {
        get {
            let sharedDefaults = UserDefaults(suiteName: "group.ppg.sharedDataPPG")
            return sharedDefaults?.string(forKey: "PPGDeviceToken") ?? ""
        }
        set {
            let sharedDefaults = UserDefaults(suiteName: "group.ppg.sharedDataPPG")
            sharedDefaults?.set(newValue, forKey: "PPGDeviceToken")
        }
    }

    var center: UNUserNotificationCenter!
}

