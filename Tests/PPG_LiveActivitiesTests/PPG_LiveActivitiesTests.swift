//
//  PPG_LiveActivitiesTests.swift
//  Unit tests for the PPG Live Activities SDK.
//

import XCTest
import SwiftUI
@testable import PPG_LiveActivities

final class PPG_LiveActivitiesTests: XCTestCase {

    // MARK: - MatchPhase

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

    /// Static minute markers shown in the Dynamic Island compact slot for
    /// phases where the match clock is stopped.
    @available(iOS 17.2, *)
    func testMatchPhaseStaticMinuteText() {
        XCTAssertEqual(MatchPhase.halfTimeBreak.staticMinuteText, "45'")
        XCTAssertEqual(MatchPhase.fullTime.staticMinuteText, "90'")
        XCTAssertEqual(MatchPhase.extraTimeBreak.staticMinuteText, "90'")
        XCTAssertEqual(MatchPhase.extraTimeHalfTimeBreak.staticMinuteText, "105'")
        XCTAssertEqual(MatchPhase.penaltyShootout.staticMinuteText, "120'")

        // Playing phases use the live clock instead; pre/post-match show nothing.
        XCTAssertNil(MatchPhase.firstHalf.staticMinuteText)
        XCTAssertNil(MatchPhase.secondHalf.staticMinuteText)
        XCTAssertNil(MatchPhase.preMatch.staticMinuteText)
        XCTAssertNil(MatchPhase.matchEnded.staticMinuteText)
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

    // MARK: - Wire contract

    /// The APNs `attributes.statusLabels` array is mapped to phases by index
    /// in `MatchPhase.allCases` order — this test pins that order so an
    /// accidental reorder or mid-enum insertion fails loudly instead of
    /// silently shifting labels onto the wrong phases. New cases must be
    /// appended at the END (and the backend updated in lockstep).
    @available(iOS 17.2, *)
    func testMatchPhaseWireOrderIsStable() {
        XCTAssertEqual(MatchPhase.allCases.map(\.rawValue), [
            "PRE_MATCH",
            "FIRST_HALF",
            "FIRST_HALF_ADDED_TIME",
            "HALF_TIME_BREAK",
            "SECOND_HALF",
            "SECOND_HALF_ADDED_TIME",
            "FULL_TIME",
            "EXTRA_TIME_BREAK",
            "EXTRA_TIME_FIRST_HALF",
            "EXTRA_TIME_FIRST_HALF_ADDED_TIME",
            "EXTRA_TIME_HALF_TIME_BREAK",
            "EXTRA_TIME_SECOND_HALF",
            "EXTRA_TIME_SECOND_HALF_ADDED_TIME",
            "PENALTY_SHOOTOUT",
            "MATCH_ENDED",
            "OTHER",
        ])
    }

    /// `statusLabels` travels as an ordered array on the APNs wire; encoding
    /// and decoding through the ActivityKit round-trip must preserve the
    /// phase → label mapping.
    @available(iOS 17.2, *)
    func testStatusLabelsArrayRoundTrip() throws {
        let attrs = makeAttributes(statusLabels: [
            "PRE_MATCH": "Przed meczem",
            "SECOND_HALF": "2 połowa",
            "MATCH_ENDED": "Koniec",
        ])

        let data = try JSONEncoder().encode(attrs)
        let decoded = try JSONDecoder().decode(MatchActivityAttributes.self, from: data)

        XCTAssertEqual(decoded.label(for: .preMatch), "Przed meczem")
        XCTAssertEqual(decoded.label(for: .secondHalf), "2 połowa")
        XCTAssertEqual(decoded.label(for: .matchEnded), "Koniec")
        // Unset phase falls back to the built-in display text.
        XCTAssertEqual(decoded.label(for: .firstHalf), MatchPhase.firstHalf.displayText)
    }

    // MARK: - ContentState

    @available(iOS 17.2, *)
    func testContentStateScoreDisplay() {
        let state = MatchActivityAttributes.ContentState(
            homeTeamScore: 2,
            awayTeamScore: 1,
            status: .secondHalf
        )

        XCTAssertEqual(state.scoreDisplay, "2 : 1")
        XCTAssertEqual(state.scoreCompact, "2:1")
    }

    @available(iOS 17.2, *)
    func testContentStatePhaseDisplayText() {
        let state = MatchActivityAttributes.ContentState(
            homeTeamScore: 0,
            awayTeamScore: 0,
            status: .firstHalf
        )

        XCTAssertEqual(state.phaseDisplayText, "1st Half")
    }

    @available(iOS 17.2, *)
    func testContentStateCodableRoundTrip() throws {
        let changedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let state = MatchActivityAttributes.ContentState(
            homeTeamScore: 3,
            awayTeamScore: 2,
            status: .penaltyShootout,
            statusChangedAt: changedAt,
            liveDataVersion: 7
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(MatchActivityAttributes.ContentState.self, from: data)

        XCTAssertEqual(decoded.homeTeamScore, 3)
        XCTAssertEqual(decoded.awayTeamScore, 2)
        XCTAssertEqual(decoded.status, .penaltyShootout)
        XCTAssertEqual(decoded.liveDataVersion, 7)
        XCTAssertEqual(decoded.statusChangedAt!.timeIntervalSince1970,
                       changedAt.timeIntervalSince1970, accuracy: 1)
        XCTAssertNil(decoded.hotMessage)
    }

    /// Minimal backend payload — every optional field absent.
    @available(iOS 17.2, *)
    func testContentStateDecodesMinimalPayload() throws {
        let json = """
        {"homeTeamScore":0,"awayTeamScore":0,"status":"PRE_MATCH"}
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(MatchActivityAttributes.ContentState.self, from: json)

        XCTAssertEqual(state.status, .preMatch)
        XCTAssertNil(state.hotMessage)
        XCTAssertNil(state.statusChangedAt)
        XCTAssertNil(state.countdownDate)
        XCTAssertEqual(state.liveDataVersion, 0)
    }

    /// Backend sends dates either as ISO-8601 strings or epoch numbers —
    /// both must decode.
    @available(iOS 17.2, *)
    func testContentStateDecodesIsoStringDates() throws {
        let json = """
        {"homeTeamScore":1,"awayTeamScore":0,"status":"FIRST_HALF",
         "statusChangedAt":"2026-06-10T10:03:26.229Z"}
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(MatchActivityAttributes.ContentState.self, from: json)
        XCTAssertNotNil(state.statusChangedAt)

        // Without fractional seconds too.
        let json2 = """
        {"homeTeamScore":1,"awayTeamScore":0,"status":"FIRST_HALF",
         "statusChangedAt":"2026-06-10T10:03:26Z"}
        """.data(using: .utf8)!
        let state2 = try JSONDecoder().decode(MatchActivityAttributes.ContentState.self, from: json2)
        XCTAssertNotNil(state2.statusChangedAt)
    }

    @available(iOS 17.2, *)
    func testContentStateMatchClock() {
        let kickoff = Date(timeIntervalSinceNow: -10 * 60) // 10 minutes ago

        // Playing phase with statusChangedAt → clock shown.
        let playing = MatchActivityAttributes.ContentState(
            homeTeamScore: 0, awayTeamScore: 0, status: .firstHalf,
            statusChangedAt: kickoff
        )
        XCTAssertTrue(playing.showsMatchClock)
        XCTAssertNotNil(playing.matchClockStartDate)
        XCTAssertEqual(playing.matchMinuteText(), "11'")

        // Second half clock is shifted so the minute continues from 45.
        let secondHalf = MatchActivityAttributes.ContentState(
            homeTeamScore: 0, awayTeamScore: 0, status: .secondHalf,
            statusChangedAt: kickoff
        )
        XCTAssertEqual(secondHalf.matchMinuteText(), "56'")

        // Missing statusChangedAt → no clock.
        let withoutTimestamp = MatchActivityAttributes.ContentState(
            homeTeamScore: 0, awayTeamScore: 0, status: .firstHalf
        )
        XCTAssertFalse(withoutTimestamp.showsMatchClock)
        XCTAssertNil(withoutTimestamp.matchClockStartDate)

        // Breaks and penalties never show the live clock.
        let halfTime = MatchActivityAttributes.ContentState(
            homeTeamScore: 0, awayTeamScore: 0, status: .halfTimeBreak,
            statusChangedAt: kickoff
        )
        XCTAssertFalse(halfTime.showsMatchClock)
        let penalties = MatchActivityAttributes.ContentState(
            homeTeamScore: 0, awayTeamScore: 0, status: .penaltyShootout,
            statusChangedAt: kickoff
        )
        XCTAssertFalse(penalties.showsMatchClock)
    }

    @available(iOS 17.2, *)
    func testContentStateMatchMinutePrefix() {
        func state(_ status: MatchPhase) -> MatchActivityAttributes.ContentState {
            .init(homeTeamScore: 0, awayTeamScore: 0, status: status, statusChangedAt: Date())
        }
        XCTAssertEqual(state(.firstHalfAddedTime).matchMinutePrefix, "45+")
        XCTAssertEqual(state(.secondHalfAddedTime).matchMinutePrefix, "90+")
        XCTAssertEqual(state(.extraTimeFirstHalfAddedTime).matchMinutePrefix, "105+")
        XCTAssertEqual(state(.extraTimeSecondHalfAddedTime).matchMinutePrefix, "120+")
        XCTAssertNil(state(.firstHalf).matchMinutePrefix)
        XCTAssertNil(state(.halfTimeBreak).matchMinutePrefix)
    }

    @available(iOS 17.2, *)
    func testContentStateLiveDataVersionDecodesIntOrDouble() throws {
        let intJson = """
        {"homeTeamScore":0,"awayTeamScore":0,"status":"PRE_MATCH","liveDataVersion":5}
        """.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(MatchActivityAttributes.ContentState.self, from: intJson).liveDataVersion, 5)

        let doubleJson = """
        {"homeTeamScore":0,"awayTeamScore":0,"status":"PRE_MATCH","liveDataVersion":5.0}
        """.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(MatchActivityAttributes.ContentState.self, from: doubleJson).liveDataVersion, 5)
    }

