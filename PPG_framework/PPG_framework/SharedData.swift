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
    
    var projectId = ""
    var apiToken = ""
    var deviceToken = ""
    var subscriberId = ""
    
    var center: UNUserNotificationCenter!
    
    func getSubscriberId() -> String {
        if subscriberId != "" {
            return subscriberId
        } else {
            return UserDefaults.standard.string(forKey: "PPGSubscriberId") ?? ""
        }
    }
}
