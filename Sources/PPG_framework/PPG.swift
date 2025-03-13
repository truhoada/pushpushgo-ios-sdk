//
//  PPG.swift
//  PPG_framework
//
//  Created by Adam Majczyk on 13/07/2020.
//  Copyright © 2020 Goodylabs. All rights reserved.
//

import UIKit
import UserNotifications

@objcMembers
public class PPG: NSObject, UNUserNotificationCenterDelegate {

    // Shared instance of PPG for handling notification delegate methods
    public static let shared = PPG()
    
    public static var subscriberId: String {
        return SharedData.shared.subscriberId
    }

    override public init() {
        super.init()
    }

    public static func initializeNotifications(
        projectId: String, apiToken: String, appGroupId: String
    ) {
        SharedData.shared.appGroupId = appGroupId
        SharedData.shared.projectId = projectId
        SharedData.shared.apiToken = apiToken
        SharedData.shared.center = UNUserNotificationCenter.current()
        
        // Register default notification categories
        CategoryManager.addDefaultCategories()
    }
    
    /// Using for Objective C project
    public static func registerForNotificationsObjc(application: UIApplication, onSuccess: @escaping() -> Void, onFailure: @escaping(String?) -> Void) {
        registerForNotifications(application: application) { result in
            switch result {
            case .success:
                onSuccess()
            case .error(let error):
                onFailure(error)
            }
        }
    }

    /// Using for Swift project
    public static func registerForNotifications(
        application: UIApplication,
        handler: @escaping (_ result: ActionResult) -> Void
    ) {
        SharedData.shared.center.requestAuthorization(options: [
            .alert, .sound, .badge,
        ]) { granted, error in
            if let error = error {
                print("Init Notifications error: \(error)")
                handler(.error(error.localizedDescription))
                return
            }

            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
            print("Init Notifications success")

            handler(.success)
        }
    }

    public static func changeProjectIdAndToken(
        _ projectId: String, _ apiToken: String
    ) {
        SharedData.shared.projectId = projectId
        SharedData.shared.apiToken = apiToken
    }
    
    /// Using for Objective C project
    public static func sendDeviceTokenObjC(_ token: Data, onSuccess: @escaping(_ subscriberId: String?) -> Void, onFailure: @escaping(String?) -> Void) {
        sendDeviceToken(token) { result, subscriberId in
            switch result {
            case .success:
                onSuccess(subscriberId)
            case .error(let error):
                onFailure(error)
            }
        }
    }

    /// Using for Swift project
    public static func sendDeviceToken(_ token: Data, handler: @escaping (_ result: ActionResult, _ subscriberId: String?) -> Void) {
        let tokenParts = token.map { data in String(format: "%02.2hhx", data) }
        let key = tokenParts.joined()
        let oldKey = SharedData.shared.deviceToken
        let subId = SharedData.shared.subscriberId

        print("Device token \(key)")

        if oldKey == key {
            handler(.error("Token already sent"), subId)
            return
        }

        ApiService.shared.subscribeUser(token: key) { result, subscriberId in
            if case .success = result {
                SharedData.shared.deviceToken = key
            }

            handler(result, subscriberId)
        }
    }
    
    /// Using for Objective C project
    public static func resendDeviceTokenObjC(onSuccess: @escaping() -> Void, onFailure: @escaping(String?) -> Void) {
        resendDeviceToken { result in
            switch result {
            case .success:
                onSuccess()
            case .error(let error):
                onFailure(error)
            }
        }
    }
    
    /// Using for Swift project
    public static func resendDeviceToken(handler: @escaping (_ result: ActionResult) -> Void) {
        let token = SharedData.shared.deviceToken
        if token == "" {
            handler(.error("Token is not available"))
            return
        }

        ApiService.shared.subscribeUser(token: token) { result, subscriberId in
            handler(result)
        }
    }
    
    /// Using for Objective C project
    public static func unsubscribeUserObjC(onSuccess: @escaping() -> Void, onFailure: @escaping(String?) -> Void) {
        unsubscribeUser { result in
            switch result {
            case .success:
                onSuccess()
            case .error(let error):
                onFailure(error)
            }
        }
    }

    /// Using for Swift project
    public static func unsubscribeUser(handler: @escaping (_ result: ActionResult) -> Void) {
        ApiService.shared.unsubscribeUser { result in
            if case .success = result {
                SharedData.shared.deviceToken = ""
            }

            handler(result)
        }
    }

    /// Using for Objective C project
    /// Mark given notification as delivered to the user
    /// This should be called in your NotificationServiceExtension
    ///
    /// - Parameter notificationRequest: UNNotificationRequest
    public static func notificationDeliveredObjC(notificationRequest: UNNotificationRequest, onSuccess: @escaping() -> Void, onFailure: @escaping(String?) -> Void) {
        notificationDelivered(notificationRequest: notificationRequest) { result in
            switch result {
            case .success:
                onSuccess()
            case .error(let error):
                onFailure(error)
            }
        }
    }

    /// Using for Swift project
    /// Mark given notification as delivered to the user
    /// This should be called in your NotificationServiceExtension
    ///
    /// - Parameter notificationRequest: UNNotificationRequest
    public static func notificationDelivered(
        notificationRequest: UNNotificationRequest,
        handler: @escaping (_ result: ActionResult) -> Void
    ) {
        SharedData.shared.eventManager.notificationDelivered(
            notificationRequest: notificationRequest, handler: handler)
    }

