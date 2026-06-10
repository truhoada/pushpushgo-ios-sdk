//
//  MatchDynamicIslandView.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import SwiftUI
import WidgetKit
import ActivityKit

/// Pre-built Dynamic Island configuration for the football match Live Activity.
@available(iOS 17.2, *)
public struct PPGMatchDynamicIsland {
    
    let context: ActivityViewContext<MatchActivityAttributes>
    
    public init(context: ActivityViewContext<MatchActivityAttributes>) {
        self.context = context
    }
    
    private var phase: MatchPhase { context.state.status }
    
    /// Build the DynamicIsland configuration
    public func body() -> DynamicIsland {
        DynamicIsland {
            // Expanded view — Lock Screen-style layout split across two regions
            // so the title/clock occupies the otherwise-empty space beside the
            // camera (center) and the teams + score + buttons fill the large
            // bottom region without clipping.
            DynamicIslandExpandedRegion(.center) {
                expandedHeader
            }
            DynamicIslandExpandedRegion(.bottom) {
                expandedBody
            }
        } compactLeading: {
            compactLeading
        } compactTrailing: {
            compactTrailing
        } minimal: {
            minimal
        }
        .widgetURL(widgetURL)
    }
    
    // Widget URL
    
    private var widgetURL: URL? {
        LiveActivityClickURL.make(
            liveNotificationId: context.attributes.liveNotificationId,
            type: .clicked,
            liveDataVersion: context.state.liveDataVersion,
            destination: context.attributes.deepLink.flatMap(URL.init)
        )
    }
    
    // Expanded View — Lock Screen-style layout (header + body)
    
    /// Top region: hot message when present (transient, auto-hides), otherwise
    /// the title + optional live match clock. Rendered in the `.center` region
    /// so it sits beside the camera and reclaims the empty top space.
    @ViewBuilder
    private var expandedHeader: some View {
        if let hotMessage = context.state.hotMessage, !context.isStale {
            PPGHotMessageView(
                hotMessage: hotMessage,
                activityID: context.activityID,
                compact: true
            )
        } else {
            HStack(spacing: 0) {
                if context.state.showsMatchClock {
                    Color.clear.frame(width: 56)
                }
                Text(context.attributes.title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                if context.state.showsMatchClock,
                   let clockStart = context.state.matchClockStartDate {
                    clockText(clockStart: clockStart)
                        .monospacedDigit()
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                        .frame(width: 56, alignment: .trailing)
                }
            }
        }
    }
    
    /// Bottom region: teams + central score/status, then up to two action
    /// buttons below — mirrors the Lock Screen body.
    @ViewBuilder
    private var expandedBody: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                teamView(name: context.attributes.homeTeamName, imageType: .homeTeamBadge)
                centerView
                teamView(name: context.attributes.awayTeamName, imageType: .awayTeamBadge)
            }
            
