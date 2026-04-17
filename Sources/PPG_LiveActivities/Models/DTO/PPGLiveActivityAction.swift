//
//  PPGLiveActivityAction.swift
//  PPG_LiveActivities
//
//  Mirrors backend ILiveNotificationActionDTO hierarchy.
//

import Foundation

/// Horizontal alignment of an action (button) in the Live Activity layout.
@available(iOS 17.2, *)
public enum PPGActionAlignment: String, Codable, Sendable {
    case left = "LEFT"
    case center = "CENTER"
    case right = "RIGHT"
    case stretch = "STRETCH"
}

/// iOS-specific styling applied to an action button.
@available(iOS 17.2, *)
public struct PPGActionIOSDesign: Codable, Sendable, Hashable {
    public let alignment: PPGActionAlignment
    public let borderRadius: Double
    public let textColor: PPGBasicColorSet
    public let backgroundColor: PPGBasicColorSet
    public let border: Border?
    
    public struct Border: Codable, Sendable, Hashable {
        public let color: PPGBasicColorSet
        public let width: Double
        
        public init(color: PPGBasicColorSet, width: Double) {
            self.color = color
            self.width = width
        }
    }
    
    public init(
        alignment: PPGActionAlignment,
        borderRadius: Double,
        textColor: PPGBasicColorSet,
        backgroundColor: PPGBasicColorSet,
        border: Border?
    ) {
        self.alignment = alignment
        self.borderRadius = borderRadius
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.border = border
    }
}

/// Wrapper for platform-specific action design.
@available(iOS 17.2, *)
public struct PPGActionDesign: Codable, Sendable, Hashable {
    public let ios: PPGActionIOSDesign
    
    public init(ios: PPGActionIOSDesign) {
        self.ios = ios
    }
}

/// A tappable action rendered in the Live Activity.
@available(iOS 17.2, *)
public enum PPGLiveActivityAction: Codable, Sendable, Hashable {
    case openApp(name: String, design: PPGActionDesign)
    case url(name: String, url: String, design: PPGActionDesign)
    case close(name: String, design: PPGActionDesign)
    
    public var name: String {
        switch self {
        case .openApp(let name, _), .url(let name, _, _), .close(let name, _):
            return name
        }
    }
    
    public var design: PPGActionDesign {
        switch self {
        case .openApp(_, let design), .url(_, _, let design), .close(_, let design):
            return design
        }
    }
    
    // Codable
    
    private enum CodingKeys: String, CodingKey {
        case type, name, url, design
    }
    
    private enum Kind: String, Codable {
        case openApp = "OPEN_APP"
        case url = "URL"
        case close = "CLOSE"
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .type)
        let name = try c.decode(String.self, forKey: .name)
        let design = try c.decode(PPGActionDesign.self, forKey: .design)
        switch kind {
        case .openApp:
            self = .openApp(name: name, design: design)
        case .url:
            let url = try c.decode(String.self, forKey: .url)
            self = .url(name: name, url: url, design: design)
        case .close:
            self = .close(name: name, design: design)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(design, forKey: .design)
        switch self {
        case .openApp:
            try c.encode(Kind.openApp, forKey: .type)
        case .url(_, let url, _):
            try c.encode(Kind.url, forKey: .type)
            try c.encode(url, forKey: .url)
        case .close:
            try c.encode(Kind.close, forKey: .type)
        }
    }
}
