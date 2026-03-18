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
///
/// Usage in your Widget Extension:
/// ```swift
/// struct MatchLiveActivity: Widget {
///     var body: some WidgetConfiguration {
///         ActivityConfiguration(for: MatchActivityAttributes.self) { context in
///             PPGMatchLockScreenView(context: context)
///         } dynamicIsland: { context in
///             PPGMatchDynamicIsland(context: context)
///         }
///     }
/// }
/// ```
@available(iOS 16.2, *)
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
                    
                    Text(phase.displayText)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(phaseColor)
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
    
    // Compact Views
    
    private var compactLeading: some View {
        HStack(spacing: 4) {
            teamBadge(url: context.attributes.homeTeamBadgeUrl, size: 16)
            
            Text("\(context.state.homeScore)")
                .font(.caption)
                .fontWeight(.bold)
                .monospacedDigit()
        }
    }
    
    private var compactTrailing: some View {
        HStack(spacing: 4) {
            Text("\(context.state.awayScore)")
                .font(.caption)
                .fontWeight(.bold)
                .monospacedDigit()
            
            teamBadge(url: context.attributes.awayTeamBadgeUrl, size: 16)
        }
    }
    
    // Minimal View
    
    private var minimal: some View {
        Text(context.state.scoreCompact)
            .font(.caption2)
            .fontWeight(.bold)
            .monospacedDigit()
    }
    
    // Helpers
    
    private func teamBadge(url: String?, size: CGFloat) -> some View {
        Group {
            if let badgeUrl = url, let imageUrl = URL(string: badgeUrl) {
                AsyncImage(url: imageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "shield.fill")
                        .font(.system(size: size * 0.6))
                        .foregroundColor(.secondary)
                }
                .frame(width: size, height: size)
            } else {
                Image(systemName: "shield.fill")
                    .font(.system(size: size * 0.6))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var phaseColor: Color {
        guard let phase = phase else { return .secondary }
        
        if phase.isPlaying { return .green }
        if phase.isBreak { return .yellow }
        if phase.isFinished { return .secondary }
        return .primary
    }
}
