//
//  ApiService.swift
//  PPG_framework
//
//  Created by Adam Majczyk on 14/07/2020.
//  Copyright © 2020 Goodylabs. All rights reserved.
//

import Foundation

class ApiService {
    static var shared = ApiService()

    let baseUrl = "https://api.pushpushgo.com"

    func subscribeUser(token: String, handler: @escaping (_ result: ActionResult) -> Void) {
        guard let encoded = try? JSONEncoder().encode(["token": token]) else {
            let log = "Failed to encode token"
            print(log)
            handler(.error(log))
            return
        }

        let projectId = SharedData.shared.projectId

        let url = URL(string: "\(baseUrl)/v1/ios/\(projectId)/subscriber")!
        var request = URLRequest(url: url)
        request.addStandardHeaders()
        request.httpMethod = "POST"
        request.httpBody = encoded

        URLSession.shared.dataTask(with: request) { data, response, error in
            // handle the result here.
            guard let data = data else {
                let log = "No data in response: \(error?.localizedDescription ?? "Unknown error")."
                print(log)
                handler(.error(log))
                return
            }

            if let decodedData = try? JSONDecoder().decode(SubscribeUserResponse.self, from: data) {
                print("decodedData:")
                print(decodedData)

                SharedData.shared.subscriberId = decodedData._id

                UserDefaults.standard.set(decodedData._id, forKey: "PPGSubscriberId")
                handler(.success)
            } else {
                let log = "Invalid response from server"
                print(log)
                handler(.error(log))
            }
        }.resume()
    }

    func unsubscribeUser(handler: @escaping (_ result: ActionResult) -> Void) {
        let projectId = SharedData.shared.projectId
        let subscriberId = SharedData.shared.getSubscriberId()

        let url = URL(string: "\(baseUrl)/v1/ios/\(projectId)/subscriber/\(subscriberId)")!
        var request = URLRequest(url: url)
        request.addStandardHeaders()
        request.httpMethod = "DELETE"

        URLSession.shared.dataTask(with: request) { data, response, error in
            // handle the result here.
            if error != nil {
                handler(.error(error?.localizedDescription ?? "Unknown error"))
                return
            }

            handler(.success)

        }.resume()
    }

    func sendEvent(event: Event, handler: @escaping (_ result: ActionResult) -> Void) {
        let projectId = SharedData.shared.projectId
        let subscriberId = SharedData.shared.getSubscriberId()
        
        if subscriberId == "" {
            handler(.error("Subscriber ID is not available"))
            return
        }

        let bodyData = EventBody(
            type: event.eventType.rawValue,
            payload: EventBodyPayload(timestamp: event.timestamp, button: event.button,
                                      campaign: event.campaign, subscriber: subscriberId))

        guard let encoded = try? JSONEncoder().encode(bodyData) else {
            handler(.error("Failed to encode token"))
            return
        }

        let url = URL(string: "\(baseUrl)/v1/ios/\(projectId)/event/")!
        var request = URLRequest(url: url)
        request.addStandardHeaders()
        request.httpMethod = "POST"
        request.httpBody = encoded

        URLSession.shared.dataTask(with: request) { data, response, error in
            // handle the result here.
            if error != nil {
                handler(.error(error?.localizedDescription ?? "Unknown error"))
                return
            }

            handler(.success)
        }.resume()
    }

    func sendBeacon(beacon: Beacon, handler: @escaping (_ result: ActionResult) -> Void) {
        let projectId = SharedData.shared.projectId
        let subscriberId = SharedData.shared.getSubscriberId()
        
        if subscriberId == "" {
            handler(.error("Subscriber ID is not available"))
            return
        }

        let requestBody = BeaconBody(beacon: beacon)

        guard let encoded = try? JSONEncoder().encode(requestBody) else {
            print("Failed to encode token")
            return
        }

        let url = URL(string: "\(baseUrl)/v1/ios/\(projectId)/subscriber/\(subscriberId)/beacon")!
        var request = URLRequest(url: url)
        request.addStandardHeaders()
        request.httpMethod = "POST"
        request.httpBody = encoded

        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                handler(.error(error?.localizedDescription ?? "Unknown error"))
                return
            }

            handler(.success)
        }.resume()
    }
}
