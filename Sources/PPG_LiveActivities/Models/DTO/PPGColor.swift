//
//  PPGColor.swift
//  PPG_LiveActivities
//
//  Mirrors backend IColor / IColorSetDTO types.
//

import Foundation
import SwiftUI

/// Direction of a gradient color fill.
@available(iOS 17.2, *)
public enum PPGGradientDirection: String, Codable, Sendable {
    case topToBottom = "TOP_TO_BOTTOM"
    case bottomToTop = "BOTTOM_TO_TOP"
    case leftToRight = "LEFT_TO_RIGHT"
    case rightToLeft = "RIGHT_TO_LEFT"
    
    var startPoint: UnitPoint {
        switch self {
        case .topToBottom: return .top
        case .bottomToTop: return .bottom
        case .leftToRight: return .leading
        case .rightToLeft: return .trailing
        }
    }
    
    var endPoint: UnitPoint {
        switch self {
        case .topToBottom: return .bottom
        case .bottomToTop: return .top
        case .leftToRight: return .trailing
        case .rightToLeft: return .leading
        }
    }
}

/// A single color value — either a solid hex or a gradient.
@available(iOS 17.2, *)
public enum PPGColor: Codable, Sendable, Hashable {
    case basic(hex: String)
    case gradient(fromHex: String, toHex: String, direction: PPGGradientDirection)
    
    // Codable — backend sends either `{hex}` (basic) or
    // `{fromHex, toHex, direction}` (gradient).
    
    private enum CodingKeys: String, CodingKey {
        case type, hex, fromHex, toHex, direction
    }
    
    private enum Kind: String, Codable {
        case basic = "BASIC"
        case gradient = "GRADIENT"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Prefer explicit discriminator when present (future-proof).
        let kind = try container.decodeIfPresent(Kind.self, forKey: .type)
        
        // Gradient: either type == GRADIENT or gradient fields present.
        let hasGradientFields = container.contains(.fromHex)
            && container.contains(.toHex)
        
        if kind == .gradient || hasGradientFields {
            let from = try container.decode(String.self, forKey: .fromHex)
            let to = try container.decode(String.self, forKey: .toHex)
            // direction is optional; default to top→bottom
            let dir = try container.decodeIfPresent(
                PPGGradientDirection.self, forKey: .direction
            ) ?? .topToBottom
            self = .gradient(fromHex: from, toHex: to, direction: dir)
            return
        }
        
        // Basic: presence of `hex`.
        if container.contains(.hex) {
            let hex = try container.decode(String.self, forKey: .hex)
            self = .basic(hex: hex)
            return
        }
        
        throw DecodingError.dataCorrupted(
            .init(
                codingPath: decoder.codingPath,
                debugDescription:
                    "PPGColor: expected either `hex` (basic) or `fromHex`/`toHex` (gradient) fields."
            )
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .basic(let hex):
            try container.encode(hex, forKey: .hex)
        case .gradient(let from, let to, let dir):
            try container.encode(from, forKey: .fromHex)
            try container.encode(to, forKey: .toHex)
            try container.encode(dir, forKey: .direction)
        }
    }
}

/// A color-set that supports light & dark mode and allows gradients.
@available(iOS 17.2, *)
public struct PPGColorSet: Codable, Sendable, Hashable {
    public let lightMode: PPGColor
    public let darkMode: PPGColor
    
    public init(lightMode: PPGColor, darkMode: PPGColor) {
        self.lightMode = lightMode
        self.darkMode = darkMode
    }
    
    /// Convenience — same color for both modes.
    public init(_ color: PPGColor) {
        self.lightMode = color
        self.darkMode = color
    }
    
    /// Pick the color matching the given color scheme.
    public func resolve(for scheme: ColorScheme) -> PPGColor {
        scheme == .dark ? darkMode : lightMode
    }
}

/// A basic (non-gradient) color with light/dark variants.
/// Used for text, borders, where gradients don't apply.
@available(iOS 17.2, *)
public struct PPGBasicColorSet: Codable, Sendable, Hashable {
    public let lightMode: String   // hex
    public let darkMode: String    // hex
    
    public init(lightMode: String, darkMode: String) {
        self.lightMode = lightMode
        self.darkMode = darkMode
    }
    
    public init(_ hex: String) {
        self.lightMode = hex
        self.darkMode = hex
    }
    
    public func resolve(for scheme: ColorScheme) -> String {
        scheme == .dark ? darkMode : lightMode
    }
    
    private enum CodingKeys: String, CodingKey {
        case lightMode, darkMode
    }
    
    private struct BasicColorPayload: Codable {
        let type: String?
        let hex: String
    }
    
    private static func decodeHex(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> String {
        if let raw = try? container.decode(String.self, forKey: key) {
            return raw
        }
        let nested = try container.decode(BasicColorPayload.self, forKey: key)
        return nested.hex
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.lightMode = try Self.decodeHex(from: container, forKey: .lightMode)
        self.darkMode = try Self.decodeHex(from: container, forKey: .darkMode)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(BasicColorPayload(type: nil, hex: lightMode), forKey: .lightMode)
        try container.encode(BasicColorPayload(type: nil, hex: darkMode), forKey: .darkMode)
    }
}

// SwiftUI Helpers

@available(iOS 17.2, *)
extension Color {
    /// Create a SwiftUI Color from a hex string (e.g. "#FF5733" or "FF5733").
    public init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        
        let r, g, b, a: Double
        switch cleaned.count {
        case 6:
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
            a = 1.0
        case 8:
            r = Double((value >> 24) & 0xFF) / 255.0
            g = Double((value >> 16) & 0xFF) / 255.0
            b = Double((value >> 8) & 0xFF) / 255.0
            a = Double(value & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

@available(iOS 17.2, *)
extension PPGColor {
    /// Render this color as a SwiftUI view (auto-dispatches to Color or LinearGradient).
    @ViewBuilder
    public func view() -> some View {
        switch self {
        case .basic(let hex):
            Color(hex: hex)
        case .gradient(let from, let to, let dir):
            LinearGradient(
                colors: [Color(hex: from), Color(hex: to)],
                startPoint: dir.startPoint,
                endPoint: dir.endPoint
            )
        }
    }
}

@available(iOS 17.2, *)
extension PPGColorSet {
    /// Render the appropriate color for the current color scheme.
    @ViewBuilder
    public func view(for scheme: ColorScheme) -> some View {
        resolve(for: scheme).view()
    }
}
