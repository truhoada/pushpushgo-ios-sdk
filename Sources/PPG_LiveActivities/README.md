# PPG Live Activities SDK for iOS

Display real-time activity tracking on the Lock Screen and Dynamic Island. Includes a pre-built football match template and supports custom templates.

## Requirements

- iOS 17.2+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager (Recommended)

In Xcode:

1. File → Add Package Dependencies...
2. Enter: `https://github.com/ppgco/ios-sdk`
3. Select `PPG_LiveActivities` product

### CocoaPods

```ruby
pod 'PPG_LiveActivities', :git => 'https://github.com/ppgco/ios-sdk.git', :tag => '4.2.0'
```

Then run:

```bash
pod install
```

## Quick Start

### Step 1: Configure App Group (required)

The Widget Extension runs in a separate process and cannot share memory with
your app. Team badges and hot-message state are persisted in a shared
App Group container.

1. Apple Developer portal → enable an App Group on **both** your app's bundle id
   and your widget extension bundle id (e.g. `group.com.your.app.liveactivities`).
2. Xcode → both targets → Signing & Capabilities → **+ Capability → App Groups**
   and tick the same group.
3. Use that exact id in the SDK init below and in the Widget Extension setup.

### Step 2: Initialize the SDK

```swift
import PPG_LiveActivities

// In AppDelegate.application(_:didFinishLaunchingWithOptions:) or App init
LiveActivitiesSDK.shared.initialize(
    apiKey: "YOUR_API_KEY",
    projectId: "YOUR_PROJECT_ID",
    appGroupId: "group.com.your.app.liveactivities" // example
)
```

### Step 3: Add a Widget Extension

1. Xcode → File → New → Target → **Widget Extension**.
2. Add `PPG_LiveActivities` as a dependency for the widget target.
3. Inside the widget bundle's `init`, point the image manager at the same
   App Group so cached badges become visible to widget views:

```swift
import WidgetKit
import SwiftUI
import PPG_LiveActivities

@main
struct MatchLiveActivityWidget: Widget {
    init() {
        // The widget runs in its own process and does not inherit
        // configuration from the host app — wire up the shared App Group.
        LiveActivitiesSDK.configureWidgetExtension(
            appGroupId: "group.com.your.app.liveactivities"
        )
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MatchActivityAttributes.self) { context in
            // Lock Screen
            PPGMatchLockScreenView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island
            PPGMatchDynamicIsland(context: context).body()
        }
    }
}
```

### Step 4: Start a Match Activity from a backend payload (recommended)

In production the activity is driven by the PPG backend. Decode the
`PPGLiveNotificationDTO` from your in-app event / push and use the
`from(dto:)` factory — it builds both the static attributes and the initial
`ContentState` in one shot:

```swift
let dto = try JSONDecoder().decode(PPGLiveNotificationDTO.self, from: jsonData)

guard let (attributes, initialState) = MatchActivityAttributes.from(dto: dto) else {
    return  // not a football-match template
}

// Prefetch team badges into the App Group so the widget can render them.
await LiveActivityImageManager.shared.prefetch(from: [
    attributes.homeTeamBadgeUrl,
    attributes.awayTeamBadgeUrl
].compactMap { $0 })

let activityId = LiveActivitiesSDK.shared.startActivity(
    attributes: attributes,
    initialState: initialState,
    templateId: "match"
)
```

### Step 5: Update During the Match

`matchMinute` is optional — leave it `nil` before kickoff or at full-time and
the widget will hide the live-minute badge.

```swift
LiveActivitiesSDK.shared.updateActivity(
    MatchActivityAttributes.self,
    activityId: activityId!,
    state: MatchActivityAttributes.ContentState(
        homeScore: 1,
        awayScore: 0,
        phase: .firstHalf,
        matchMinute: "23"
    )
)
```

### Step 6: End the Match