            if !context.attributes.actionSet.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(context.attributes.actionSet.prefix(2).enumerated()), id: \.offset) { index, action in
                        actionButton(action, index: index)
                    }
                }
            }
        }
    }
    
    private func teamView(name: String, imageType: PPGLiveActivityImageType) -> some View {
        VStack(spacing: 3) {
            teamBadge(imageType: imageType, size: 38)
            Text(name)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(minWidth: 56, maxWidth: .infinity)
    }
    
    private var centerView: some View {
        VStack(spacing: 2) {
            let countdownDate = context.state.countdownDate ?? context.attributes.countdownDate
            if phase == .preMatch, let countdownDate {
                diCountdownTimerLarge(until: countdownDate)
            } else {
                Text(context.state.scoreDisplay)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            
            HStack(spacing: 4) {
                if phase.isPlaying {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 5, height: 5)
                }
                Text(statusLabel)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    /// Status color for the Dynamic Island: gray for in-match breaks
    /// (half time / extra-time breaks), green for every other phase.
    private var statusColor: Color {
        phase.isBreak ? .gray : .green
    }
    
    private var statusLabel: String {
        let msg = context.state.countdownMessage ?? context.attributes.countdownMessage
        if phase == .preMatch, let msg { return msg }
        return context.attributes.label(for: phase)
    }
    
    private func clockText(clockStart: Date) -> Text {
        let timer = Text(timerInterval: clockStart...clockStart.addingTimeInterval(500 * 60),
                         countsDown: false,
                         showsHours: false) + Text("'")
        if let prefix = context.state.matchMinutePrefix {
            return Text(prefix) + timer
        }
        return timer
    }
    
    @ViewBuilder
    private func actionButton(_ action: PPGLiveActivityAction, index: Int) -> some View {
        let appearance = action.design.ios.appearance.lightMode
        let destination: URL? = {
            switch action {
            case .url(_, let urlStr, _): return URL(string: urlStr)
            case .openApp: return context.attributes.deepLink.flatMap(URL.init)
            case .close:
                let encoded = context.attributes.liveNotificationId
                    .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                return URL(string: "ppg-la://close?id=\(encoded)")
            }
        }()
        let url = LiveActivityClickURL.make(
            liveNotificationId: context.attributes.liveNotificationId,
            type: index == 0 ? .clicked1 : .clicked2,
            liveDataVersion: context.state.liveDataVersion,
            destination: destination
        )
        if let url {
            Link(destination: url) { ctaLabel(text: action.name, appearance: appearance, cornerRadius: action.design.ios.borderRadius) }
        } else {
            ctaLabel(text: action.name, appearance: appearance, cornerRadius: action.design.ios.borderRadius)
        }
    }
    
    // Countdown timer used by compact leading (small) and expanded center (large)
    
    @ViewBuilder
    private func diCountdownTimer(until date: Date) -> some View {
        if date > Date.now {
            Text(timerInterval: Date.now...date, countsDown: true)
                .font(.caption2)
                .fontWeight(.semibold)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
        } else {
            Text("0:00")
                .font(.caption2)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundColor(.white)
        }
    }
    
    @ViewBuilder
    private func diCountdownTimerLarge(until date: Date) -> some View {
        if date > Date.now {
            Text(timerInterval: Date.now...date, countsDown: true)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
        } else {
            Text("0:00")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
        }
    }
    
    private func ctaLabel(text: String, appearance: PPGActionIOSAppearance, cornerRadius: Double) -> some View {
        let textColor: Color = {
            if case .basic(let hex) = appearance.textColor { return Color(hex: hex) }
            return .white
        }()
        let bgColor: Color? = {
            guard let bg = appearance.backgroundColor else { return nil }
            if case .basic(let hex) = bg { return Color(hex: hex) }
            return nil
        }()
        return Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(bgColor ?? Color.blue.opacity(0.3))
            .foregroundColor(textColor)
            .cornerRadius(cornerRadius)
    }
    
    // Compact Views — badge(22) + score:score + badge(22) in leading, phase in trailing
    
    private var compactLeading: some View {
        HStack(spacing: 3) {
            teamBadge(imageType: .homeTeamBadge, size: 22)
            let countdownDateCompact = context.state.countdownDate ?? context.attributes.countdownDate
            if phase == .preMatch, let countdownDateCompact {
                diCountdownTimer(until: countdownDateCompact)
            } else {
                Text(context.state.scoreCompact)
                    .font(.caption)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
            teamBadge(imageType: .awayTeamBadge, size: 22)
        }
    }
    
    private var compactTrailing: some View {
        HStack(spacing: 3) {
            if phase.isPlaying {
                Circle()
                    .fill(statusColor)
                    .frame(width: 5, height: 5)
            }
            if context.state.showsMatchClock, let clockStart = context.state.matchClockStartDate {
                let timer = Text(timerInterval: clockStart...clockStart.addingTimeInterval(500 * 60),
                                 countsDown: false,
                                 showsHours: false) + Text("'")
                let combined: Text = context.state.matchMinutePrefix.map { Text($0) + timer } ?? timer
                combined
                    .monospacedDigit()
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor)
                    .lineLimit(1)
                    .fixedSize()
            } else {
                Text(phase.shortText)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor)
            }
        }
    }
    
    // Minimal View
    
    private var minimal: some View {
        Text(context.state.scoreCompact)
            .font(.caption2)
            .fontWeight(.bold)
            .monospacedDigit()
    }
    
    private func teamBadge(imageType: PPGLiveActivityImageType, size: CGFloat) -> some View {
        Group {
            // Downsampled load — the compact island silently refuses to draw
            // bitmaps much larger than the slot, so hand it a thumbnail.
            if let image = LiveActivityImageManager.shared.loadImage(
                imageType: imageType,
                campaignId: context.attributes.liveNotificationId,
                targetSize: CGSize(width: size, height: size)
            ) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "shield.fill")
                            .font(.system(size: size * 0.55))
                            .foregroundColor(.white.opacity(0.9))
                    )
            }
        }
    }
}
