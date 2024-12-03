//
//  EventManager.swift
//  PPG_framework
//
//  Created by PushPushGo on 17/10/2024.
//  Copyright © 2024 Goodylabs. All rights reserved.
//
//

import Foundation
import UserNotifications

class EventManager {
    private let sharedData: SharedData
    private let eventSender: EventSender

    init(sharedData: SharedData, eventSender: EventSender = DefaultEventSender()) {
        self.sharedData = sharedData
        self.eventSender = eventSender
    }

    public func notificationDelivered(notificationRequest: UNNotificationRequest,
                                      handler: @escaping (_ result: ActionResult) -> Void) {
        let notificationContent = notificationRequest.content

        guard let campaign = notificationContent.userInfo["campaign"] as? String else { return }

        let deliveryEvent = Event(eventType: .delivered, button: nil, campaign: campaign, sender: self.eventSender)
        register(event: deliveryEvent, handler: handler)
    }

    public func registerNotificationDeliveredFromUserInfo(userInfo: [AnyHashable: Any],
                                                          handler: @escaping (_ result: ActionResult) -> Void) {
        guard let campaign = userInfo["campaign"] as? String else { return }

        let deliveryEvent = Event(eventType: .delivered, button: nil, campaign: campaign, sender: self.eventSender)
        register(event: deliveryEvent, handler: handler)
    }

    public func notificationClicked(response: UNNotificationResponse) {
        let campaign = response.notification.request.content
            .userInfo["campaign"] as? String

        let clickEvent = Event(eventType: .clicked, button: 0,
                               campaign: campaign ?? "", sender: self.eventSender)
        register(event: clickEvent) { result in print(result) }
    }

    public func notificationButtonClicked(
        response: UNNotificationResponse, button: Int) {

        let campaign = response.notification.request.content
            .userInfo["campaign"] as? String

        let clickEvent = Event(eventType: .clicked, button: button,
                               campaign: campaign ?? "", sender: self.eventSender)
        register(event: clickEvent) { result in print(result) }
    }


    public func sync(handler: @escaping (_ result: [Event]) -> Void) {
        let validEvents = getEvents().filter { !$0.canDelete() }
        print("Valid events for syncing: \(validEvents.map { $0.getKey() })")
        let dispatchGroup = DispatchGroup()

        validEvents.forEach { event in
            dispatchGroup.enter()
            event.send(sender: self.eventSender) { result in
                print("Event sent: \(event.getKey()), Result: \(result)")
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            self.setEvents(events: validEvents)
            print("All events have been synced.")
            handler(validEvents)
        }
    }


    public func register(event: Event, handler: @escaping (_ result: ActionResult) -> Void) {
        print("Registering event: \(event.getKey())")
        if exists(event: event) {
            print("Event already exists. Returning error.")
            DispatchQueue.main.async {
                handler(.error("Event was sent before. Omitting"))
            }
            return
        }
        append(event: event)
        print("Event appended. Calling sync.")
        sync { result in
            print("Sync completed for event: \(event.getKey())")
            DispatchQueue.main.async {
                handler(.success)
            }
        }
    }

    private func exists(event: Event) -> Bool {
        return getEvents().contains(where: { $0.softEquals(event) })
    }

    private func append(event: Event) {
        var events = getEvents()
        events.append(event)
        setEvents(events: events)
    }


    public func getEvents() -> [Event] {
        if let data = self.sharedData.sharedDefaults?.data(forKey: "SavedPPGEvents") {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Data from UserDefaults: \(jsonString)")
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder -> Date in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                if let date = ISO8601DateFormatter.custom.date(from: dateString) {
                    return date
                } else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
                }
            }
            do {
                let events = try decoder.decode([Event].self, from: data)
                return events
            } catch {
                print("Decoding error: \(error)")
                return []
            }
        }
        return []
    }

    public func setEvents(events: [Event]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let dateString = ISO8601DateFormatter.custom.string(from: date)
            try container.encode(dateString)
        }
        do {
            let data = try encoder.encode(events)
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Encoded events: \(jsonString)")
            }
            self.sharedData.sharedDefaults?.set(data, forKey: "SavedPPGEvents")
        } catch {
            print("Encoding error: \(error)")
        }
    }

    public func clearEvents() {
        self.sharedData.sharedDefaults?.removeObject(forKey: "SavedPPGEvents")
    }
    
}


extension ISO8601DateFormatter {
    static let custom: ISO8601DateFormatter = Event.iso8601DateFormatter
}
