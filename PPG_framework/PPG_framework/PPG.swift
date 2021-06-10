//
//  PPG.swift
//  PPG_framework
//
//  Created by Adam Majczyk on 13/07/2020.
//  Copyright © 2020 Goodylabs. All rights reserved.
//

import UIKit
import UserNotifications

public class PPG: NSObject, UNUserNotificationCenterDelegate {

    override public init() {
        super.init()
    }

    public static func initializeNotifications(projectId: String, apiToken: String) {
        SharedData.shared.projectId = projectId
        SharedData.shared.apiToken = apiToken
        SharedData.shared.center = UNUserNotificationCenter.current()
    }

    public static func registerForNotifications(application: UIApplication, handler: @escaping (_ result: ActionResult) -> Void) {
        SharedData.shared.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
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

    public static func sendDeviceToken(_ token: Data, handler: @escaping (_ result: ActionResult) -> Void) {
        let tokenParts = token.map { data in String(format: "%02.2hhx", data) }
        let key = tokenParts.joined()
        let oldKey = SharedData.shared.deviceToken

        if oldKey == key {
            handler(.error("Token already sent"))
        }
        SharedData.shared.deviceToken = key
        print("Device token \(key)")

        ApiService.shared.subscribeUser(token: key) { result in
            handler(result)
        }
    }

    public static func unsubscribeUser(handler: @escaping (_ result: ActionResult) -> Void) {
        ApiService.shared.unsubscribeUser { result in
            handler(result)
        }
    }

    public static func notificationClicked(response: UNNotificationResponse) {
        let campaign = response.notification.request.content
            .userInfo["campaign"] as? String

        let clickEvent = Event(eventType: .clicked, button: 0,
                               campaign: campaign ?? "")

        saveEvent(clickEvent)
    }

    public static func notificationButtonClicked(response: UNNotificationResponse,
                                                 button: Int) {
        let campaign = response.notification.request.content
            .userInfo["campaign"] as? String

        let clickEvent = Event(eventType: .clicked, button: button,
                               campaign: campaign ?? "")

        saveEvent(clickEvent)
    }

    public static func getUrlFromNotificationResponse(response: UNNotificationResponse) -> URL? {
        guard let aps = response.notification.request.content
                .userInfo["aps"] as? [String: AnyObject],
            let link = aps["url-args"]?.firstObject as? String,
            (link.starts(with: "http") || link.starts(with: "app")),
            let url = URL(string: link)
            else {
                return nil
        }

        return url
    }

    public static func modifyNotification(_ notification: UNMutableNotificationContent) -> UNMutableNotificationContent {

        guard let imageUrl = notification.userInfo["image"] as? String
            else { return notification }

        guard let attachement = try? UNNotificationAttachment(url: imageUrl)
            else { return notification }

        notification.attachments = [attachement]

        return notification
    }

    public static func sendEventsDataToApi() {
        let savedEvents = getEvents()
        var tmpEvents = savedEvents

        savedEvents.forEach { event in
            event.send { result in
                switch result {
                case .success:
                    removeSavedEvent(event)
                case .error:
                    break
                }
            }
        }
    }

    public static func sendBeacon(_ beacon: Beacon, handler: @escaping (_ result: ActionResult) -> Void) {
        ApiService.shared.sendBeacon(beacon: beacon, handler: handler)
    }

    private static func saveEvent(_ event: Event) {
        var events = getEvents()

        events.append(event)
        UserDefaults.standard.set(try? PropertyListEncoder().encode(events),
                                  forKey: "SavedPPGEvents")
    }

    private static func saveEvents(_ events: [Event]) {
        UserDefaults.standard.set(try? PropertyListEncoder().encode(events),
                                  forKey: "SavedPPGEvents")
    }

    private static func getEvents() -> [Event] {
        if let data = UserDefaults.standard
            .value(forKey: "SavedPPGEvents") as? Data {
            guard let event = try? PropertyListDecoder()
                .decode(Array<Event>.self, from: data)
                else { return [] }
            return event
        }
        return []
    }

    private static func removeSavedEvent(_ event: Event) {
        let events = getEvents().filter { $0 != event }
        saveEvents(events)
    }

}
