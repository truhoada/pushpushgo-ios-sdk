//
//  PPG_LiveActivitiesTests.swift
//  PPG_LiveActivitiesTests
//
//  Created by PushPushGo on 13/03/2026.
//

import XCTest
import SwiftUI
@testable import PPG_LiveActivities

final class PPG_LiveActivitiesTests: XCTestCase {
    
    // MatchPhase Tests
    
    @available(iOS 17.2, *)
    func testMatchPhaseDisplayText() {
        XCTAssertEqual(MatchPhase.preMatch.displayText, "Pre-Match")
        XCTAssertEqual(MatchPhase.firstHalf.displayText, "1st Half")
        XCTAssertEqual(MatchPhase.halfTimeBreak.displayText, "Half Time")
        XCTAssertEqual(MatchPhase.secondHalf.displayText, "2nd Half")
        XCTAssertEqual(MatchPhase.fullTime.displayText, "Full Time")
        XCTAssertEqual(MatchPhase.penaltyShootout.displayText, "Penalties")
        XCTAssertEqual(MatchPhase.matchEnded.displayText, "Match Ended")
    }
    
    @available(iOS 17.2, *)
    func testMatchPhaseIsPlaying() {
        // Playing phases
        XCTAssertTrue(MatchPhase.firstHalf.isPlaying)
        XCTAssertTrue(MatchPhase.firstHalfAddedTime.isPlaying)
        XCTAssertTrue(MatchPhase.secondHalf.isPlaying)
        XCTAssertTrue(MatchPhase.secondHalfAddedTime.isPlaying)
        XCTAssertTrue(MatchPhase.extraTimeFirstHalf.isPlaying)
        XCTAssertTrue(MatchPhase.extraTimeSecondHalf.isPlaying)
        XCTAssertTrue(MatchPhase.penaltyShootout.isPlaying)
        
        // Not playing phases
        XCTAssertFalse(MatchPhase.preMatch.isPlaying)
        XCTAssertFalse(MatchPhase.halfTimeBreak.isPlaying)
        XCTAssertFalse(MatchPhase.fullTime.isPlaying)
        XCTAssertFalse(MatchPhase.matchEnded.isPlaying)
    }
    
    @available(iOS 17.2, *)
    func testMatchPhaseIsBreak() {
        XCTAssertTrue(MatchPhase.halfTimeBreak.isBreak)
        XCTAssertTrue(MatchPhase.extraTimeBreak.isBreak)
        XCTAssertTrue(MatchPhase.extraTimeHalfTimeBreak.isBreak)
        
        XCTAssertFalse(MatchPhase.firstHalf.isBreak)
        XCTAssertFalse(MatchPhase.preMatch.isBreak)
        XCTAssertFalse(MatchPhase.matchEnded.isBreak)
    }
    
    @available(iOS 17.2, *)
    func testMatchPhaseIsFinished() {
        XCTAssertTrue(MatchPhase.fullTime.isFinished)
        XCTAssertTrue(MatchPhase.matchEnded.isFinished)
        
        XCTAssertFalse(MatchPhase.preMatch.isFinished)
        XCTAssertFalse(MatchPhase.firstHalf.isFinished)
        XCTAssertFalse(MatchPhase.penaltyShootout.isFinished)
    }
    
    @available(iOS 17.2, *)
    func testMatchPhaseIsAddedTime() {
        XCTAssertTrue(MatchPhase.firstHalfAddedTime.isAddedTime)
        XCTAssertTrue(MatchPhase.secondHalfAddedTime.isAddedTime)
        XCTAssertTrue(MatchPhase.extraTimeFirstHalfAddedTime.isAddedTime)
        XCTAssertTrue(MatchPhase.extraTimeSecondHalfAddedTime.isAddedTime)
        
        XCTAssertFalse(MatchPhase.firstHalf.isAddedTime)
        XCTAssertFalse(MatchPhase.secondHalf.isAddedTime)
    }
    
