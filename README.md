#  Setup Guide

> [!IMPORTANT]
> **Version 3.0.0 Breaking changes**
>
> The SDK now internally handles all notification-related functionality:
> 1. Remove `UNUserNotificationCenterDelegate` conformance from your AppDelegate
> 2. Remove all `userNotificationCenter` delegate method implementations
> 3. Change `UNUserNotificationCenter.current().delegate = self` to `UNUserNotificationCenter.current().delegate = PPG.shared`
>
> **SPM support**
> 
> Version 2.1.0 provides architecture that supports SPM. At the same time, installation via Cocoapods from that version will no longer be supported.
>
> **Version 2.0.1 Breaking changes**
>
> - To be able to use v2.0.1 you will need to add AppGroups capability to your project.
> 
> - Check *Add required capabilities* and *Create Notification Service Extension* sections for further instructions.
> 
> - Also recommended: implementation of PPG.registerNotificationDeliveredFromUserInfo() in AppDelegate. Check examples below.

### [ Create certificate and upload it ]
Tutorial: https://docs.pushpushgo.company/application/providers/mobile-push/apns

### Install framework
Choose one of options:
- SPM
- Direct download
- Cocoapods (deprecated from v2.1.0)

### Migration Cocoapods -> SPM
1. If PPG ios-sdk was the only library installed by Pods, run `pod deintegrate` to remove any Pods-related files. If you are using Pods for any other dependencies, then remove PPG_framework refferences manually. Also detatch it from project and NSE targets.
2. Add library using SPM. Xcode -> File -> Add Package Dependency. Provide github url and choose you project target.
3. Manually add library to NotificationServiceExtension target.
4. Clean and rebuild the project.
5. If you will face any problems with derived data try running `rm -rf ~Library/Developer/Xcode/DerivedData/*` in you project directory. Then restart Xcode and clean and rebuild project.

### UIKit - Add required code to AppDelegate

Open AppDelegate.swift file
Add required imports

```swift
import UserNotifications
import PPG_framework
```

Add initialization code to given functions

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.

    // Initialize PPG framework
    PPG.initializeNotifications(projectId: "<your_app_id>", apiToken: "<your_api_token>", appGroupId: "<your_app_group_id>")
    
    // Register for push notifications if you do not already
    PPG.registerForNotifications(application: application, handler: { result in
        switch result {
        case .error(let error):
            // handle error
            print(error)
            return
        case .success:
            return
        }
    })
    
    UNUserNotificationCenter.current().delegate = PPG.shared
    
    return true
}
```

```swift
func applicationDidBecomeActive(_ application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive.
    // If the application was previously in the background, optionally refresh the user interface.
    PPG.sendEventsDataToApi()
}
```

```swift
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    PPG.sendDeviceToken(deviceToken) { _ in }
}
```

```swift
func application(_ application: UIApplication, 
                 didReceiveRemoteNotification userInfo: [AnyHashable: Any], 
                 fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    // Send a delivery event to your server
    PPG.registerNotificationDeliveredFromUserInfo(userInfo: userInfo) { status in
        print(status)
    }
    completionHandler(.newData)
}
```



### SwiftUI - Using SwiftUI you will still have to add AppDelegate
Create AppDelegate.swift file
```swift
import Foundation
import UIKit
import UserNotifications
import PPG_framework

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Initialize PPG
        PPG.initializeNotifications(projectId: "YOUR PROJECT ID", apiToken: "YOUR API KEY", appGroupId: "YOUR APP GROUP ID")
        
        // Register for notifications
        PPG.registerForNotifications(application: application) { result in
            switch result {
            case .error(let error):
                print(error)
                return
            case .success:
                print("Successfully registered")
                return
            }
        }
        
        UNUserNotificationCenter.current().delegate = PPG.shared
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive.
        // If the application was previously in the background, optionally refresh the user interface.
        PPG.sendEventsDataToApi()
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PPG.sendDeviceToken(deviceToken) { _ in }
    }

    func application(_ application: UIApplication, 
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any], 
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Send a delivery event to your server
        PPG.registerNotificationDeliveredFromUserInfo(userInfo: userInfo) { status in
            print(status)
        }
        completionHandler(.newData)
    }
}
```

Now you will have to inject that AppDelegate to your mainApp.swift file
```swift
import SwiftUI

@main
struct iOS_example_integrationApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate: AppDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Add required capabilities