    @available(iOS 17.2, *)
    func testContentStateClearingHotMessage() {
        let state = MatchActivityAttributes.ContentState(
            homeTeamScore: 2,
            awayTeamScore: 1,
            status: .secondHalf,
            hotMessage: PPGHotMessage(id: "m1", text: "GOL!", expiresAt: Date(timeIntervalSinceNow: 30)),
            statusChangedAt: Date(),
            liveDataVersion: 3
        )

        let cleared = state.clearingHotMessage()
        XCTAssertNil(cleared.hotMessage)
        // Everything else is preserved.
        XCTAssertEqual(cleared.homeTeamScore, 2)
        XCTAssertEqual(cleared.awayTeamScore, 1)
        XCTAssertEqual(cleared.status, .secondHalf)
        XCTAssertEqual(cleared.liveDataVersion, 3)
    }

    // MARK: - PPGHotMessage

    /// Wire format is `{id, text, timestamp}` where `timestamp` is the
    /// expiry as Unix epoch seconds.
    @available(iOS 17.2, *)
    func testHotMessageDecodesWireFormat() throws {
        let json = #"{"id":"msg_123","text":"Gol anulowany po VAR","timestamp":1781088180}"#.data(using: .utf8)!
        let message = try JSONDecoder().decode(PPGHotMessage.self, from: json)

        XCTAssertEqual(message.id, "msg_123")
        XCTAssertEqual(message.text, "Gol anulowany po VAR")
        XCTAssertEqual(message.expiresAt.timeIntervalSince1970, 1_781_088_180, accuracy: 1)
    }