```swift
LiveActivitiesSDK.shared.endActivity(
    MatchActivityAttributes.self,
    activityId: activityId!,
    finalState: MatchActivityAttributes.ContentState(
        homeScore: 2,
        awayScore: 1,
        phase: .matchEnded,
        matchMinute: nil
    ),
    dismissPolicy: .default  // Stays on Lock Screen for ~4 hours
)
```

## Hot Messages

`ContentState.hotMessage` renders a transient banner in the Lock Screen and
Dynamic Island (taking priority over the CTA). It auto-hides after
`durationSeconds` using a deterministic timeline, and per-activity timestamps
are persisted in the App Group so the countdown survives widget refreshes.
Set `hotMessage` back to `nil` in a follow-up `update` to clear it early.

```swift
LiveActivitiesSDK.shared.updateActivity(
    MatchActivityAttributes.self,
    activityId: activityId!,
    state: MatchActivityAttributes.ContentState(
        homeScore: 1,
        awayScore: 0,
        phase: .firstHalf,
        matchMinute: "45+2",
        hotMessage: PPGHotMessage(
            id: "var-cancelled-1",
            text: "Goal cancelled after VAR",
            durationSeconds: 5
        )
    )
)
```

## Adding a New Template

All lifecycle methods are generic — they work with **any** `ActivityAttributes` type.
Adding a new template requires **zero changes** to the SDK core:

1. Define your `ActivityAttributes`:
```swift
struct DeliveryActivityAttributes: ActivityAttributes {
    let orderId: String
    let restaurantName: String
    
    struct ContentState: Codable, Hashable {
        let status: String
        let estimatedArrival: Date
    }
}
```

2. Create SwiftUI views for Lock Screen and Dynamic Island
3. Register in your Widget Extension via `ActivityConfiguration(for: DeliveryActivityAttributes.self)`
4. Use the same SDK methods — generics handle everything:

```swift
let id = LiveActivitiesSDK.shared.startActivity(
    attributes: DeliveryActivityAttributes(orderId: "456", restaurantName: "Pizza Place"),
    initialState: .init(status: "preparing", estimatedArrival: Date().addingTimeInterval(1800)),
    templateId: "delivery"
)

LiveActivitiesSDK.shared.updateActivity(
    DeliveryActivityAttributes.self,
    activityId: id!,
    state: .init(status: "on_the_way", estimatedArrival: Date().addingTimeInterval(900))
)

LiveActivitiesSDK.shared.endActivity(
    DeliveryActivityAttributes.self,
    activityId: id!,
    finalState: .init(status: "delivered", estimatedArrival: Date()),
    dismissPolicy: .after(Date().addingTimeInterval(300))
)
```

## Match Phases

The SDK provides a complete `MatchPhase` enum with all football match states:

| Phase | Display Text | State |
|-------|-------------|-------|
| `PRE_MATCH` | Pre-Match | Before kickoff |
| `FIRST_HALF` | 1st Half | Playing |
| `FIRST_HALF_ADDED_TIME` | 1st Half +AT | Playing |
| `HALF_TIME_BREAK` | Half Time | Break |
| `SECOND_HALF` | 2nd Half | Playing |
| `SECOND_HALF_ADDED_TIME` | 2nd Half +AT | Playing |
| `FULL_TIME` | Full Time | Finished |
| `EXTRA_TIME_BREAK` | ET Break | Break |
| `EXTRA_TIME_FIRST_HALF` | ET 1st Half | Playing |
| `EXTRA_TIME_FIRST_HALF_ADDED_TIME` | ET 1st Half +AT | Playing |
| `EXTRA_TIME_HALF_TIME_BREAK` | ET Half Time | Break |
| `EXTRA_TIME_SECOND_HALF` | ET 2nd Half | Playing |
| `EXTRA_TIME_SECOND_HALF_ADDED_TIME` | ET 2nd Half +AT | Playing |
| `PENALTY_SHOOTOUT` | Penalties | Playing |
| `MATCH_ENDED` | Match Ended | Finished |
| `OTHER` | — | Fallback / unknown |

