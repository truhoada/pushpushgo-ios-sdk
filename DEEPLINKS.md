# Deep links, Universal Links and AASA in PushPushGo iOS SDK

This document explains how `PPG_framework` routes URLs delivered inside push
notifications on iOS, how to opt into **Universal Links** (and the
`apple-app-site-association` / AASA file that they require), and how to add
**custom URL schemes** for traditional deep links.

---

## Table of contents

- [Overview](#overview)
- [Payload reference](#payload-reference)
- [Default click handling](#default-click-handling)
- [Regular URL vs Universal Link — decision flow](#regular-url-vs-universal-link--decision-flow)
- [Custom URL schemes (deep links)](#custom-url-schemes-deep-links)
  - [Registering the scheme in Info.plist](#registering-the-scheme-in-infoplist)
  - [Whitelisting the scheme in the SDK (`PPGSupportedURLSchemes`)](#whitelisting-the-scheme-in-the-sdk-ppgsupportedurlschemes)
  - [Handling the URL in the app](#handling-the-url-in-the-app)
- [Universal Links](#universal-links)
  - [1. Host an AASA file](#1-host-an-aasa-file)
  - [2. Enable the `Associated Domains` capability](#2-enable-the-associated-domains-capability)
  - [3. Flag the URL as a Universal Link in the payload (`UL`)](#3-flag-the-url-as-a-universal-link-in-the-payload-ul)
  - [4. Handle `NSUserActivity` in the app](#4-handle-nsuseractivity-in-the-app)
- [Action buttons and per-button URLs](#action-buttons-and-per-button-urls)
- [Retrieving the URL manually](#retrieving-the-url-manually)
- [Troubleshooting](#troubleshooting)

---

## Overview

When the user taps a notification (or one of its action buttons),
`PPG_framework`'s `UNUserNotificationCenterDelegate` implementation
(`PPG.shared`) executes the following steps:

1. Tracks the click (`PPG.notificationClicked` or
   `PPG.notificationButtonClicked(..., button: n)`).
2. Extracts a URL from the payload with
   `PPG.getUrlFromNotificationResponse(response:)`.
3. If the URL has a supported scheme, opens it either as a **Universal Link**
   (`NSUserActivity` → `application(_:continue:restorationHandler:)`) or as a
   **regular URL** (`UIApplication.shared.open(url)`), depending on the
   `UL` flag carried by the payload.

This means you get deep linking for free as long as the payload is shaped
correctly and your app is configured to receive the chosen URL type.

---

## Payload reference

Fields relevant to deep-link routing, attached to the APNs payload:

```json
{
  "aps": {
    "alert": { "title": "Hi", "body": "Check this out" },
    "url-args": ["https://example.com/product/42"]
  },
  "campaign": "...",
  "UL": true,
  "actions": [
    { "title": "Open", "url": "https://example.com/product/42", "UL": true },
    { "title": "Share", "url": "myapp://share/42" }
  ]
}
```

- `aps.url-args[0]` — URL used when the user taps the notification **body**.
- `actions[i].url`  — URL used when the user taps action **button `i+1`**.
  Button identifiers in `UNNotificationResponse.actionIdentifier` are
  `button_1` and `button_2`.
- `UL` (Boolean, optional) — present at the root level **or** per-action.
  - `UL: true`  → SDK opens the URL as a Universal Link.
  - `UL: false` (or missing) → SDK opens the URL via `open(url)`.

---

## Default click handling

```swift
// PPG.swift
public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    // 1. Track click (body or button)
    // 2. Resolve URL
    let (responseUrl, isUniversalLink) = PPG.getUrlFromNotificationResponse(response: response)

    if let url = responseUrl {
        if isUniversalLink {
            let userActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
            userActivity.webpageURL = url
            // forwarded to appDelegate.application(_:continue:restorationHandler:)
        } else {
            UIApplication.shared.open(url)
        }
    }
    completionHandler()
}
```

This delegate is registered automatically by:

- `PPGAppDelegate` (via `@UIApplicationDelegateAdaptor` for SwiftUI or
  inheritance for UIKit), or
- the `PPGUserNotificationCenterDelegateSetUp()` helper for existing
  UIKit AppDelegates.

See `Sources/PPG_framework/README.md` for the three supported integration
styles.

---

## Regular URL vs Universal Link — decision flow

```
              +------------------------------------+
              | User taps notification / button    |
              +------------------------------------+
                              |
                              v
              +------------------------------------+
              | getUrlFromNotificationResponse()   |
              |                                    |
              | - actions[i].url  if button_i      |
              | - aps.url-args[0] otherwise        |
              | - scheme must be in                |
              |   getSupportedUrlSchemes()         |
              +------------------------------------+
                              |
          UL == true          |          UL == false (default)
          +-----------------+ | +-----------------+
          v                   v                   v
   +----------------+  (no URL -> noop)    +--------------+
   | NSUserActivity |                      | open(url)    |
   | Browsing Web   |                      | (Safari or   |
   | -> app:continue|                      |  custom URL  |
   |   handler      |                      |  scheme)     |
   +----------------+                      +--------------+
```

`getSupportedUrlSchemes()` returns the array under Info.plist key
`PPGSupportedURLSchemes`, falling back to `["http", "https", "app"]` when
the key is missing.

---

## Custom URL schemes (deep links)

Use these when you want `myapp://product/42` inside `aps.url-args` (or
`actions[].url`) to open your app directly, without hosting an AASA file.

### Registering the scheme in Info.plist

Standard iOS requirement — completely unrelated to PushPushGo, but listed
here for completeness:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.example.myapp</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>myapp</string>
        </array>
    </dict>
</array>
```

### Whitelisting the scheme in the SDK (`PPGSupportedURLSchemes`)

`PPG_framework` only forwards URLs whose prefix matches an entry returned by
`PPG.getSupportedUrlSchemes()`. The default list is `http`, `https`, `app`.
To allow `myapp://...`, add:

```xml
<key>PPGSupportedURLSchemes</key>
<array>
    <string>http</string>
    <string>https</string>
    <string>myapp</string>
</array>
```

If you set this key at all it **replaces** the defaults, so always include
`http` and `https` unless you explicitly want them excluded.

> Define this key in the main app's `Info.plist`. The Notification Service
> Extension does not perform the click routing and does not need the key.

### Handling the URL in the app

Because `UL` is `false` (or absent), the SDK calls `UIApplication.shared.open(url)`.
iOS then dispatches the URL to the app through one of the standard entry
points:

**UIKit AppDelegate:**

```swift
func application(_ app: UIApplication,
                 open url: URL,
                 options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    return MyRouter.handle(url)
}
```

**UIKit SceneDelegate:**

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    URLContexts.forEach { MyRouter.handle($0.url) }
}
```

**SwiftUI:**

```swift
WindowGroup {
    ContentView()
        .onOpenURL { url in MyRouter.handle(url) }
}
```

---

## Universal Links

Use these when you want `https://example.com/product/42` inside the push to
open **your app** rather than Safari. iOS requires:

1. An `apple-app-site-association` (AASA) file hosted on your domain.
2. The `Associated Domains` capability, declaring that domain.
3. An app entry point that understands an incoming
   `NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)`.

### 1. Host an AASA file

Publish the file at:

```
https://example.com/.well-known/apple-app-site-association
```

It must be served over HTTPS, with `Content-Type: application/json`, and
**no redirects**. Minimal example:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["ABCDE12345.com.example.myapp"],
        "components": [
          {
            "/": "/product/*",
            "comment": "Matches product deep links"
          }
        ]
      }
    ]
  }
}
```

`ABCDE12345` is your Apple Developer Team ID; `com.example.myapp` is the
bundle identifier of the app that should receive the link.

iOS fetches the AASA file through Apple's CDN when the app is installed.
If you change the file, uninstalling + reinstalling the app (or toggling
Associated Domains with `?mode=developer` during debugging) is the fastest
way to force a refetch.

### 2. Enable the `Associated Domains` capability

In Xcode → *Signing & Capabilities* → `+ Capability` → **Associated Domains**,
add:

```
applinks:example.com
```

The capability must also be present in the **App ID / provisioning profile**
on the Apple Developer portal.

> This capability is only required for Universal Links. It is **not**
> required for push notifications themselves, nor for custom URL schemes.

### 3. Flag the URL as a Universal Link in the payload (`UL`)

The SDK must know whether to use `open(url)` (browser / custom scheme) or
`NSUserActivity` (Universal Link). This is controlled by the `UL` field in
the payload:

- `UL: true`  → SDK dispatches the URL as `NSUserActivity` (Universal Link).
- `UL: false` or missing → SDK calls `UIApplication.shared.open(url)`.

The flag can be set at the root level (for the body tap) or per action
(overrides the root flag for that specific button). Remember to configure your ASAA link in PushPushGo iOS integration.
### 4. Handle `NSUserActivity` in the app

When `UL == true`, the SDK forwards the URL to the standard iOS entry point
for Universal Links. **You must implement it** — otherwise the tap silently
falls back to `open(url)`.

**UIKit AppDelegate:**

```swift
func application(_ application: UIApplication,
                 continue userActivity: NSUserActivity,
                 restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else { return false }
    return MyRouter.handle(url)
}
```

**SwiftUI:**

```swift
WindowGroup {
    ContentView()
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL { MyRouter.handle(url) }
        }
}
```

Internally the SDK does:

```swift
let userActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
userActivity.webpageURL = url
appDelegate.application?(UIApplication.shared,
                         continue: userActivity,
                         restorationHandler: { _ in })
```

so any domain whitelisted via AASA + `applinks:` will be routed into the
app.

---

## Action buttons and per-button URLs

Mapping between `UNNotificationResponse.actionIdentifier` and the payload:

- `UNNotificationDefaultActionIdentifier` → `aps.url-args[0]`
- `button_1` → `actions[0].url`
- `button_2` → `actions[1].url`

Each action may define its own `UL` flag, which takes precedence over the
root-level `UL` when present — so one button can open a Universal Link
while another opens a plain URL in Safari.

---

## Retrieving the URL manually

If you bypass the default delegate (for example in a hybrid app, or to run
custom routing), you can call:

```swift
let (url, isUniversalLink) = PPG.getUrlFromNotificationResponse(response: response)
```

`url` is `nil` when:

- There is no URL in the payload, or
- Its scheme is not included in `PPG.getSupportedUrlSchemes()`.

---

## Troubleshooting

- **Custom scheme URL does nothing.** Scheme missing from either
  `CFBundleURLTypes` or `PPGSupportedURLSchemes`. Both are required.
- **Universal Link opens Safari instead of the app.** Either:
  - AASA file is not reachable / not JSON / served with a redirect;
  - `Associated Domains` capability is missing / not in the provisioning
    profile;
  - `UL` flag is not `true` in the payload;
  - `application(_:continue:restorationHandler:)` / `.onContinueUserActivity`
    is not implemented (SDK falls back to `open(url)` in that case).
- **Payload URL is ignored.** Check `PPG.getSupportedUrlSchemes()` — if you
  set `PPGSupportedURLSchemes` without `http`/`https`, default web links are
  dropped.
- **Action button click is tracked but no URL opens.** `actions[i].url`
  missing, empty, or using an unsupported scheme.
- **How do I debug AASA?** Use Apple's validator:
  `https://app-site-association.cdn-apple.com/a/v1/example.com`, and check
  the device console filtered by `swcd` / `CoreSpotlight`.
