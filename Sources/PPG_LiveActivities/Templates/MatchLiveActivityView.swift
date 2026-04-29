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
    
    private var phase: MatchPhase? {
        return MatchPhase(rawValue: context.state.matchPhase)
    }
    
    /// Background for the current match phase — uses backend-provided
    /// `statusBackgrounds` when available, falls back to the built-in gradient.
    @ViewBuilder
    private var backgroundView: some View {
        if let phase = phase,
           let colorSet = context.attributes.background(for: phase) {
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
                HStack(spacing: 0) {
                    // Home team
                    teamView(
                        name: context.attributes.homeTeamName,
                        badgeUrl: context.attributes.homeTeamBadgeUrl,
                        score: context.state.homeScore,
                        alignment: .trailing
                    )
                    
                    // Center: score + phase
                    centerView
                    
                    // Away team
                    teamView(
                        name: context.attributes.awayTeamName,
                        badgeUrl: context.attributes.awayTeamBadgeUrl,
                        score: context.state.awayScore,
                        alignment: .leading
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
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
        badgeUrl: String?,
        score: Int,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            // Badge — loaded from shared App Group container
            if let image = LiveActivityImageManager.shared.loadImage(for: badgeUrl) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } else {
                teamBadgePlaceholder
            }
            
            // Team name
            Text(name)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(minWidth: 60)
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
            // Score
            Text(context.state.scoreDisplay)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            
            // Phase + Minute
            HStack(spacing: 4) {
                if let phase = phase {
                    if phase.isPlaying {
                        // Show pulsing dot for live match
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        
                        Text("\(context.state.matchMinute)'")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    Text(context.attributes.label(for: phase))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(phase.color)
                }
            }
            
            // Countdown timer for pre-match
            if let phase = phase, phase == .preMatch,
               let startDate = context.state.startDate {
                Text(startDate, style: .timer)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            // CTA button
            if let ctaText = context.attributes.ctaText,
               !ctaText.isEmpty {
                if let ctaDeepLink = context.attributes.ctaDeepLink,
                   let url = URL(string: ctaDeepLink) {
                    Link(destination: url) {
                        ctaButton(text: ctaText)
                    }
                } else if let deepLink = context.attributes.deepLink,
                          let url = URL(string: deepLink) {
                    Link(destination: url) {
                        ctaButton(text: ctaText)
                    }
                } else {
                    ctaButton(text: ctaText)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func ctaButton(text: String) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.6))
            .cornerRadius(12)
    }
    
}