1. Click on top item in your project hierarchy.
2. Select your project on target list.
3. Select `Signing & Capabilities`.
4. You can add capability by clicking on `+ Capability` button that is placed under `Signing & Capabilities` button.
5. Add `Background Modes` capability unless it is already on your capability list. Then select `Remote notifications`.
6. Add `Push notifications` capability unless it is already on your capability list.
7. Add `App Groups`. You can use your default app group ID or add new one.
8. Make sure that your `Provisioning Profile` has required capabilities. If you didn't add them while creating Provisioning Profile for your app you should go to your Apple Developer Center to add them. Then refresh your profile in Xcode project.

> **How to add new group to your provisioning profile?**
>
> Go to Apple developers and navigate to *Certificates, Identifiers & Profiles*. Then go to *Identifiers* and in the right corner change *App IDs* to *AppGroups*. You can add new group here.
>
> Now you can go back to *Identifiers*, choose your app identifier and add *AppGroup* capability. Remember to check your new group.

### Create Notification Service Extension

1. Open your Xcode project
2. Go to `File -> New -> Target`.
3. Select `Notification Service Extension`.
4. Choose a suitable name for it (for example `PPGNotificationServiceExtension`).
5. Open `NotificationService.swift` file.
6. Change `didReceive` function to: (use dispatch_group here to make sure that extension returns only when delivery event is sent and notification content is updated)
7. Click on top item in your project hierarchy and select your NotificationExtension on target list
8. Similarly to your project, add App Group capability to your NotificationExtension and check group you want to use.
9. Also add PPG_framework to NotificationServiceExtension target (General tab) if you haven't done that yet.
10. In your NotificationService extension, in *didReceive* function set your app group ID.

```swift
override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    self.contentHandler = contentHandler
    self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

    guard let content = bestAttemptContent else { return }

    // Wait for delivery event result & image fetch before returning from extension
    let group = DispatchGroup()
    group.enter()
    group.enter()

    // Dynamically set app group ID for your app
    SharedData.shared.appGroupId = "YOUR APP GROUP ID"

    PPG.notificationDelivered(notificationRequest: request) { _ in
        group.leave()
    }

    DispatchQueue.global().async { [weak self] in
        self?.bestAttemptContent = PPG.modifyNotification(content)
        group.leave()
    }

    group.notify(queue: .main) {
        contentHandler(self.bestAttemptContent ?? content)
    }
}

```

# Usage guide

### Create and send Beacon
```swift
let beacon = Beacon()
beacon.addSelector("Test_Selector", "0")

// Methods with strategy and ttl support
// For append tag in concrete category (with ttl, default = 0)
beacon.appendTag("mytag", "mycategory")
beacon.appendTag("mytag", "mycategory", 3600)

// For rewrite tag in concrete category (with ttl, default = 0)
beacon.rewriteTag("mytag", "mycategory")
beacon.rewriteTag("mytag", "mycategory", 3600)

// For delete tag in concrete category (with ttl, default = 0)
beacon.deleteTag("mytag", "mycategory");

// Legacy methods (not supports strategy append/rewrite and ttl)
beacon.addTag("new_tag", "new_tag_label")
beacon.addTagToDelete(BeaconTag(tag: "my_old_tag", label: "my_old_tag_label"))

beacon.send() { result in }
```

### Unsubscribe user
`PPG.unsubscribeUser { result in ... }`

### Handling Notifications and Events

#### Event Tracking
The SDK automatically tracks various notification events:

1. **Notification Delivery**
```swift
// In NotificationServiceExtension
PPG.notificationDelivered(notificationRequest: request) { _ in
    // Handle completion
}

// Or in AppDelegate
PPG.registerNotificationDeliveredFromUserInfo(userInfo: userInfo) { status in
    // Handle completion
}
```

2. **Notification Clicks**
The SDK automatically tracks notification clicks and handles URL redirections internally. No additional code is required in your AppDelegate.

#### Interactive Notifications
The SDK supports interactive notifications with action buttons. Actions are configured through the notification payload and automatically managed by the SDK:

- Buttons are created dynamically based on the payload
- Duplicate button titles are handled automatically
- Categories expire after 7 days
- URLs can be associated with specific buttons

Button identifiers:
- `button_1`: First action button
- `button_2`: Second action button

Supported button options:
- `foreground`: Opens the app
- `destructive`: Red button style
- `authenticationRequired`: Requires device unlock

The SDK automatically manages:
- Category creation and registration
- Button title uniqueness
- Action handling and URL redirection
- Event tracking for button clicks