    /// A millisecond epoch (e.g. JS `Date.now()`) is normalized to seconds.
    @available(iOS 17.2, *)
    func testHotMessageNormalizesMillisecondEpoch() throws {
        let json = #"{"id":"m","text":"x","timestamp":1781088180000}"#.data(using: .utf8)!
        let message = try JSONDecoder().decode(PPGHotMessage.self, from: json)
        XCTAssertEqual(message.expiresAt.timeIntervalSince1970, 1_781_088_180, accuracy: 1)
    }

    /// Missing optional wire fields fall back to sane defaults.
    @available(iOS 17.2, *)
    func testHotMessageDecodesWithoutOptionalFields() throws {
        let json = #"{"text":"Penalty!"}"#.data(using: .utf8)!
        let message = try JSONDecoder().decode(PPGHotMessage.self, from: json)

        XCTAssertEqual(message.text, "Penalty!")
        XCTAssertFalse(message.id.isEmpty)
        // Default expiry ≈ now + maxDisplayDuration.
        XCTAssertEqual(message.expiresAt.timeIntervalSinceNow,
                       PPGHotMessage.maxDisplayDuration, accuracy: 2)
    }

    /// Effective visibility end = min(receivedAt + 10 s, expiresAt).
    @available(iOS 17.2, *)
    func testHotMessageEndDate() {
        let receivedAt = Date()

        // expiresAt far in the future → local 10 s cap wins.
        let longLived = PPGHotMessage(id: "a", text: "x", expiresAt: receivedAt.addingTimeInterval(3600))
        XCTAssertEqual(longLived.endDate(receivedAt: receivedAt),
                       receivedAt.addingTimeInterval(PPGHotMessage.maxDisplayDuration))

        // expiresAt sooner than the cap → backend cutoff wins.
        let shortLived = PPGHotMessage(id: "b", text: "x", expiresAt: receivedAt.addingTimeInterval(3))
        XCTAssertEqual(shortLived.endDate(receivedAt: receivedAt),
                       receivedAt.addingTimeInterval(3))
    }

