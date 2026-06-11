//
//  LiveActivityClickURL.swift
//  PPG_LiveActivities
//
//  Builds and parses the SDK-internal `ppg-la://click` URL used to count
//  Live Activity taps. Every tappable element in a Live Activity (body tap
//  via `widgetURL`, and each action button via `Link`) is wrapped in one of
//  these URLs so the host app routes the tap back through
//  `LiveActivitiesSDK.handleURL(...)`, which records the statistics event and
//  then forwards to the real destination carried in `to`.
//
//  Shape: ppg-la://click?id={liveNotificationId}&type={clicked|clicked_1|clicked_2}&v={liveDataVersion}&to={percent-encoded destination URL}
//

import Foundation

@available(iOS 17.2, *)
internal enum LiveActivityClickURL {

    static let scheme = "ppg-la"
    static let host = "click"

    struct Parsed {
        let liveNotificationId: String
        let type: PPGLiveNotificationStatisticsEventType
        let liveDataVersion: Int
        /// Real destination to forward to after recording the event, if any.
        let destination: URL?
    }

    /// Wrap a real `destination` (may be `nil` for a body tap with no deep
    /// link) into a `ppg-la://click` URL carrying the event metadata.
    static func make(
        liveNotificationId: String,
        type: PPGLiveNotificationStatisticsEventType,
        liveDataVersion: Int,
        destination: URL?
    ) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        var items = [
            URLQueryItem(name: "id", value: liveNotificationId),
            URLQueryItem(name: "type", value: type.rawValue),
            URLQueryItem(name: "v", value: String(liveDataVersion))
        ]
        if let destination {
            items.append(URLQueryItem(name: "to", value: destination.absoluteString))
        }
        components.queryItems = items
        return components.url
    }

    /// Parse a `ppg-la://click` URL. Returns `nil` for any other URL.
    static func parse(_ url: URL) -> Parsed? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        guard let id = value("id"),
              let rawType = value("type"),
              let type = PPGLiveNotificationStatisticsEventType(rawValue: rawType) else {
            return nil
        }
        let version = value("v").flatMap(Int.init) ?? 0
        let destination = value("to").flatMap(URL.init)
        return Parsed(liveNotificationId: id, type: type, liveDataVersion: version, destination: destination)
    }
}
