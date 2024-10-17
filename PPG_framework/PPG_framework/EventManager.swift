//
//  EventManager.swift
//  PPG_framework
//
//  Created by PushPushGo on 17/10/2024.
//  Copyright © 2024 Goodylabs. All rights reserved.
//

import Foundation
import UserNotifications

class EventManager {
    private let sharedData: SharedData
    
    init(sharedData: SharedData) {
        self.sharedData = sharedData
    }
    
    
    public func notificationDelivered(notificationRequest: UNNotificationRequest,
                                             handler: @escaping (_ result: ActionResult) -> Void) {
        let notificationContent = notificationRequest.content

        guard let campaign = notificationContent.userInfo["campaign"] as? String else { return }

        let deliveryEvent = Event(eventType: .delivered, button: nil, campaign: campaign)
        register(event: deliveryEvent)
    }

    public func registerNotificationDeliveredFromUserInfo(userInfo: [AnyHashable: Any],
                                    handler: @escaping (_ result: ActionResult) -> Void) {

        guard let campaign = userInfo["campaign"] as? String else { return }

        let deliveryEvent = Event(eventType: .delivered, button: nil, campaign: campaign)
        register(event: deliveryEvent)
    }

    public func notificationClicked(response: UNNotificationResponse) {
        let campaign = response.notification.request.content
            .userInfo["campaign"] as? String

        let clickEvent = Event(eventType: .clicked, button: 0,
                               campaign: campaign ?? "")
        register(event: clickEvent)
    }

    public func notificationButtonClicked(
        response: UNNotificationResponse, button: Int) {

        let campaign = response.notification.request.content
            .userInfo["campaign"] as? String

        let clickEvent = Event(eventType: .clicked, button: button,
                               campaign: campaign ?? "")
        register(event: clickEvent)
    }
    
    public func sync() {
        let validEvents = getEvents().filter({ $0.canDelete() == false})

        validEvents.forEach { event in
            event.send { result in
                print(result)
            }
        }
        setEvents(events: validEvents)
    }

    
    private func append(event: Event) {
        var events = getEvents()
        events.append(event)
        
        setEvents(events: events)
        
    }
    
    private func register(event: Event) {
        if (exists(event: event)) {
            return
        }
            
        append(event: event)
        event.send { result in
            switch result {
            case .success:
                break
            case .error:
                break
            }
        }
    }
    
    private func exists(event: Event) -> Bool {
        return getEvents().contains(where: { $0.softEquals(event) })
    }
    
    private func getEvents() -> [Event] {
        if let data = self.sharedData.sharedDefaults?.value(forKey: "SavedPPGEvents") as? Data {
            guard let events = try? PropertyListDecoder()
                .decode([Event].self, from: data)
                else { return [] }
            return events
        }
        return []
    }
    
    private func setEvents(events: [Event]) -> Void {
        self.sharedData.sharedDefaults?.set(try? PropertyListEncoder().encode(events),
                            forKey: "SavedPPGEvents")
    }
}
