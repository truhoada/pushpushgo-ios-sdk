//
//  MatchLiveActivityView.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 13/03/2026.
//

import SwiftUI
import WidgetKit
import ActivityKit

/// Pre-built Lock Screen view for the football match Live Activity template.
@available(iOS 17.2, *)
public struct PPGMatchLockScreenView: View {
    
    let context: ActivityViewContext<MatchActivityAttributes>
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(context: ActivityViewContext<MatchActivityAttributes>) {
        self.context = context
    }
    
    private var phase: MatchPhase { context.state.status }
    
    /// Background for the current match phase — uses backend-provided
    /// `statusBackgrounds` when available, falls back to the design cache
    /// (populated from the REST bootstrap GET). When neither is set
    /// (backend sent `statusBackgrounds:null` — "device system" mode),
    /// renders `Color.clear` so iOS shows its system-adaptive Live Activity
    /// background which auto-adjusts to light/dark mode.
    @ViewBuilder
    private var backgroundView: some View {
        let liveNotifId = context.attributes.liveNotificationId
        let colorSet = context.attributes.background(for: phase)
            ?? LiveActivityDesignStore.shared.background(for: phase, liveNotificationId: liveNotifId)
        if let colorSet {
            colorSet.view(for: colorScheme)
        } else {
            Color.clear
        }
    }
    
    public var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                // Hot message banner — transient, auto-hides after duration
                if let hotMessage = context.state.hotMessage {
                    PPGHotMessageView(
                        hotMessage: hotMessage,
                        activityID: context.activityID
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
                
                // Match title header — left spacer + right clock both conditional on same flag
                HStack(spacing: 0) {
                    if context.state.showsMatchClock {
                        Color.clear.frame(width: 68)
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
                            .frame(width: 68, alignment: .trailing)
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 16)
                
                // Teams + Score row
                HStack(spacing: 0) {
                    teamView(
                        name: context.attributes.homeTeamName,
                        imageType: .homeTeamBadge,
                        score: context.state.homeTeamScore,
                        alignment: .trailing
                    )
                    centerView
                    teamView(
                        name: context.attributes.awayTeamName,
                        imageType: .awayTeamBadge,
                        score: context.state.awayTeamScore,
                        alignment: .leading
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                // Action buttons (custom design + alignment) - render up to 2
                if !context.attributes.actionSet.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(context.attributes.actionSet.prefix(2), id: \.name) { action in
                            actionRow(action)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
        .widgetURL(context.attributes.deepLink.flatMap(URL.init))
        .activitySystemActionForegroundColor(.white)
    }
    
    // Team View
    
    private func teamView(
        name: String,
        imageType: PPGLiveActivityImageType,
        score: Int,
        alignment: HorizontalAlignment
    ) -> some View {
        let campaignId = context.attributes.liveNotificationId
        return VStack(alignment: .center, spacing: 4) {
            if let image = LiveActivityImageManager.shared.loadImage(imageType: imageType, campaignId: campaignId) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
            } else {
                teamBadgePlaceholder
            }
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(minWidth: 60, maxWidth: .infinity)
    }
    
    private var teamBadgePlaceholder: some View {
        Circle()
            .fill(Color.white.opacity(0.2))
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: "shield.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.5))
            )
    }
    
    // Center View
    
    private var centerView: some View {
        VStack(spacing: 4) {
            let countdownDate = context.state.countdownDate ?? context.attributes.countdownDate
            if phase == .preMatch, let countdownDate {
                countdownTimer(until: countdownDate)
            } else {
                Text(context.state.scoreDisplay)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            
            HStack(spacing: 4) {
                if phase.isPlaying {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                }
                Text(statusLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(phase.color)
            }
        }
        .frame(maxWidth: .infinity)
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
    
    private var statusLabel: String {
        let msg = context.state.countdownMessage ?? context.attributes.countdownMessage
        if phase == .preMatch, let msg { return msg }
        return context.attributes.label(for: phase)
    }
    
    @ViewBuilder
    private func countdownTimer(until date: Date) -> some View {
        if date > Date.now {
            Text(timerInterval: Date.now...date, countsDown: true)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        } else {
            Text("0:00")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
        }
    }
    
    // Action Row
    
    private func actionRow(_ action: PPGLiveActivityAction) -> some View {
        HStack(spacing: 0) {
            actionButtonAligned(action)
        }
    }
    
    @ViewBuilder
    private func actionButtonAligned(_ action: PPGLiveActivityAction) -> some View {
        switch action.design.ios.alignment {
        case .left:
            actionButton(action)
            Spacer(minLength: 0)
        case .right:
            Spacer(minLength: 0)
            actionButton(action)
        case .center:
            Spacer(minLength: 0)
            actionButton(action)
            Spacer(minLength: 0)
        case .stretch:
            actionButton(action, isStretched: true)
        }
    }
    
    @ViewBuilder
    private func actionButton(_ action: PPGLiveActivityAction, isStretched: Bool = false) -> some View {
        let design = action.design.ios
        let appearance = colorScheme == .dark ? design.appearance.darkMode : design.appearance.lightMode
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
            Link(destination: url) {
                styledLabel(text: action.name, appearance: appearance, cornerRadius: design.borderRadius, isStretched: isStretched)
            }
        } else {
            styledLabel(text: action.name, appearance: appearance, cornerRadius: design.borderRadius, isStretched: isStretched)
        }
    }
    
    private func styledLabel(text: String, appearance: PPGActionIOSAppearance, cornerRadius: Double, isStretched: Bool = false) -> some View {
        let textColor: Color = {
            if case .basic(let hex) = appearance.textColor { return Color(hex: hex) }
            return .white
        }()
        let bgColor: Color? = {
            guard let bg = appearance.backgroundColor else { return nil }
            if case .basic(let hex) = bg { return Color(hex: hex) }
            return nil
        }()
        let borderColor: Color? = {
            guard let border = appearance.border, case .basic(let hex) = border.color else { return nil }
            return Color(hex: hex)
        }()
        let borderWidth = appearance.border?.width ?? 0
        return Text(text)
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundColor(textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 5)
            .frame(maxWidth: isStretched ? .infinity : nil)
            .background(bgColor ?? .clear)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                if let borderColor {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: borderWidth)
                }
            }
    }
    
}
