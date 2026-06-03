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

Field names mirror the backend APNs `content-state` payload
(`homeTeamScore`, `awayTeamScore`, `status`).

```swift
LiveActivitiesSDK.shared.updateActivity(
    MatchActivityAttributes.self,
    activityId: activityId!,
    state: MatchActivityAttributes.ContentState(
        homeTeamScore: 1,
        awayTeamScore: 0,
        status: .firstHalf
    )
)
```

### Step 6: End the Match

```swift
LiveActivitiesSDK.shared.endActivity(
    MatchActivityAttributes.self,
    activityId: activityId!,
    finalState: MatchActivityAttributes.ContentState(
        homeTeamScore: 2,
        awayTeamScore: 1,
        status: .matchEnded
    ),
    dismissPolicy: .default  // Stays on Lock Screen for ~4 hours
)
```

## Hot Messages

`ContentState.hotMessage` renders a transient banner in the Lock Screen and
Dynamic Island (taking priority over the CTA). Visibility is the **minimum**
of two cutoffs:

- **Local cap** — `PPGHotMessage.maxDisplayDuration` (10 s by default).
- **Backend cutoff** — `expiresAt` (Unix epoch wire field `timestamp`).

The SDK schedules a deterministic `Activity.update` at the computed end
instant so the banner disappears even if the widget's `TimelineView`
updates are deferred under render-budget pressure. Send the same content
state with `hotMessage: nil` to clear it early.

```swift
LiveActivitiesSDK.shared.updateActivity(
    MatchActivityAttributes.self,
    activityId: activityId!,
    state: MatchActivityAttributes.ContentState(
        homeTeamScore: 1,
        awayTeamScore: 0,
        status: .firstHalf,
        hotMessage: PPGHotMessage(
            id: "var-cancelled-1",
            text: "Goal cancelled after VAR",
            expiresAt: Date(timeIntervalSinceNow: 30) // hard cutoff
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

## Subscriber API (Recommended for Production)

Production Live Activities are driven entirely by PPG backend push.
`subscribe(liveNotificationId:)` registers this device for a specific
Live Notification. Backend handles `event:start`, `event:update`, and
`event:end` via APNs.

### How it works

1. Backend creates a Live Notification (`POST /core/projects/{project}/live-notifications/football-match-tracking`) and returns its `id`.
2. App calls `LiveActivitiesSDK.shared.subscribe(MatchActivityAttributes.self, liveNotificationId: id)`.
3. SDK generates / reuses a persistent `installationId` (UUIDv4 in `UserDefaults`) and listens on `Activity<T>.pushToStartTokenUpdates`.
4. On every new push-to-start token, SDK POSTs `/live-notifications/{id}/subscribers` with `{ installationId, endpoint:{ transport: "APNS", remoteStartToken } }`.
5. Backend pushes `event:start` → OS creates the Live Activity locally with the right `attributes` + initial `content-state`.
6. SDK forwards every rotated `activity.pushTokenUpdates` token via PUT `/subscribers/{installationId}/endpoint` so subsequent `event:update` pushes can target this device.
7. `event:end` (no content-state) ends the activity. `unsubscribe(liveNotificationId:)` deletes the subscriber on the backend.

### Usage

```swift
// User taps "Follow match" button
LiveActivitiesSDK.shared.subscribe(
    MatchActivityAttributes.self,
    liveNotificationId: "69f84d8daddcd1d291038d91"
) { status in
    switch status {
    case .registered:
        print("Subscriber registered, waiting for match start…")
    case .activityStarted(let id):
        print("Live Activity started: \(id)")
    case .updateTokenSent(let id):
        print("Update token forwarded for \(id)")
    case .activityEnded(let id):
        print("Activity ended: \(id)")
    case .unsubscribed:
        print("Subscriber removed")
    case .error(let error):
        print("Subscriber error: \(error)")
    }
}

// To stop receiving updates
LiveActivitiesSDK.shared.unsubscribe(liveNotificationId: "69f84d8daddcd1d291038d91")
```

### Subscriber vs Local Start

| Feature | `subscribe(liveNotificationId:)` | `startActivity` |
|---|---|---|
| Who starts? | PPG backend (via push) | App code (locally) |
| App must be open? | No (after registration) | Yes |
| Best for | Production | Development / testing |
| REST endpoints | `/live-notifications/{id}/subscribers` | none |

## Push Token Management

The SDK automatically handles ActivityKit push tokens for subscribed
notifications:

- **Push-to-start token**: posted to `/subscribers` on first observation and on every rotation.
- **Activity update token**: forwarded to `/subscribers/{installationId}/endpoint` once the activity exists.
- **`installationId`**: stable UUIDv4 generated and persisted by the SDK — not the same as `PPG.subscriberId` from the push SDK.

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

// Subscriber API (production — backend-driven)
subscribe<T>(_ type: T.Type, liveNotificationId: String, onStatus:)
unsubscribe(liveNotificationId: String)

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