    /// Using for Objective C project
    @objc public static func registerNotificationDeliveredFromUserInfoObjc(
        userInfo: [AnyHashable: Any], onSuccess: @escaping() -> Void, onFailure: @escaping(String?) -> Void) {
            registerNotificationDeliveredFromUserInfo(userInfo: userInfo) { result in
                switch result {
                case .success:
                    onSuccess()
                case .error(let error):
                    onFailure(error)
                }
            }
    }
    
    /// Using for Swift project
    public static func registerNotificationDeliveredFromUserInfo(
        userInfo: [AnyHashable: Any],
        handler: @escaping (_ result: ActionResult) -> Void
    ) {
        SharedData.shared.eventManager
            .registerNotificationDeliveredFromUserInfo(
                userInfo: userInfo, handler: handler)

    }

    public static func notificationClicked(response: UNNotificationResponse) {
        SharedData.shared.eventManager.notificationClicked(response: response)
    }

    public static func notificationButtonClicked(
        response: UNNotificationResponse, button: Int
    ) {
        SharedData.shared.eventManager.notificationButtonClicked(
            response: response, button: button)
    }

    public static func getUrlFromNotificationResponse(
        response: UNNotificationResponse
    ) -> URL? {
        let userInfo = response.notification.request.content.userInfo
        
        // Check for URL in actions array
        // For specific button clicks
        if response.actionIdentifier != UNNotificationDefaultActionIdentifier,
           let actions = userInfo["actions"] as? [[String: Any]] {
            let index: Int
            switch response.actionIdentifier {
            case "button_1":
                index = 0
            case "button_2":
                index = 1
            default:
                return nil
            }
            
            guard index < actions.count,
                let urlString = actions[index]["url"] as? String,
                urlString.starts(with: "http") || urlString.starts(with: "app"),
                let url = URL(string: urlString) else {
                return nil
            }
            return url
        }
        
        // Fallback to default url
        if let aps = userInfo["aps"] as? [String: Any],
           let urlArgs = aps["url-args"] as? [String],
           let link = urlArgs.first,
           link.starts(with: "http") || link.starts(with: "app"),
           let url = URL(string: link) {
            return url
        }
        
        return nil
    }
    
    public static func modifyNotification(
        _ notification: UNMutableNotificationContent
    ) -> UNMutableNotificationContent {
        // Handle image attachment if present
        if let imageUrl = notification.userInfo["image"] as? String,
           let attachement = try? UNNotificationAttachment(url: imageUrl) {
            notification.attachments = [attachement]
        }
        
        let group = DispatchGroup()
        group.enter()
        
        UNUserNotificationCenter.current().getNotificationCategories { existingCategories in
            var updatedCategories = existingCategories
            
            // Process actions from payload
            if let actions = notification.userInfo["actions"] as? [[String: Any]], !actions.isEmpty {
                
                let dynamicActions = NotificationActionBuilder.createUniqueActions(from: actions)
                
                // Use existing category ID or generate a new one
                let categoryId = notification.categoryIdentifier.isEmpty ? 
                               "ppg_category_\(UUID().uuidString)" : notification.categoryIdentifier
                
                // Create category
                let category = UNNotificationCategory(
                    identifier: categoryId,
                    actions: dynamicActions,
                    intentIdentifiers: [],
                    options: []
                )
                
                // Keep all existing categories except the one we're updating
                updatedCategories = updatedCategories.filter { $0.identifier != categoryId }
                updatedCategories.insert(category)
                
                notification.categoryIdentifier = categoryId
                CategoryManager.saveCategory(id: categoryId, actions: dynamicActions)
                print("PPG SDK - Added category: \(categoryId)")
            } else {
                notification.categoryIdentifier = CategoryManager.defaultCategoryId
                print("PPG SDK - Using default category")
            }
            
            // Get valid stored categories
            let storedCategoryIds = Set(CategoryManager.loadStoredCategories().map { $0.id })
            
            // Keep existing categories that are still valid
            updatedCategories = updatedCategories.filter { category in
                category.identifier == CategoryManager.defaultCategoryId || storedCategoryIds.contains(category.identifier)
            }
            
            // Update notification center
            UNUserNotificationCenter.current().setNotificationCategories(updatedCategories)
            print("PPG SDK - Categories after update: \(updatedCategories.map { $0.identifier })")
            
            group.leave()
        }
        
        group.wait()
        return notification
    }



    public static func sendEventsDataToApi() {
        SharedData.shared.eventManager.sync { result in
            print(result)
        }
    }

    public static func sendBeacon(
        _ beacon: Beacon, handler: @escaping (_ result: ActionResult) -> Void
    ) {

        ApiService.shared.sendBeacon(beacon: beacon, handler: handler)
    }
    
    public static func getEvents() -> [EventDTO] {
        return SharedData.shared.eventManager.getEvents().map {$0.toDTO()}
    }
    
    //UNUserNotificationCenterDelegate
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Display notification when app is in foreground
        completionHandler([.alert, .badge, .sound])
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        
        // Handle the action
        if actionIdentifier == UNNotificationDefaultActionIdentifier {
            // User tapped the notification itself
            PPG.notificationClicked(response: response)
        } else if actionIdentifier == "button_1" {
            PPG.notificationButtonClicked(response: response, button: 1)
        } else if actionIdentifier == "button_2" {
            PPG.notificationButtonClicked(response: response, button: 2)
        } else {
            // Track as regular notification click for unknown actions
            PPG.notificationClicked(response: response)
        }
        
        // Handle URL opening if present
        if let url = PPG.getUrlFromNotificationResponse(response: response) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        }
        
        completionHandler()
    }

}
