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
    /// `statusBackgrounds` when available, falls back to the built-in gradient.
    @ViewBuilder
    private var backgroundView: some View {
        if let colorSet = context.attributes.background(for: phase) {
            colorSet.view(for: colorScheme)
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.33, green: 0.80, blue: 0.47),   // emerald green
                    Color(red: 0.35, green: 0.0, blue: 0.55)     // vivid purple
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    public var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                // Match title header
                Text(context.attributes.title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
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
                
                // Action button (custom design + alignment)
                if let action = context.attributes.firstCTAAction {
                    actionRow(action)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                
                // Hot message banner — transient, auto-hides after duration
                if let hotMessage = context.state.hotMessage {
                    PPGHotMessageView(
                        hotMessage: hotMessage,
                        activityID: context.activityID
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
        }
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
                .font(.caption2)
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
        } else {
            Text("0:00")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
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
            actionButton(action).frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    private func actionButton(_ action: PPGLiveActivityAction) -> some View {
        let design = action.design.ios
        let appearance = colorScheme == .dark ? design.appearance.darkMode : design.appearance.lightMode
        let url: URL? = {
            switch action {
            case .url(_, let urlStr, _): return URL(string: urlStr)
            case .openApp: return context.attributes.deepLink.flatMap(URL.init)
            case .close: return nil
            }
        }()
        if let url {
            Link(destination: url) {
                styledLabel(text: action.name, appearance: appearance, cornerRadius: design.borderRadius)
            }
        } else {
            styledLabel(text: action.name, appearance: appearance, cornerRadius: design.borderRadius)
        }
    }
    
    private func styledLabel(text: String, appearance: PPGActionIOSAppearance, cornerRadius: Double) -> some View {
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
