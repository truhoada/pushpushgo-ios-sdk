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

    func subscribeUser(token: String, handler:@escaping (_ result: ActionResult) -> Void) {
        guard let encoded = try? JSONEncoder().encode(["token": token]) else {
            print("Failed to encode token")
            return
        }

        let projectId = SharedData.shared.projectId

        let url = URL(string: "\(baseUrl)/v1/ios/\(projectId)/subscriber")!
        var request = URLRequest(url: url)
        request.addStandardHeaders()
        request.httpMethod = "POST"
        request.httpBody = encoded

        debugRequest(request: request)

        URLSession.shared.dataTask(with: request) { data, response, error in
            // handle the result here.
            self.debugResponse(response: response, data: data, error: error)

            guard let data = data else {
                print("No data in response: \(error?.localizedDescription ?? "Unknown error").")
                return
            }

            if let decodedData = try? JSONDecoder().decode(SubscribeUserResponse.self, from: data) {
                print("decodedData:")
                print(decodedData)

                SharedData.shared.subscriberId = decodedData._id

                UserDefaults.standard.set(decodedData._id,
                    forKey: "PPGSubscriberId")
            } else {
                print("Invalid response from server")
            }
        }.resume()
    }

    func unsubscribeUser(handler:@escaping (_ result: ActionResult) -> Void) {
        let projectId = SharedData.shared.projectId
        let subscriberId = SharedData.shared.getSubscriberId()

        let url = URL(string: "\(baseUrl)/v1/ios/\(projectId)/subscriber/\(subscriberId)")!
        var request = URLRequest(url: url)
        request.addStandardHeaders()
        request.httpMethod = "DELETE"
        
        debugRequest(request: request)

        URLSession.shared.dataTask(with: request) { data, response, error in
            // handle the result here.
            self.debugResponse(response: response, data: data, error: error)

            if error != nil {
                handler(.error(error?.localizedDescription ?? "Unknown error"))
                return
            }

            handler(.success)

        }.resume()
    }

    func sendEvent(event: Event, handler:@escaping (_ result: ActionResult) -> Void) {
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

        debugRequest(request: request)

        URLSession.shared.dataTask(with: request) { data, response, error in
            // handle the result here.
            self.debugResponse(response: response, data: data, error: error)

            if error != nil {
                handler(.error(error?.localizedDescription ?? "Unknown error"))
                return
            }

            handler(.success)
        }.resume()
    }

    func sendBeacon(beacon: Beacon, handler:@escaping (_ result: ActionResult) -> Void) {
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

        debugRequest(request: request)

        URLSession.shared.dataTask(with: request) { data, response, error in
            self.debugResponse(response: response, data: data, error: error)

            if error != nil {
                handler(.error(error?.localizedDescription ?? "Unknown error"))
                return
            }

            handler(.success)
        }.resume()
    }

    func debugRequest(request: URLRequest) {
//        print(request.httpMethod)
//        print(request)
//        print(request.allHTTPHeaderFields)
//        if let body = request.httpBody {
//            print(String(data: body, encoding: .utf8))
//        }
    }

    func debugResponse(response: URLResponse?, data: Data?, error: Error?) {
//        print("data:")
//        print(data)
//        print("response:")
//        print(response)
//        print("error:")
//        print(error)
    }
}
