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

/// Border styling for a single appearance mode.
@available(iOS 17.2, *)
public struct PPGActionBorder: Codable, Sendable, Hashable {
    public let color: PPGColor
    public let width: Double
    
    public init(color: PPGColor, width: Double) {
        self.color = color
        self.width = width
    }
}

/// Colors and border for one appearance mode (light or dark).
/// Mirrors `ILiveNotificationActionIOSAppearanceDTO`.
/// Each field is a single `PPGColor` — light/dark split is handled by the
/// outer `PPGActionIOSAppearanceSet`.
@available(iOS 17.2, *)
public struct PPGActionIOSAppearance: Codable, Sendable, Hashable {
    public let textColor: PPGColor
    public let backgroundColor: PPGColor?
    public let border: PPGActionBorder?
    
    public init(
        textColor: PPGColor,
        backgroundColor: PPGColor? = nil,
        border: PPGActionBorder? = nil
    ) {
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.border = border
    }
}

/// Light-mode / dark-mode appearance pair.
/// Mirrors `ILiveNotificationActionIOSAppearanceSetDTO`.
@available(iOS 17.2, *)
public struct PPGActionIOSAppearanceSet: Codable, Sendable, Hashable {
    public let lightMode: PPGActionIOSAppearance
    public let darkMode: PPGActionIOSAppearance
    
    public init(lightMode: PPGActionIOSAppearance, darkMode: PPGActionIOSAppearance) {
        self.lightMode = lightMode
        self.darkMode = darkMode
    }
}

/// iOS-specific styling applied to an action button.
/// Mirrors `IBaseLiveNotificationActionDTO.design.ios`.
@available(iOS 17.2, *)
public struct PPGActionIOSDesign: Codable, Sendable, Hashable {
    public let alignment: PPGActionAlignment
    public let borderRadius: Double
    public let appearance: PPGActionIOSAppearanceSet
    
    public init(
        alignment: PPGActionAlignment,
        borderRadius: Double,
        appearance: PPGActionIOSAppearanceSet
    ) {
        self.alignment = alignment
        self.borderRadius = borderRadius
        self.appearance = appearance
    }
    
    // Backward-compatible decode: accept new `appearance` wrapper (current
    // backend) and legacy flat `textColor`/`backgroundColor`/`border` fields
    // (older backend versions that haven't migrated yet).
    private enum CodingKeys: String, CodingKey {
        case alignment, borderRadius, appearance
        case textColor, backgroundColor, border
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        alignment = try c.decode(PPGActionAlignment.self, forKey: .alignment)
        borderRadius = try c.decode(Double.self, forKey: .borderRadius)
        if let app = try c.decodeIfPresent(PPGActionIOSAppearanceSet.self, forKey: .appearance) {
            // New format
            appearance = app
        } else {
            // Legacy flat format — textColor/backgroundColor were PPGBasicColorSet
            // ({ lightMode: {hex}, darkMode: {hex} }). Split into separate modes.
            let textSet = try c.decode(PPGBasicColorSet.self, forKey: .textColor)
            let bgSet = try c.decodeIfPresent(PPGBasicColorSet.self, forKey: .backgroundColor)
            let border = try c.decodeIfPresent(PPGActionBorder.self, forKey: .border)
            let lightMode = PPGActionIOSAppearance(
                textColor: .basic(hex: textSet.lightMode),
                backgroundColor: bgSet.map { .basic(hex: $0.lightMode) },
                border: border
            )
            let darkMode = PPGActionIOSAppearance(
                textColor: .basic(hex: textSet.darkMode),
                backgroundColor: bgSet.map { .basic(hex: $0.darkMode) },
                border: border
            )
            appearance = PPGActionIOSAppearanceSet(lightMode: lightMode, darkMode: darkMode)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(alignment, forKey: .alignment)
        try c.encode(borderRadius, forKey: .borderRadius)
        try c.encode(appearance, forKey: .appearance)
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
