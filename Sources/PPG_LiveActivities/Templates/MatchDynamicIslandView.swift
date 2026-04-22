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
    
    private var phase: MatchPhase? {
        return MatchPhase(rawValue: context.state.matchPhase)
    }
    
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
            teamBadge(url: context.attributes.homeTeamBadgeUrl, size: 28)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(context.attributes.homeTeamName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("\(context.state.homeScore)")
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
                
                Text("\(context.state.awayScore)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
            
            teamBadge(url: context.attributes.awayTeamBadgeUrl, size: 28)
        }
    }
    
    private var expandedCenter: some View {
        VStack(spacing: 2) {
            if let phase = phase {
                HStack(spacing: 4) {
                    if phase.isPlaying {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                        
                        Text("\(context.state.matchMinute)'")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    Text(context.attributes.label(for: phase))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(phase.color)
                }
            }
        }
    }
    
    private var expandedBottom: some View {
        Group {
            if let ctaText = context.attributes.ctaText, !ctaText.isEmpty {
                if let ctaDeepLink = context.attributes.ctaDeepLink,
                   let url = URL(string: ctaDeepLink) {
                    Link(destination: url) {
                        Text(ctaText)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.3))
                            .cornerRadius(8)
                    }
                } else {
                    Text(ctaText)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    // Compact Views — badge(22) + score:score + badge(22) in leading, phase in trailing
    
    private var compactLeading: some View {
        HStack(spacing: 3) {
            teamBadge(url: context.attributes.homeTeamBadgeUrl, size: 22)
            Text(context.state.scoreCompact)
                .font(.caption)
                .fontWeight(.bold)
                .monospacedDigit()
            teamBadge(url: context.attributes.awayTeamBadgeUrl, size: 22)
        }
    }
    
    private var compactTrailing: some View {
        HStack(spacing: 3) {
            if let phase = phase, phase.isPlaying {
                Circle()
                    .fill(Color.green)
                    .frame(width: 5, height: 5)
                Text("\(context.state.matchMinute)'")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            } else if let phase = phase {
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
    
    private func teamBadge(url: String?, size: CGFloat) -> some View {
        Group {
            if let image = LiveActivityImageManager.shared.loadImage(for: url) {
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
