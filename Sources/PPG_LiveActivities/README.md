# PPG Live Activities SDK for iOS

Live match tracking on the Lock Screen and in the Dynamic Island, driven by
the PushPushGo backend. Your app integrates the SDK once and subscribes a
device to a campaign — starting the activity, updating the score, showing
hot messages and ending the match are all done server-side through the PPG
panel / REST API. The app does not need to be running.

```
PPG panel / REST API ──▶ PPG backend ──▶ APNs ──▶ Live Activity on the device
                                ▲
   your app ── subscribe(id) ───┘   (one-time, via this SDK)
```

## Requirements

- iOS 17.2+
- Swift 5.9+, Xcode 15.0+
- An APNs certificate/key uploaded to your PPG project ([tutorial](https://docs.pushpushgo.company/application/providers/mobile-push/apns))

## Installation

### Swift Package Manager (recommended)

1. Xcode → File → Add Package Dependencies…
2. Enter: `https://github.com/ppgco/ios-sdk`
3. Select the `PPG_LiveActivities` product — add it to **both** the app target and the Widget Extension target (created in Step 3 below).

### CocoaPods

```ruby
pod 'PPG_LiveActivities', :git => 'https://github.com/ppgco/ios-sdk.git', :tag => '4.4.0'
```

## App setup (one-time)

### Step 1: App Group

The Widget Extension runs in a separate process — team badges, design and
hot-message state are shared through an App Group container.

1. Apple Developer portal → enable an App Group on **both** your app's bundle id and your widget extension's bundle id (e.g. `group.com.your.app.liveactivities`).
2. Xcode → both targets → Signing & Capabilities → **+ Capability → App Groups** → tick the same group.
3. Use that exact id everywhere below.

### Step 2: Info.plist keys

In the **app target's** Info.plist:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>ppg-la</string></array>
  </dict>
</array>
```

`ppg-la` is the SDK-owned URL scheme used by Live Activity taps and action
buttons (Step 5 wires it up).

### Step 3: Initialize the SDK

Call `initialize` from `application(_:didFinishLaunchingWithOptions:)` (or
your SwiftUI `App.init`). **It must run on every launch, including background
launches** — when a match starts while your app is terminated, iOS wakes it
briefly and this is the SDK's only window to capture push tokens.

```swift
import PPG_LiveActivities

LiveActivitiesSDK.shared.initialize(
    apiKey: "YOUR_API_KEY",
    projectId: "YOUR_PROJECT_ID",
    appGroupId: "group.com.your.app.liveactivities",
    isDebug: true            // verbose logs while integrating; remove for release
)
```

### Step 4: Add the Widget Extension

1. Xcode → File → New → Target → **Widget Extension** (no need for the "Include Live Activity" checkbox — the SDK ships the views).
2. Add `PPG_LiveActivities` as a dependency of the widget target and enable the same App Group on it.
3. Replace the generated widget with:

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
            PPGMatchLockScreenView(context: context)      // Lock Screen
        } dynamicIsland: { context in
            PPGMatchDynamicIsland(context: context).body() // Dynamic Island
        }
    }
}
```

### Step 5: Handle taps

Taps on the activity body and on action buttons are delivered to your app as
`ppg-la://…` URLs. Route them through the SDK — it records click statistics
and opens the right destination (`http/https` → browser, CLOSE buttons →
your handler):

```swift
// SwiftUI
.onOpenURL { url in
    if !LiveActivitiesSDK.handleURL(url, closeHandler: { _ in
        LiveActivitiesSDK.shared.endAllActivities(ofType: MatchActivityAttributes.self)
    }) {
        // not an SDK URL — route your own deep links here
    }
}
```

(UIKit: call the same from `application(_:open:options:)`.)

Setup done — everything below is the runtime flow.

## The match flow (end to end)

| Phase | Who does it | How |
|---|---|---|
| 1. Create campaign | You (panel / your backend) | PPG panel or `POST /live-notifications/football-match-tracking` |
| 2. Subscribe device | Your app (this SDK) | `subscribe(liveNotificationId:)` |
| 3. Start | PPG backend | push-to-start at the scheduled time (or bootstrap, see 3b) |
| 4. Score / hot messages | You (panel / your backend) | `PUT /live-data`, `POST /hot-messages` |
| 5. End | You (panel / your backend) | `POST /stop` |
| 6. Unsubscribe (optional) | Your app | `unsubscribe(liveNotificationId:)` |

All REST calls below use base `https://api.pushpushgo.com` and headers
`X-Token: <API key>` + `Content-Type: application/json`.

### 1. Create the campaign

Create the Live Activity in the PPG panel (teams, badges, colors, action
buttons, schedule) — or via REST:
`POST /core/projects/{projectId}/live-notifications/football-match-tracking`.

Either way you get the campaign id (**`liveNotificationId`**, a 24-char hex
id). Deliver it to your app however you like — a regular push, your own API,
a hardcoded fixture list.

### 2. Subscribe the device

Call when the user opts in (e.g. taps "Follow match") — and again on every
app launch while the campaign is active, so observers re-attach after a
relaunch (`subscribe` is idempotent):

```swift
LiveActivitiesSDK.shared.subscribe(
    MatchActivityAttributes.self,
    liveNotificationId: campaignId,
    onCampaignAlreadyActive: { data in
        // Late-subscriber bootstrap: the campaign is already ONGOING, so no
        // push-to-start will come. Build the activity from the REST payload:
        let dto = try PPGLiveNotificationDTO.decode(from: data)
        return MatchActivityAttributes.from(dto: dto)
    }
) { status in
    switch status {
    case .registered:                  print("waiting for match start…")
    case .activityStarted(let id):     print("Live Activity on screen: \(id)")
    case .updateTokenSent:             break   // device can now receive updates
    case .activityEnded:               print("match over")
    case .unsubscribed:                break
    case .error(let error):            print("LA error: \(error)")
    }
}
```

The SDK registers the device on the PPG backend, manages all ActivityKit
push tokens, and downloads the campaign's team badges into the App Group
cache automatically.

### 3. Match start — nothing to do in the app

- **3a. Scheduled start (typical):** at the campaign's start the PPG backend
  sends an APNs *push-to-start* — iOS creates the Live Activity even if your
  app is terminated. You'll see `.activityStarted` if the app is running.
- **3b. Late subscriber (bootstrap):** if the device subscribes when the
  campaign is already ONGOING, no push-to-start will arrive — the SDK fetches
  the campaign over REST and starts the activity locally via your
  `onCampaignAlreadyActive` closure. Same UI, same updates afterwards.

### 4. Drive the match

Score / status changes (each one updates every subscribed device):

```bash
curl -X PUT "https://api.pushpushgo.com/core/projects/$PROJECT/live-notifications/$CAMPAIGN/live-data" \
  -H "X-Token: $API_KEY" -H "Content-Type: application/json" \
  -d '{ "homeTeamScore": 1, "awayTeamScore": 0, "status": "FIRST_HALF" }'
```

`status` takes any [match phase](#match-phases). Playing phases render a live
match clock; breaks show a static minute marker (`45'`, `90'`, `105'`).

Hot messages — a transient banner ("Goal!", "Red card #5") shown for up to
10 seconds on the Lock Screen, in the expanded island, and in place of the
clock in the compact island; each new message replaces the previous one:

```bash
curl -X POST "https://api.pushpushgo.com/core/projects/$PROJECT/live-notifications/$CAMPAIGN/hot-messages" \
  -H "X-Token: $API_KEY" -H "Content-Type: application/json" \
  -d '{ "text": "Goal cancelled after VAR" }'
```

### 5. End the match

```bash
curl -X POST "https://api.pushpushgo.com/core/projects/$PROJECT/live-notifications/$CAMPAIGN/stop" \
  -H "X-Token: $API_KEY"
```

The activity ends on every device (iOS may keep it dimmed on the Lock Screen
for up to ~4 h unless the user swipes it away).

### 6. Unsubscribe (optional)

For an in-app "Unfollow" action — deletes the subscriber on the backend, no
further pushes reach the device:

```swift
LiveActivitiesSDK.shared.unsubscribe(liveNotificationId: campaignId)
```

## What the user sees

- **Lock Screen** — campaign title + live match clock, team badges and names,
  score, status label (texts configured per-campaign in the panel), hot
  message banner on top, up to two action buttons.
- **Dynamic Island compact** — home badge · score · away badge on the left;
  live clock (or break minute, or hot message text) on the right.
- **Dynamic Island expanded** — Lock Screen-style layout with buttons.
- **Action buttons** — the first action's alignment (`LEFT`/`CENTER`/`RIGHT`/
  `STRETCH`) lays out the whole group; colors, border and corner radius are
  per-button. The island always uses the dark-mode variant of each action.

## Match Phases

The **DI compact** column is what the compact island's trailing slot shows:
a live counting clock for playing phases (requires `statusChangedAt` in the
content state — the PPG backend sets it automatically) or a static,
language-neutral minute marker when the clock is stopped.

| Phase | State | DI compact |
|-------|-------|------------|
| `PRE_MATCH` | Before kickoff | — (countdown in leading slot) |
| `FIRST_HALF` | Playing | live clock |
| `FIRST_HALF_ADDED_TIME` | Playing | live clock (`45+…`) |
| `HALF_TIME_BREAK` | Break | `45'` |
| `SECOND_HALF` | Playing | live clock |
| `SECOND_HALF_ADDED_TIME` | Playing | live clock (`90+…`) |
| `FULL_TIME` | Finished | `90'` |
| `EXTRA_TIME_BREAK` | Break | `90'` |
| `EXTRA_TIME_FIRST_HALF` | Playing | live clock |
| `EXTRA_TIME_FIRST_HALF_ADDED_TIME` | Playing | live clock (`105+…`) |
| `EXTRA_TIME_HALF_TIME_BREAK` | Break | `105'` |
| `EXTRA_TIME_SECOND_HALF` | Playing | live clock |
| `EXTRA_TIME_SECOND_HALF_ADDED_TIME` | Playing | live clock (`120+…`) |
| `PENALTY_SHOOTOUT` | Playing | `120'` |
| `MATCH_ENDED` | Finished | — |
| `OTHER` | Fallback / unknown | — |

## Delivery at scale: broadcast channels (iOS 18+)

For large audiences the PPG backend can attach an APNs **broadcast channel**
to a campaign. Updates and the end event are then published once per campaign
(instead of once per device), so delivery time no longer grows with the
subscriber count. Requires no integration work — behavior is negotiated
automatically:

- The SDK reports channel capability with every subscriber registration
  (`endpoint.isBroadcastChannel`, `true` on iOS 18+); devices on iOS
  17.2–17.x keep the per-token path.
- Push-to-start remains per device; when the campaign has a channel the
  backend includes `input-push-channel` and the created activity receives all
  subsequent updates via broadcast.
- Late-subscriber bootstrap starts the activity with `pushType: .channel(...)`
  when the campaign exposes an APNs entry in `broadcastChannels`
  (`[{"type": "APNS", "channelId": "…"}]`). The array is empty until the
  campaign goes ONGOING, which is exactly when bootstrap applies.

Behavioral notes in channel mode:

- `updateTokenSent` never fires (channel-backed activities have no update
  token) — this is expected, not a token-forwarding failure.
- `unsubscribe(liveNotificationId:)` ends the campaign's activities locally.
  A broadcast reaches every channel subscriber and the backend cannot
  exclude one device, so opting a device out requires ending its activity.
  This applies to both push registrations — the client cannot reliably tell
  them apart, and ending the activity is what "stop following" implies
  either way.
- Statistics (`started` / `clicked` / `closed`) are unaffected — they are
  reported by the SDK from the device.

## Alternative: app-driven activities (no PPG backend)

For development, demos, or when your app drives the content itself, the SDK
exposes the full local lifecycle. Activities started this way are **not**
reachable by PPG backend pushes.

```swift
// Start (badges must be prefetched manually in this flow)
let dto = try PPGLiveNotificationDTO.decode(from: jsonData)
guard let (attributes, initialState) = MatchActivityAttributes.from(dto: dto) else { return }

let activityId = LiveActivitiesSDK.shared.startActivity(
    attributes: attributes, initialState: initialState, templateId: "match"
)

// Update — including hot messages via ContentState.hotMessage
LiveActivitiesSDK.shared.updateActivity(
    MatchActivityAttributes.self,
    activityId: activityId!,
    state: .init(homeTeamScore: 1, awayTeamScore: 0, status: .firstHalf)
)

// End
LiveActivitiesSDK.shared.endActivity(
    MatchActivityAttributes.self,
    activityId: activityId!,
    finalState: .init(homeTeamScore: 2, awayTeamScore: 1, status: .matchEnded),
    dismissPolicy: .default   // .immediate / .after(Date) / .default (~4 h)
)
```

## Troubleshooting

### Live Activity not appearing?

1. **Permissions**: `LiveActivitiesSDK.shared.areActivitiesEnabled()` must be
   `true` (Settings → Face ID & Passcode → Live Activities, and the per-app
   toggle).
2. **Physical device** with iOS 17.2+; push-to-start does not work in the
   simulator. Dynamic Island requires iPhone 14 Pro or later.
3. **Subscribe order**: the device must be subscribed before the campaign
   starts — or pass `onCampaignAlreadyActive` so late subscribers bootstrap.
4. Enable `isDebug: true` and watch the logs: you should see
   `Subscriber registered…`, then `Activity appeared…`.

### Push updates not working?

- With `isDebug: true` you should see `Update token forwarded for activity …`
  after the activity appears — if not, the backend has no update token for
  this device.
- **APNs environment must match the build**: a sandbox/test PPG project
  delivers only to development-signed builds (run from Xcode);
  TestFlight/App Store builds use the production APNs environment. A mismatch
  fails silently — subscription works (it's HTTPS) but no push ever arrives.
  An expired or revoked APNs certificate fails the same silent way.
- On-device diagnosis: install Apple's **ActivityKit logging profile**
  (developer.apple.com → Profiles & Logs), then in Console.app filter
  Subsystem = `co.pushpushgo.PPG_LiveActivities` (SDK logs from app and
  widget) and Process = `liveactivitiesd` / `apsd` (system push delivery).

### Badges not showing?

- The App Group id must be identical in `initialize(...)`,
  `configureWidgetExtension(...)` and both targets' capabilities.
- In the subscriber flow badges download automatically right after the
  activity appears (placeholders swap to real badges within seconds); in the
  local-start flow prefetch them yourself (see the alternative flow above).

## API Reference

```swift
// Setup
initialize(apiKey:projectId:appGroupId:isProduction:isDebug:)
LiveActivitiesSDK.configureWidgetExtension(appGroupId:)   // widget process
areActivitiesEnabled() -> Bool
LiveActivitiesSDK.handleURL(_:closeHandler:) -> Bool      // tap routing

// Production (backend-driven)
subscribe<T>(_ type:, liveNotificationId:, onCampaignAlreadyActive:, onStatus:)
unsubscribe(liveNotificationId:)

// Local lifecycle (development / app-driven)
startActivity<T>(attributes:initialState:templateId:) -> String?
updateActivity<T>(_ type:, activityId:, state:)
endActivity<T>(_ type:, activityId:, finalState:, dismissPolicy:)
endAllActivities<T>(ofType:)
getActiveActivities() -> [LiveActivityInfo]
```

## Support

- GitHub Issues: https://github.com/ppgco/ios-sdk/issues
- Documentation: https://docs.pushpushgo.com
