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
            // Expanded view
            DynamicIslandExpandedRegion(.leading) {
                expandedLeading
            }
            DynamicIslandExpandedRegion(.trailing) {
                expandedTrailing
            }
            DynamicIslandExpandedRegion(.center) {
                expandedCenter
            }
            DynamicIslandExpandedRegion(.bottom) {
                expandedBottom
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
        if let deepLink = context.attributes.deepLink {
            return URL(string: deepLink)
        }
        return nil
    }
    
    // Expanded Views
    
    private var expandedLeading: some View {
        HStack(spacing: 6) {
            teamBadge(imageType: .homeTeamBadge, size: 28)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(context.attributes.homeTeamName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("\(context.state.homeTeamScore)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
        }
    }
    
    private var expandedTrailing: some View {
        HStack(spacing: 6) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(context.attributes.awayTeamName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("\(context.state.awayTeamScore)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
            
            teamBadge(imageType: .awayTeamBadge, size: 28)
        }
    }
    
    private var expandedCenter: some View {
        VStack(spacing: 2) {
            let countdownDate = context.state.countdownDate ?? context.attributes.countdownDate
            if phase == .preMatch, let countdownDate {
                diCountdownTimer(until: countdownDate)
            } else {
                HStack(spacing: 4) {
                    if phase.isPlaying {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                    }
                    Text(context.attributes.label(for: phase))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(phase.color)
                }
            }
        }
    }
    
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
    private var expandedBottom: some View {
        if let hotMessage = context.state.hotMessage {
            PPGHotMessageView(
                hotMessage: hotMessage,
                activityID: context.activityID
            )
        } else if let action = context.attributes.firstCTAAction {
            let appearance = action.design.ios.appearance.lightMode
            let url: URL? = {
                switch action {
                case .url(_, let urlStr, _): return URL(string: urlStr)
                case .openApp: return context.attributes.deepLink.flatMap(URL.init)
                case .close:
                    let encoded = context.attributes.liveNotificationId
                        .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    return URL(string: "ppg-la://close?id=\(encoded)")
                }
            }()
            if let url {
                Link(destination: url) { ctaLabel(text: action.name, appearance: appearance, cornerRadius: action.design.ios.borderRadius) }
            } else {
                ctaLabel(text: action.name, appearance: appearance, cornerRadius: action.design.ios.borderRadius)
            }
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
                    .fill(Color.green)
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
                    .foregroundColor(phase.color)
                    .lineLimit(1)
                    .fixedSize()
            } else {
                Text(phase.shortText)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(phase.color)
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
            if let image = LiveActivityImageManager.shared.loadImage(imageType: imageType, campaignId: context.attributes.liveNotificationId) {
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
