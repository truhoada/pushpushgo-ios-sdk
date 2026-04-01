//
//  MatchPhase.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import Foundation
import SwiftUI

/// Represents all possible phases of a football match
@available(iOS 17.2, *)
public enum MatchPhase: String, Codable, CaseIterable, Sendable {
    case preMatch = "PRE_MATCH"
    case firstHalf = "FIRST_HALF"
    case firstHalfAddedTime = "FIRST_HALF_ADDED_TIME"
    case halfTimeBreak = "HALF_TIME_BREAK"
    case secondHalf = "SECOND_HALF"
    case secondHalfAddedTime = "SECOND_HALF_ADDED_TIME"
    case fullTime = "FULL_TIME"
    case extraTimeBreak = "EXTRA_TIME_BREAK"
    case extraTimeFirstHalf = "EXTRA_TIME_FIRST_HALF"
    case extraTimeFirstHalfAddedTime = "EXTRA_TIME_FIRST_HALF_ADDED_TIME"
    case extraTimeHalfTimeBreak = "EXTRA_TIME_HALF_TIME_BREAK"
    case extraTimeSecondHalf = "EXTRA_TIME_SECOND_HALF"
    case extraTimeSecondHalfAddedTime = "EXTRA_TIME_SECOND_HALF_ADDED_TIME"
    case penaltyShootout = "PENALTY_SHOOTOUT"
    case matchEnded = "MATCH_ENDED"
    
    /// Display text for the match phase
    public var displayText: String {
        switch self {
        case .preMatch:
            return "Pre-Match"
        case .firstHalf:
            return "1st Half"
        case .firstHalfAddedTime:
            return "1st Half +AT"
        case .halfTimeBreak:
            return "Half Time"
        case .secondHalf:
            return "2nd Half"
        case .secondHalfAddedTime:
            return "2nd Half +AT"
        case .fullTime:
            return "Full Time"
        case .extraTimeBreak:
            return "ET Break"
        case .extraTimeFirstHalf:
            return "ET 1st Half"
        case .extraTimeFirstHalfAddedTime:
            return "ET 1st Half +AT"
        case .extraTimeHalfTimeBreak:
            return "ET Half Time"
        case .extraTimeSecondHalf:
            return "ET 2nd Half"
        case .extraTimeSecondHalfAddedTime:
            return "ET 2nd Half +AT"
        case .penaltyShootout:
            return "Penalties"
        case .matchEnded:
            return "Match Ended"
        }
    }
    
    /// Whether the match is actively being played (ball in play or added time)
    public var isPlaying: Bool {
        switch self {
        case .firstHalf, .firstHalfAddedTime,
             .secondHalf, .secondHalfAddedTime,
             .extraTimeFirstHalf, .extraTimeFirstHalfAddedTime,
             .extraTimeSecondHalf, .extraTimeSecondHalfAddedTime,
             .penaltyShootout:
            return true
        default:
            return false
        }
    }
    
    /// Whether the match is in a break period
    public var isBreak: Bool {
        switch self {
        case .halfTimeBreak, .extraTimeBreak, .extraTimeHalfTimeBreak:
            return true
        default:
            return false
        }
    }
    
    /// Whether the match has concluded
    public var isFinished: Bool {
        switch self {
        case .fullTime, .matchEnded:
            return true
        default:
            return false
        }
    }
    
    /// Whether this is added/injury time
    public var isAddedTime: Bool {
        switch self {
        case .firstHalfAddedTime, .secondHalfAddedTime,
             .extraTimeFirstHalfAddedTime, .extraTimeSecondHalfAddedTime:
            return true
        default:
            return false
        }
    }
    
    /// Short abbreviation for compact display (e.g. Dynamic Island minimal)
    public var shortText: String {
        switch self {
        case .preMatch: return "PRE"
        case .firstHalf: return "1H"
        case .firstHalfAddedTime: return "1H+"
        case .halfTimeBreak: return "HT"
        case .secondHalf: return "2H"
        case .secondHalfAddedTime: return "2H+"
        case .fullTime: return "FT"
        case .extraTimeBreak: return "ETB"
        case .extraTimeFirstHalf: return "ET1"
        case .extraTimeFirstHalfAddedTime: return "ET1+"
        case .extraTimeHalfTimeBreak: return "ETHT"
        case .extraTimeSecondHalf: return "ET2"
        case .extraTimeSecondHalfAddedTime: return "ET2+"
        case .penaltyShootout: return "PEN"
        case .matchEnded: return "END"
        }
    }
    
    /// Color representing the current phase state for UI display
    public var color: Color {
        if isPlaying { return .green }
        if isBreak { return .yellow }
        if isFinished { return .secondary }
        return .primary
    }
}
