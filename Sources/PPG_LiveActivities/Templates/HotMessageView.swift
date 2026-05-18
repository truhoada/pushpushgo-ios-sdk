//
//  HotMessageView.swift
//  PPG_LiveActivities
//
//  Created by PushPushGo on 29/04/2026.
//

import SwiftUI
import ActivityKit

/// Renders a transient `PPGHotMessage` for exactly `durationSeconds` after
/// the first render on the device, then auto-hides.
///
/// Uses SwiftUI `TimelineView(.explicit(...))` to instruct the system to
/// re-render at the exact expiry moment — no timers, no polling, and no
/// second push needed. The expiry timestamp is derived from
/// `HotMessageStore.receivedAt(activityID:hotMessageId:)`, which persists
/// the first-seen time per-Activity in the shared App Group so it is
/// stable across multiple widget re-renders within the same window.
///
/// Pass a non-nil `hotMessage` and the current `activityID` from
/// `ActivityViewContext.activityID` to render.
@available(iOS 17.2, *)
public struct PPGHotMessageView: View {
    
    private let hotMessage: PPGHotMessage
    private let activityID: String
    
    public init(hotMessage: PPGHotMessage, activityID: String) {
        self.hotMessage = hotMessage
        self.activityID = activityID
    }
    
    public var body: some View {
        let receivedAt = HotMessageStore.shared.receivedAt(
            activityID: activityID,
            hotMessageId: hotMessage.id
        )
        // Effective end = min(receivedAt + maxDisplayDuration, expiresAt).
        // The local cap (10s) protects design intent; `expiresAt` is the
        // backend-controlled hard cutoff for stale messages.
        let endDate = hotMessage.endDate(receivedAt: receivedAt)
        
        TimelineView(.explicit([Date(), endDate])) { timeline in
            if timeline.date < endDate {
                messageBanner
            }
        }
    }
    
    private var messageBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            
            Text(hotMessage.text)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.45))
        )
    }
}