## Observer API (Recommended for Production)

The primary production flow uses `observeLiveActivity` — the PPG backend controls the entire lifecycle remotely via ActivityKit push notifications.

### How it works

1. Create a campaign in the PPG panel or via PPG API
2. User taps "Follow this match" in your app → SDK registers as observer
3. PPG backend starts, updates, and ends the Live Activity via push
4. On **iOS 18+**: broadcast channel (1 push → all observers)
5. On **iOS 17.2–17.x**: per-device push tokens

### Usage

```swift
// User taps "Follow match" button
LiveActivitiesSDK.shared.observeLiveActivity(
    MatchActivityAttributes.self,
    campaignId: "camp-2026-final",
    templateId: "match"
) { status in
    switch status {
    case .registered:
        print("Waiting for match to start...")
    case .started(let activityId):
        print("Live Activity started: \(activityId)")
    case .updated(let activityId):
        print("Activity updated: \(activityId)")
    case .ended(let activityId):
        print("Match ended: \(activityId)")
    case .error(let error):
        print("Error: \(error)")
    }
}

// To stop observing
LiveActivitiesSDK.shared.stopObserving(campaignId: "camp-2026-final")
```

### Observer vs Local Start

| Feature | `observeLiveActivity` | `startActivity` |
|---|---|---|
| Who starts? | PPG backend (via push) | App code (locally) |
| App must be open? | No (after registration) | Yes |
| Best for | Production campaigns | Development/testing |
| Scales to many users | Yes (channels on iOS 18+) | N/A (local only) |

## Push Token Management

The SDK automatically handles ActivityKit push tokens:

- **Push-to-start tokens**: Sent to PPG backend when `observeLiveActivity` is called
- **Push-to-update tokens**: Registered automatically after an activity starts
- **Token rotation**: Observed and re-registered on change

## Dismiss Policies

Control when ended activities are removed from the Lock Screen:

```swift
// Remove immediately
.immediate

// Keep for a specific duration
.after(Date().addingTimeInterval(3600))  // 1 hour

// System default (~4 hours)
.default
```

## Troubleshooting

### Live Activity not appearing?

1. **Check permissions**: `LiveActivitiesSDK.shared.areActivitiesEnabled()`
2. **Enable debug logging**:
   ```swift
   LiveActivitiesSDK.shared.initialize(
       apiKey: "...",
       projectId: "...",
       isDebug: true
   )
   ```
3. **Verify Widget Extension** is properly configured and includes `PPG_LiveActivities`
4. **Check device**: Live Activities require iPhone with iOS 17.2+. Dynamic Island requires iPhone 14 Pro or later.

### Push updates not working?

- Ensure your app has the Push Notifications capability
- The `NSSupportsLiveActivities` key must be `YES` in your app's `Info.plist`
- Check that the push token was registered (debug logs)

## API Reference

### Essential Methods

```swift
// Initialize SDK
initialize(
    apiKey: String,
    projectId: String,
    appGroupId: String,
    isProduction: Bool = true,
    isDebug: Bool = false
)

// Check availability
areActivitiesEnabled() -> Bool

// Observer API (production — backend-driven)
observeLiveActivity<T>(_ type: T.Type, campaignId: String, templateId: String, onStatus:)
stopObserving(campaignId: String)

// Local lifecycle (development/testing or custom flows)
startActivity<T>(attributes: T, initialState: T.ContentState, templateId: String) -> String?
updateActivity<T>(_ type: T.Type, activityId: String, state: T.ContentState)
endActivity<T>(_ type: T.Type, activityId: String, finalState: T.ContentState?, dismissPolicy:)

// Management
endAllActivities<T>(ofType: T.Type)
getActiveActivities() -> [LiveActivityInfo]
```

## Support

For issues, feature requests, or questions:

- GitHub Issues: https://github.com/ppgco/ios-sdk/issues
- Documentation: https://docs.pushpushgo.com