    @available(iOS 17.2, *)
    func testContentStateWithHotMessageRoundTrip() throws {
        let state = MatchActivityAttributes.ContentState(
            homeTeamScore: 2,
            awayTeamScore: 1,
            status: .secondHalf,
            hotMessage: PPGHotMessage(id: "m1", text: "GOL!", expiresAt: Date(timeIntervalSinceNow: 30))
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(MatchActivityAttributes.ContentState.self, from: data)

        XCTAssertEqual(decoded.hotMessage?.id, "m1")
        XCTAssertEqual(decoded.hotMessage?.text, "GOL!")
    }

    /// A malformed `hotMessage` must not fail the whole ContentState decode —
    /// the banner is dropped, the score still renders.
    @available(iOS 17.2, *)
    func testContentStateToleratesMalformedHotMessage() throws {
        let json = """
        {"homeTeamScore":1,"awayTeamScore":0,"status":"FIRST_HALF","hotMessage":{"bogus":true}}
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(MatchActivityAttributes.ContentState.self, from: json)
        XCTAssertNil(state.hotMessage)
        XCTAssertEqual(state.homeTeamScore, 1)
    }

    // MARK: - HotMessageStore

    @available(iOS 17.2, *)
    func testHotMessageStoreReturnsStableReceivedAtForSameId() {
        let suiteName = "test.ppg.hotmessagestore.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        HotMessageStore.shared.configure(appGroupId: suiteName)

        let first = HotMessageStore.shared.receivedAt(activityID: "A", hotMessageId: "msg_1")
        Thread.sleep(forTimeInterval: 0.05)
        let second = HotMessageStore.shared.receivedAt(activityID: "A", hotMessageId: "msg_1")

        XCTAssertEqual(first.timeIntervalSince1970, second.timeIntervalSince1970, accuracy: 0.001,
                       "Same (activityID, hotMessageId) must return the same timestamp across calls")
    }

    @available(iOS 17.2, *)
    func testHotMessageStoreResetsOnNewHotMessageId() {
        let suiteName = "test.ppg.hotmessagestore.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        HotMessageStore.shared.configure(appGroupId: suiteName)

        let first = HotMessageStore.shared.receivedAt(activityID: "A", hotMessageId: "msg_1")
        Thread.sleep(forTimeInterval: 0.05)
        let second = HotMessageStore.shared.receivedAt(activityID: "A", hotMessageId: "msg_2")

        XCTAssertGreaterThan(second.timeIntervalSince1970, first.timeIntervalSince1970,
                             "A new hotMessageId must reset the receivedAt timestamp")
    }

    @available(iOS 17.2, *)
    func testHotMessageStoreIsolatesAcrossActivities() {
        let suiteName = "test.ppg.hotmessagestore.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        HotMessageStore.shared.configure(appGroupId: suiteName)

        let activityA = HotMessageStore.shared.receivedAt(activityID: "A", hotMessageId: "msg_1")
        Thread.sleep(forTimeInterval: 0.05)
        let activityB = HotMessageStore.shared.receivedAt(activityID: "B", hotMessageId: "msg_1")

        XCTAssertGreaterThan(activityB.timeIntervalSince1970, activityA.timeIntervalSince1970,
                             "Different activityIDs must have independent timestamps even for the same hotMessageId")

        // Re-reading A must still return the original timestamp
        let activityAAgain = HotMessageStore.shared.receivedAt(activityID: "A", hotMessageId: "msg_1")
        XCTAssertEqual(activityA.timeIntervalSince1970, activityAAgain.timeIntervalSince1970, accuracy: 0.001)
    }

    @available(iOS 17.2, *)
    func testHotMessageStoreClearRemovesEntry() {
        let suiteName = "test.ppg.hotmessagestore.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        HotMessageStore.shared.configure(appGroupId: suiteName)

        let first = HotMessageStore.shared.receivedAt(activityID: "A", hotMessageId: "msg_1")
        HotMessageStore.shared.clear(activityID: "A")
        Thread.sleep(forTimeInterval: 0.05)
        let afterClear = HotMessageStore.shared.receivedAt(activityID: "A", hotMessageId: "msg_1")

        XCTAssertGreaterThan(afterClear.timeIntervalSince1970, first.timeIntervalSince1970,
                             "After clear, the next call must produce a fresh timestamp")
    }

    // MARK: - MatchActivityAttributes

    @available(iOS 17.2, *)
    private func makeAttributes(
        liveNotificationId: String = "match-123",
        homeTeamName: String = "Brazil",
        awayTeamName: String = "Germany",
        homeTeamImage: String? = "https://example.com/brazil.png",
        awayTeamImage: String? = "https://example.com/germany.png",
        title: String = "World Cup Final",
        statusLabels: [String: String] = [:],
        actionSet: [PPGLiveActivityAction] = [],
        url: String? = nil
    ) -> MatchActivityAttributes {
        MatchActivityAttributes(
            liveNotificationId: liveNotificationId,
            content: PPGFootballMatchContent(
                title: title,
                homeTeamName: homeTeamName,
                homeTeamImage: homeTeamImage,
                awayTeamName: awayTeamName,
                awayTeamImage: awayTeamImage
            ),
            design: PPGFootballMatchDesign(
                ios: PPGFootballMatchIOSDesign(statusBackground: nil)
            ),
            statusLabels: statusLabels,
            actionSet: actionSet,
            timeout: PPGLiveActivityTimeout(minutes: 180),
            url: url
        )
    }

    @available(iOS 17.2, *)
    private func makeUrlAction(name: String = "Stats", url: String = "https://example.com/stats") -> PPGLiveActivityAction {
        let appearance = PPGActionIOSAppearance(
            textColor: .basic(hex: "#FFF"),
            backgroundColor: .basic(hex: "#000"),
            border: nil
        )
        return .url(
            name: name,
            url: url,
            design: PPGActionDesign(ios: PPGActionIOSDesign(
                alignment: .center,
                borderRadius: 8,
                appearance: PPGActionIOSAppearanceSet(lightMode: appearance, darkMode: appearance)
            ))
        )
    }

    @available(iOS 17.2, *)
    func testMatchActivityAttributesInit() {
        let attrs = makeAttributes(
            liveNotificationId: "match-123",
            homeTeamName: "Brazil",
            awayTeamName: "Germany",
            actionSet: [makeUrlAction(name: "Stats", url: "myapp://match/123/stats")]
        )

        XCTAssertEqual(attrs.liveNotificationId, "match-123")
        XCTAssertEqual(attrs.homeTeamName, "Brazil")
        XCTAssertEqual(attrs.awayTeamName, "Germany")
        XCTAssertEqual(attrs.homeTeamBadgeUrl, "https://example.com/brazil.png")
        XCTAssertEqual(attrs.awayTeamBadgeUrl, "https://example.com/germany.png")
        XCTAssertNil(attrs.deepLink)
        XCTAssertEqual(attrs.ctaText, "Stats")
        XCTAssertEqual(attrs.ctaDeepLink, "myapp://match/123/stats")
    }

    @available(iOS 17.2, *)
    func testMatchActivityAttributesMinimalInit() {
        let attrs = makeAttributes(
            liveNotificationId: "match-456",
            homeTeamName: "Team A",
            awayTeamName: "Team B",
            homeTeamImage: nil,
            awayTeamImage: nil
        )

        XCTAssertEqual(attrs.liveNotificationId, "match-456")
        XCTAssertNil(attrs.homeTeamBadgeUrl)
        XCTAssertNil(attrs.awayTeamBadgeUrl)
        XCTAssertNil(attrs.deepLink)
        XCTAssertNil(attrs.ctaText)
        XCTAssertNil(attrs.ctaDeepLink)
        XCTAssertTrue(attrs.actionSet.isEmpty)
    }

    @available(iOS 17.2, *)
    func testMatchActivityAttributesEmptyLabelsAndBackgroundsFallbacks() {
        let attrs = makeAttributes(
            liveNotificationId: "m1",
            homeTeamName: "A",
            awayTeamName: "B",
            title: "",
            statusLabels: [:]
        )

        // No statusLabels → fall back to MatchPhase.displayText
        XCTAssertEqual(attrs.label(for: .firstHalf), MatchPhase.firstHalf.displayText)
        // No statusBackground → nil (widgets use system default)
        XCTAssertNil(attrs.background(for: .firstHalf))
        XCTAssertTrue(attrs.actionSet.isEmpty)
        XCTAssertEqual(attrs.title, "")
    }

    // Empty-string image URL → nil (no image)

    @available(iOS 17.2, *)
    func testEmptyBadgeImageUrlNormalizedToNil() {
        let attrs = makeAttributes(
            liveNotificationId: "m-empty",
            homeTeamName: "A",
            awayTeamName: "B",
            homeTeamImage: "",
            awayTeamImage: "   "
        )
        XCTAssertNil(attrs.homeTeamBadgeUrl)
        XCTAssertNil(attrs.awayTeamBadgeUrl)
    }

    /// Attributes decoding must accept the alternative wire names for the id
    /// (`id` / `notificationId`) and default `statusLabels` / `actionSet`
    /// when absent.
    @available(iOS 17.2, *)
    func testAttributesDecodeTolerance() throws {
        let json = """
        {
          "id": "la_alias",
          "content": {"title":"t","homeTeamName":"A","awayTeamName":"B"},
          "design": {"ios":{}},
          "timeout": {"minutes": 60}
        }
        """.data(using: .utf8)!

        let attrs = try JSONDecoder().decode(MatchActivityAttributes.self, from: json)
        XCTAssertEqual(attrs.liveNotificationId, "la_alias")
        XCTAssertTrue(attrs.actionSet.isEmpty)
        XCTAssertTrue(attrs.statusLabels.isEmpty)
    }

    /// Badge image URLs from the attributes payload feed the automatic
    /// prefetch on push-to-start.
    @available(iOS 17.2, *)
    func testAttributesImagePrefetchable() {
        let attrs = makeAttributes(liveNotificationId: "camp-9")

        XCTAssertEqual(attrs.imageCampaignId, "camp-9")
        XCTAssertEqual(attrs.prefetchableImages[.homeTeamBadge], "https://example.com/brazil.png")
        XCTAssertEqual(attrs.prefetchableImages[.awayTeamBadge], "https://example.com/germany.png")

        let noImages = makeAttributes(homeTeamImage: nil, awayTeamImage: "")
        XCTAssertTrue(noImages.prefetchableImages.isEmpty)
    }

    // MARK: - Backend DTO mapping

    @available(iOS 17.2, *)
    private func makeDTO(
        config: PPGFootballMatchConfiguration,
        liveData: PPGFootballMatchLiveData,
        lifecycle: PPGLiveActivityLifecycleStatus = .ongoing,
        scheduledAt: Date = Date(timeIntervalSince1970: 1_713_724_200),
        countdown: PPGLiveActivityCountdown? = nil
    ) -> PPGLiveNotificationDTO {
        PPGLiveNotificationDTO(
            id: "la_abc123",
            projectId: "proj_xyz",
            template: .footballMatchTracking,
            name: "Bayern vs Dortmund",
            configuration: .footballMatchTracking(config),
            liveData: .footballMatchTracking(liveData),
            lifecycle: PPGLiveNotificationLifecycle(status: lifecycle),
            startPolicy: PPGLiveActivityStartPolicy(scheduledAt: scheduledAt, countdown: countdown),
            metadata: PPGLiveNotificationMetadata(createdBy: "user_1"),
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil
        )
    }

    @available(iOS 17.2, *)
    func testMatchActivityAttributesFromDTO() {
        let config = PPGFootballMatchConfiguration(
            content: PPGFootballMatchContent(
                title: "Bundesliga",
                homeTeamName: "Bayern",
                homeTeamImage: "https://cdn.ppg.com/h.png",
                awayTeamName: "Dortmund",
                awayTeamImage: "https://cdn.ppg.com/a.png"
            ),
            design: PPGFootballMatchDesign(
                ios: PPGFootballMatchIOSDesign(statusBackground: PPGColorSet(.basic(hex: "#FFF")))
            ),
            statusLabels: ["PRE_MATCH": "Przed meczem"],
            actions: [makeUrlAction(name: "Statystyki", url: "https://example.com/stats")],
            timeout: PPGLiveActivityTimeout(minutes: 180),
            url: "https://example.com/match"
        )
        let changedAt = Date(timeIntervalSince1970: 1_713_725_000)
        let dto = makeDTO(
            config: config,
            liveData: PPGFootballMatchLiveData(
                homeTeamScore: 1,
                awayTeamScore: 0,
                status: .firstHalf,
                statusChangedAt: changedAt
            )
        )

        guard let result = MatchActivityAttributes.from(dto: dto) else {
            XCTFail("Mapping failed")
            return
        }

        // Attributes
        XCTAssertEqual(result.attributes.liveNotificationId, "la_abc123")
        XCTAssertEqual(result.attributes.homeTeamName, "Bayern")
        XCTAssertEqual(result.attributes.awayTeamName, "Dortmund")
        XCTAssertEqual(result.attributes.homeTeamBadgeUrl, "https://cdn.ppg.com/h.png")
        XCTAssertEqual(result.attributes.awayTeamBadgeUrl, "https://cdn.ppg.com/a.png")
        XCTAssertEqual(result.attributes.deepLink, "https://example.com/match")

        // First URL action promoted to CTA
        XCTAssertEqual(result.attributes.ctaText, "Statystyki")
        XCTAssertEqual(result.attributes.ctaDeepLink, "https://example.com/stats")

        // Config-aware helpers
        XCTAssertEqual(result.attributes.label(for: .preMatch), "Przed meczem")
        XCTAssertEqual(result.attributes.title, "Bundesliga")
        XCTAssertEqual(result.attributes.actionSet.count, 1)
        XCTAssertNotNil(result.attributes.background(for: .preMatch))

        // No countdown configured → no countdown fields
        XCTAssertNil(result.attributes.countdownDate)
        XCTAssertNil(result.attributes.countdownMessage)

        // Initial ContentState mirrors liveData
        XCTAssertEqual(result.initialState.homeTeamScore, 1)
        XCTAssertEqual(result.initialState.awayTeamScore, 0)
        XCTAssertEqual(result.initialState.status, .firstHalf)
        XCTAssertEqual(result.initialState.statusChangedAt!.timeIntervalSince1970,
                       changedAt.timeIntervalSince1970, accuracy: 1)
    }

    @available(iOS 17.2, *)
    func testCountdownPropagatedFromDTO() {
        let config = PPGFootballMatchConfiguration(
            content: PPGFootballMatchContent(
                title: "Bundesliga",
                homeTeamName: "Bayern",
                homeTeamImage: nil,
                awayTeamName: "Dortmund",
                awayTeamImage: nil
            ),
            design: PPGFootballMatchDesign(ios: PPGFootballMatchIOSDesign(statusBackground: nil)),
            statusLabels: [:],
            actions: [],
            timeout: PPGLiveActivityTimeout(minutes: 180)
        )
        let scheduledAt = Date(timeIntervalSinceNow: 900)
        let dto = makeDTO(
            config: config,
            liveData: PPGFootballMatchLiveData(homeTeamScore: 0, awayTeamScore: 0, status: .preMatch),
            lifecycle: .pending,
            scheduledAt: scheduledAt,
            countdown: PPGLiveActivityCountdown(message: "Mecz rozpoczyna się za", seconds: 900)
        )

        guard let result = MatchActivityAttributes.from(dto: dto) else {
            XCTFail("Expected mapping to succeed")
            return
        }
        XCTAssertEqual(result.attributes.countdownMessage, "Mecz rozpoczyna się za")
        XCTAssertEqual(result.attributes.countdownDate!.timeIntervalSince1970,
                       scheduledAt.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(result.initialState.countdownMessage, "Mecz rozpoczyna się za")
        XCTAssertNotNil(result.initialState.countdownDate)
    }

    // MARK: - Color DTOs

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
    func testPPGColorBasicWithoutTypeDiscriminator() throws {
        let json = "{\"hex\":\"#AABBCC\"}".data(using: .utf8)!
        let color = try JSONDecoder().decode(PPGColor.self, from: json)
        guard case .basic(let hex) = color else {
            XCTFail("Expected .basic")
            return
        }
        XCTAssertEqual(hex, "#AABBCC")
    }

    @available(iOS 17.2, *)
    func testPPGColorGradientWithoutTypeDiscriminator() throws {
        let json = """
        {"fromHex":"#000","toHex":"#FFF","direction":"TOP_TO_BOTTOM"}
        """.data(using: .utf8)!
        let color = try JSONDecoder().decode(PPGColor.self, from: json)
        guard case .gradient(let from, let to, let dir) = color else {
            XCTFail("Expected .gradient")
            return
        }
        XCTAssertEqual(from, "#000")
        XCTAssertEqual(to, "#FFF")
        XCTAssertEqual(dir, .topToBottom)
    }

    @available(iOS 17.2, *)
    func testPPGColorGradientDefaultsDirectionWhenMissing() throws {
        // Direction is optional; default top-to-bottom.
        let json = "{\"fromHex\":\"#000\",\"toHex\":\"#FFF\"}".data(using: .utf8)!
        let color = try JSONDecoder().decode(PPGColor.self, from: json)
        guard case .gradient(_, _, let dir) = color else {
            XCTFail("Expected .gradient")
            return
        }
        XCTAssertEqual(dir, .topToBottom)
    }

    @available(iOS 17.2, *)
    func testPPGBasicColorSetWithoutTypeDiscriminator() throws {
        let json = """
        { "lightMode": {"hex":"#FFFFFF"}, "darkMode": {"hex":"#000000"} }
        """.data(using: .utf8)!
        let set = try JSONDecoder().decode(PPGBasicColorSet.self, from: json)
        XCTAssertEqual(set.lightMode, "#FFFFFF")
        XCTAssertEqual(set.darkMode, "#000000")
    }

    // MARK: - Action / live-data DTOs

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
              "appearance": {
                "lightMode": {"textColor": {"type":"BASIC","hex":"#FFF"}, "backgroundColor": {"type":"BASIC","hex":"#000"}, "border": null},
                "darkMode":  {"textColor": {"type":"BASIC","hex":"#FFF"}, "backgroundColor": {"type":"BASIC","hex":"#000"}, "border": null}
              }
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
        let ios = PPGFootballMatchIOSDesign(statusBackground: PPGColorSet(.basic(hex: "#111")))
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

    // MARK: - DTO decoding helper

    /// `PPGLiveNotificationDTO.decode(from:)` must parse backend dates with
    /// and without fractional seconds.
    @available(iOS 17.2, *)
    func testLiveNotificationDTODecodeHelper() throws {
        let json = """
        {
          "id": "6a29366e87e86dc31cdec02d",
          "projectId": "p1",
          "template": "FOOTBALL_MATCH_TRACKING",
          "name": "QA match",
          "configuration": {
            "type": "FOOTBALL_MATCH_TRACKING",
            "content": {"title":"t","homeTeamName":"A","awayTeamName":"B"},
            "design": {"ios": {"statusBackground": null}},
            "statusLabels": {},
            "actions": [],
            "timeout": {"minutes": 480}
          },
          "liveData": {
            "type": "FOOTBALL_MATCH_TRACKING",
            "homeTeamScore": 0,
            "awayTeamScore": 0,
            "status": "PRE_MATCH",
            "statusChangedAt": "2026-06-10T10:03:26.229Z"
          },
          "lifecycle": {"status": "PENDING"},
          "startPolicy": {"scheduledAt": "2026-06-10T10:06:00Z", "countdown": null},
          "metadata": {"createdBy": "qa"},
          "createdAt": "2026-06-10T10:03:26.425Z",
          "updatedAt": "2026-06-10T10:03:26.425Z",
          "deletedAt": null
        }
        """.data(using: .utf8)!

        let dto = try PPGLiveNotificationDTO.decode(from: json)
        XCTAssertEqual(dto.id, "6a29366e87e86dc31cdec02d")
        XCTAssertEqual(dto.lifecycle.status, .pending)
        XCTAssertEqual(dto.footballMatchLiveData?.status, .preMatch)
        XCTAssertNotNil(MatchActivityAttributes.from(dto: dto))
    }

    // MARK: - Misc model types

    @available(iOS 17.2, *)
    func testLiveActivityEventTypeRawValues() {
        XCTAssertEqual(LiveActivityEventType.started.rawValue, "la.started")
        XCTAssertEqual(LiveActivityEventType.updated.rawValue, "la.updated")
        XCTAssertEqual(LiveActivityEventType.ctaClicked.rawValue, "la.cta_clicked")
        XCTAssertEqual(LiveActivityEventType.ended.rawValue, "la.ended")
        XCTAssertEqual(LiveActivityEventType.dismissed.rawValue, "la.dismissed")
        XCTAssertEqual(LiveActivityEventType.pushTokenRegistered.rawValue, "la.push_token_registered")
    }

    @available(iOS 17.2, *)
    func testStatisticsEventTypeRawValues() {
        XCTAssertEqual(PPGLiveNotificationStatisticsEventType.started.rawValue, "started")
        XCTAssertEqual(PPGLiveNotificationStatisticsEventType.closed.rawValue, "closed")
        XCTAssertEqual(PPGLiveNotificationStatisticsEventType.clicked.rawValue, "clicked")
        XCTAssertEqual(PPGLiveNotificationStatisticsEventType.clicked1.rawValue, "clicked_1")
        XCTAssertEqual(PPGLiveNotificationStatisticsEventType.clicked2.rawValue, "clicked_2")
    }

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

    // MARK: - Data helpers

    func testDataHexString() {
        XCTAssertEqual(Data([0x80, 0x56, 0x00, 0xff]).ppgHexString, "805600ff")
        XCTAssertEqual(Data().ppgHexString, "")
    }
}