    @available(iOS 17.2, *)
    func testMatchPhaseShortText() {
        XCTAssertEqual(MatchPhase.firstHalf.shortText, "1H")
        XCTAssertEqual(MatchPhase.halfTimeBreak.shortText, "HT")
        XCTAssertEqual(MatchPhase.secondHalf.shortText, "2H")
        XCTAssertEqual(MatchPhase.fullTime.shortText, "FT")
        XCTAssertEqual(MatchPhase.penaltyShootout.shortText, "PEN")
    }
    
    @available(iOS 17.2, *)
    func testMatchPhaseRawValueRoundtrip() {
        for phase in MatchPhase.allCases {
            let raw = phase.rawValue
            let decoded = MatchPhase(rawValue: raw)
            XCTAssertEqual(decoded, phase, "Roundtrip failed for \(phase)")
        }
    }
    
    @available(iOS 17.2, *)
    func testMatchPhaseCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for phase in MatchPhase.allCases {
            let data = try encoder.encode(phase)
            let decoded = try decoder.decode(MatchPhase.self, from: data)
            XCTAssertEqual(decoded, phase)
        }
    }
    
    // ContentState Tests
    
    @available(iOS 17.2, *)
    func testContentStateScoreDisplay() {
        let state = MatchActivityAttributes.ContentState(
            homeScore: 2,
            awayScore: 1,
            phase: .secondHalf,
            matchMinute: "67"
        )
        
        XCTAssertEqual(state.scoreDisplay, "2 : 1")
        XCTAssertEqual(state.scoreCompact, "2:1")
    }
    
    @available(iOS 17.2, *)
    func testContentStatePhaseProperty() {
        let state = MatchActivityAttributes.ContentState(
            homeScore: 0,
            awayScore: 0,
            matchPhase: "FIRST_HALF",
            matchMinute: "12"
        )
        
        XCTAssertEqual(state.phase, .firstHalf)
        XCTAssertEqual(state.phaseDisplayText, "1st Half")
    }
    
    @available(iOS 17.2, *)
    func testContentStateUnknownPhase() {
        let state = MatchActivityAttributes.ContentState(
            homeScore: 0,
            awayScore: 0,
            matchPhase: "UNKNOWN_PHASE",
            matchMinute: "0"
        )
        
        XCTAssertNil(state.phase)
        XCTAssertEqual(state.phaseDisplayText, "UNKNOWN_PHASE")
    }
    
    @available(iOS 17.2, *)
    func testContentStateCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let state = MatchActivityAttributes.ContentState(
            homeScore: 3,
            awayScore: 2,
            phase: .penaltyShootout,
            matchMinute: "120+3"
        )
        
        let data = try encoder.encode(state)
        let decoded = try decoder.decode(MatchActivityAttributes.ContentState.self, from: data)
        
        XCTAssertEqual(decoded.homeScore, 3)
        XCTAssertEqual(decoded.awayScore, 2)
        XCTAssertEqual(decoded.matchPhase, "PENALTY_SHOOTOUT")
        XCTAssertEqual(decoded.matchMinute, "120+3")
        XCTAssertNil(decoded.startDate)
    }
    
    @available(iOS 17.2, *)
    func testContentStateWithStartDate() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let date = Date(timeIntervalSince1970: 1700000000)
        let state = MatchActivityAttributes.ContentState(
            homeScore: 0,
            awayScore: 0,
            phase: .preMatch,
            matchMinute: "0",
            startDate: date
        )
        
        let data = try encoder.encode(state)
        let decoded = try decoder.decode(MatchActivityAttributes.ContentState.self, from: data)
        
        XCTAssertNotNil(decoded.startDate)
        XCTAssertEqual(decoded.startDate?.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 1)
    }
    
    // MatchActivityAttributes Tests
    
    @available(iOS 17.2, *)
    func testMatchActivityAttributesInit() {
        let attrs = MatchActivityAttributes(
            matchId: "match-123",
            homeTeamName: "Brazil",
            awayTeamName: "Germany",
            homeTeamBadgeUrl: "https://example.com/brazil.png",
            awayTeamBadgeUrl: "https://example.com/germany.png",
            deepLink: "myapp://match/123",
            ctaText: "Stats",
            ctaDeepLink: "myapp://match/123/stats"
        )
        
        XCTAssertEqual(attrs.matchId, "match-123")
        XCTAssertEqual(attrs.homeTeamName, "Brazil")
        XCTAssertEqual(attrs.awayTeamName, "Germany")
        XCTAssertEqual(attrs.homeTeamBadgeUrl, "https://example.com/brazil.png")
        XCTAssertEqual(attrs.awayTeamBadgeUrl, "https://example.com/germany.png")
        XCTAssertEqual(attrs.deepLink, "myapp://match/123")
        XCTAssertEqual(attrs.ctaText, "Stats")
        XCTAssertEqual(attrs.ctaDeepLink, "myapp://match/123/stats")
    }
    
    @available(iOS 17.2, *)
    func testMatchActivityAttributesMinimalInit() {
        let attrs = MatchActivityAttributes(
            matchId: "match-456",
            homeTeamName: "Team A",
            awayTeamName: "Team B"
        )
        
        XCTAssertEqual(attrs.matchId, "match-456")
        XCTAssertNil(attrs.homeTeamBadgeUrl)
        XCTAssertNil(attrs.awayTeamBadgeUrl)
        XCTAssertNil(attrs.deepLink)
        XCTAssertNil(attrs.ctaText)
        XCTAssertNil(attrs.ctaDeepLink)
    }
    
    // LiveActivityEventType Tests
    
    @available(iOS 17.2, *)
    func testLiveActivityEventTypeRawValues() {
        XCTAssertEqual(LiveActivityEventType.started.rawValue, "la.started")
        XCTAssertEqual(LiveActivityEventType.updated.rawValue, "la.updated")
        XCTAssertEqual(LiveActivityEventType.ctaClicked.rawValue, "la.cta_clicked")
        XCTAssertEqual(LiveActivityEventType.ended.rawValue, "la.ended")
        XCTAssertEqual(LiveActivityEventType.dismissed.rawValue, "la.dismissed")
        XCTAssertEqual(LiveActivityEventType.pushTokenRegistered.rawValue, "la.push_token_registered")
    }
    
    // LiveActivityDismissPolicy Tests
    
    @available(iOS 17.2, *)
    func testDismissPolicyCases() {
        let _ = LiveActivityDismissPolicy.immediate
        let _ = LiveActivityDismissPolicy.after(Date())
        let _ = LiveActivityDismissPolicy.default
    }
    
    @available(iOS 17.2, *)
    func testDismissPolicyToSystemPolicy() {
        // .immediate maps to .immediate
        let immediatePolicy = LiveActivityDismissPolicy.immediate.toSystemPolicy()
        XCTAssertNotNil(immediatePolicy)
        
        // .default maps to .default
        let defaultPolicy = LiveActivityDismissPolicy.default.toSystemPolicy()
        XCTAssertNotNil(defaultPolicy)
        
        // .after(Date) maps to .after(Date)
        let date = Date()
        let afterPolicy = LiveActivityDismissPolicy.after(date).toSystemPolicy()
        XCTAssertNotNil(afterPolicy)
    }
    
    // MatchPhase Color Tests
    
    @available(iOS 17.2, *)
    func testMatchPhaseColor() {
        // Playing phases should be green
        XCTAssertEqual(MatchPhase.firstHalf.color, .green)
        XCTAssertEqual(MatchPhase.secondHalf.color, .green)
        XCTAssertEqual(MatchPhase.penaltyShootout.color, .green)
        
        // Break phases should be yellow
        XCTAssertEqual(MatchPhase.halfTimeBreak.color, .yellow)
        XCTAssertEqual(MatchPhase.extraTimeBreak.color, .yellow)
        
        // Finished phases should be secondary
        XCTAssertEqual(MatchPhase.fullTime.color, .secondary)
        XCTAssertEqual(MatchPhase.matchEnded.color, .secondary)
        
        // Pre-match should be primary
        XCTAssertEqual(MatchPhase.preMatch.color, .primary)
    }
    
    // LiveActivityInfo Tests
    
    @available(iOS 17.2, *)
    func testLiveActivityInfoInit() {
        let date = Date()
        let info = LiveActivityInfo(
            activityId: "act-1",
            templateId: "match",
            pushToken: "abc123",
            startedAt: date
        )
        
        XCTAssertEqual(info.activityId, "act-1")
        XCTAssertEqual(info.templateId, "match")
        XCTAssertEqual(info.pushToken, "abc123")
        XCTAssertEqual(info.startedAt, date)
    }
    
    @available(iOS 17.2, *)
    func testLiveActivityInfoNilToken() {
        let info = LiveActivityInfo(
            activityId: "act-2",
            templateId: "match",
            pushToken: nil,
            startedAt: Date()
        )
        
        XCTAssertNil(info.pushToken)
    }
    
    // Observer Model Tests
    
    @available(iOS 17.2, *)
    func testObserveRequestCodable() throws {
        let request = ObserveRequest(
            campaignId: "camp-1",
            templateId: "match",
            pushToStartToken: "abc123",
            subscriberId: "sub-1",
            supportsChannels: true
        )
        
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(ObserveRequest.self, from: data)
        
        XCTAssertEqual(decoded.campaignId, "camp-1")
        XCTAssertEqual(decoded.templateId, "match")
        XCTAssertEqual(decoded.pushToStartToken, "abc123")
        XCTAssertEqual(decoded.subscriberId, "sub-1")
        XCTAssertTrue(decoded.supportsChannels)
    }
    
    @available(iOS 17.2, *)
    func testObserveResponseCodable() throws {
        let json = """
        {"status": "live", "channelId": "ch-abc123"}
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(ObserveResponse.self, from: json)
        XCTAssertEqual(response.status, "live")
        XCTAssertEqual(response.channelId, "ch-abc123")
    }
    
    @available(iOS 17.2, *)
    func testObserveResponseWithoutChannel() throws {
        let json = """
        {"status": "scheduled", "channelId": null}
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(ObserveResponse.self, from: json)
        XCTAssertEqual(response.status, "scheduled")
        XCTAssertNil(response.channelId)
    }
    
    @available(iOS 17.2, *)
    func testObserverErrorCases() {
        let error1 = LiveActivityObserverError.activitiesNotEnabled
        XCTAssertNotNil(error1)
        
        let error2 = LiveActivityObserverError.pushToStartTokenUnavailable
        XCTAssertNotNil(error2)
        
        let error3 = LiveActivityObserverError.campaignUnavailable
        XCTAssertNotNil(error3)
    }
    
    // Backend DTO Codable Tests
    
    @available(iOS 17.2, *)
    func testPPGColorBasicCodable() throws {
        let json = "{\"type\":\"BASIC\",\"hex\":\"#FF5733\"}".data(using: .utf8)!
        let color = try JSONDecoder().decode(PPGColor.self, from: json)
        if case .basic(let hex) = color {
            XCTAssertEqual(hex, "#FF5733")
        } else {
            XCTFail("Expected .basic")
        }
    }
    
    @available(iOS 17.2, *)
    func testPPGColorGradientCodable() throws {
        let json = "{\"type\":\"GRADIENT\",\"fromHex\":\"#000\",\"toHex\":\"#FFF\",\"direction\":\"LEFT_TO_RIGHT\"}".data(using: .utf8)!
        let color = try JSONDecoder().decode(PPGColor.self, from: json)
        if case .gradient(let from, let to, let dir) = color {
            XCTAssertEqual(from, "#000")
            XCTAssertEqual(to, "#FFF")
            XCTAssertEqual(dir, .leftToRight)
        } else {
            XCTFail("Expected .gradient")
        }
    }
    
    @available(iOS 17.2, *)
    func testPPGBasicColorSetCodable() throws {
        let jsonString = """
        {
          "lightMode": {"type":"BASIC","hex":"#FFFFFF"},
          "darkMode":  {"type":"BASIC","hex":"#000000"}
        }
        """
        let json = jsonString.data(using: .utf8)!
        let set = try JSONDecoder().decode(PPGBasicColorSet.self, from: json)
        XCTAssertEqual(set.lightMode, "#FFFFFF")
        XCTAssertEqual(set.darkMode, "#000000")
    }
    
    @available(iOS 17.2, *)
    func testPPGLiveActivityActionUrlCodable() throws {
        let jsonString = """
        {
          "type": "URL",
          "name": "Stats",
          "url": "https://example.com",
          "design": {
            "ios": {
              "alignment": "CENTER",
              "borderRadius": 8,
              "textColor":       {"lightMode":{"type":"BASIC","hex":"#FFF"},"darkMode":{"type":"BASIC","hex":"#FFF"}},
              "backgroundColor": {"lightMode":{"type":"BASIC","hex":"#000"},"darkMode":{"type":"BASIC","hex":"#000"}},
              "border": null
            }
          }
        }
        """
        let json = jsonString.data(using: .utf8)!
        let action = try JSONDecoder().decode(PPGLiveActivityAction.self, from: json)
        if case .url(let name, let url, _) = action {
            XCTAssertEqual(name, "Stats")
            XCTAssertEqual(url, "https://example.com")
        } else {
            XCTFail("Expected .url action")
        }
    }
    
    @available(iOS 17.2, *)
    func testPPGFootballMatchLiveDataCodable() throws {
        let json = "{\"type\":\"FOOTBALL_MATCH_TRACKING\",\"homeTeamScore\":2,\"awayTeamScore\":1,\"status\":\"SECOND_HALF\"}".data(using: .utf8)!
        let live = try JSONDecoder().decode(PPGFootballMatchLiveData.self, from: json)
        XCTAssertEqual(live.homeTeamScore, 2)
        XCTAssertEqual(live.awayTeamScore, 1)
        XCTAssertEqual(live.status, .secondHalf)
    }
    
    @available(iOS 17.2, *)
    func testPPGFootballMatchConfigurationLookupHelpers() {
        let content = PPGFootballMatchContent(
            title: "Bayern vs Dortmund",
            homeTeamName: "Bayern",
            homeTeamImage: "https://example.com/h.png",
            awayTeamName: "Dortmund",
            awayTeamImage: "https://example.com/a.png"
        )
        let ios = PPGFootballMatchIOSDesign(statusBackgrounds: [
            "PRE_MATCH": PPGColorSet(.basic(hex: "#111")),
            "OTHER":     PPGColorSet(.basic(hex: "#333"))
        ])
        let android = PPGFootballMatchAndroidDesign(
            hasTrackerIcon: true,
            progressBarColor: PPGBasicColorSet("#000"),
            breakTimeBarColor: nil
        )
        let config = PPGFootballMatchConfiguration(
            content: content,
            design: PPGFootballMatchDesign(android: android, ios: ios),
            statusLabels: ["PRE_MATCH": "Przed meczem", "OTHER": "—"],
            actions: [],
            timeout: PPGLiveActivityTimeout(minutes: 150)
        )
        
        // Direct hit
        XCTAssertEqual(config.label(for: .preMatch), "Przed meczem")
        // OTHER fallback for missing status
        XCTAssertEqual(config.label(for: .penaltyShootout), "—")
        // Background — direct hit
        XCTAssertNotNil(config.background(for: .preMatch))
        // Background — OTHER fallback
        XCTAssertNotNil(config.background(for: .secondHalf))
    }
}
