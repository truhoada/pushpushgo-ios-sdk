#  Setup Guide

> [!IMPORTANT]
> **Version 4.3.0**
>
> 🎉 **New Feature: Live Activities SDK**
>
> Display real-time activity tracking on the Lock Screen and in the Dynamic Island,
> driven by backend push (push-to-start, live updates, hot messages).
> Includes a pre-built football match template. Custom templates support soon.
> Requires iOS 17.2+. For the integration guide, see the
> [Live Activities README](Sources/PPG_LiveActivities/README.md).
>
> ---
>
> **Version 4.0.0 - Major Release**
>
> 🎉 **New Feature: In-App Messages SDK**
> 
> This release introduces a powerful In-App Messages module that allows you to display targeted messages to your users.
> For detailed integration guide and documentation, see [In-App Messages README](Sources/PPG_InAppMessages/README.md).
>
> **What's New:**
> - ✅ In-App Messages SDK with audience targeting and custom triggers
> - ✅ Enhanced duplicate event prevention for delivered events
> - ✅ Improved stability and performance
>
> ---
> 
> **Version 3.0.3**
>
> Welcome back Cocoapods - from this version you can integrate via:
> 1. SPM
> 2. Cocoapods
> 
> **Version 3.0.1+ integration**
>
> The SDK now provides three simple ways to integrate push notifications:
> 1. SwiftUI apps without AppDelegate - using `@UIApplicationDelegateAdaptor`
> 2. UIKit apps with inheritance - extend `PPGAppDelegate`
> 3. UIKit apps with existing AppDelegate - use helper methods
>
> **Requirements**
>
> - Add AppGroups capability to your project
> - Create Notification Service Extension (see section below)

### [ Create certificate and upload it ]
Tutorial: https://docs.pushpushgo.company/application/providers/mobile-push/apns

### Install framework
Before you start, make sure to remove all previous integrations with other providers.

Choose one of options:
- SPM (recommended)
- Direct download
- Cocoapods (supported again from version 3.0.3)

#### SPM
1. In Xcode navigate to File -> Add package dependencies...
2. Search for https://github.com/ppgco/ios-sdk
3. Add sdk to project target
4. Also add sdk to NotificationServiceExtension target (more details below)

#### Cocoapods
In your **Podfile** add to the application target:
```bash
    pod 'PPG_framework', :git => 'https://github.com/ppgco/ios-sdk.git', :tag => '4.3.0'
```
Then run

```bash
    pod install
```

### Integration

> [!NOTE]
> While the previous integration method (manually implementing all AppDelegate notification methods) will continue to work,
> we recommend switching to one of the new integration methods below. The new methods provide automatic notification handling
> and significantly reduce the amount of boilerplate code needed (SwiftUI).

The SDK supports three integration methods:

#### 1. SwiftUI Apps (without AppDelegate)

For SwiftUI apps that don't have a custom AppDelegate:

```swift
import SwiftUI
import PPG_framework

@main
struct YourApp: App {
    @UIApplicationDelegateAdaptor(PPGAppDelegate.self) var appDelegate
    
    init() {
        // Initialize PPG
        PPG.initializeNotifications(
            projectId: "YOUR_PROJECT_ID",
            apiToken: "YOUR_API_TOKEN",
            appGroupId: "YOUR_APP_GROUP_ID"
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Register for notifications when the view appears
                    PPG.registerForNotifications(application: UIApplication.shared) { result in
                        switch result {
                        case .success:
                            print("Successfully registered for notifications")
                        case .error(let message):
                            print("Failed to register for notifications: \(message)")
                        }
                    }
                }
        }
    }
}
```

#### 2. UIKit Apps (Inheriting from PPGAppDelegate)

For UIKit apps that want to inherit push notification handling:

```swift
import UIKit
import PPG_framework

@main
class AppDelegate: PPGAppDelegate {
    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // First call super to setup PPG delegate
        let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        // Initialize PPG
        PPG.initializeNotifications(
            projectId: "YOUR_PROJECT_ID",
            apiToken: "YOUR_API_TOKEN",
            appGroupId: "YOUR_APP_GROUP_ID"
        )
        
        // Register for notifications
        PPG.registerForNotifications(application: application) { result in
            switch result {
            case .success:
                print("Successfully registered for notifications")
            case .error(let message):
                print("Failed to register for notifications: \(message)")
            }
        }
        
        // Your additional setup code
        return result
    }
}
```

#### 3. UIKit Apps (with Existing AppDelegate using helper functions)

For UIKit apps that already have an AppDelegate:

```swift
import UIKit
import PPG_framework

@main
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialize PPG
        PPG.initializeNotifications(
            projectId: "YOUR_PROJECT_ID",
            apiToken: "YOUR_API_TOKEN",
            appGroupId: "YOUR_APP_GROUP_ID"
        )
        
        // Setup PPG notification delegate
        PPGUserNotificationCenterDelegateSetUp()
        
        // Register for notifications
        PPG.registerForNotifications(application: application) { result in
            switch result {
            case .success:
                print("Successfully registered for notifications")
            case .error(let message):
                print("Failed to register for notifications: \(message)")
            }
        }
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        PPGapplicationDidBecomeActive()
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PPGdidRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        PPGdidReceiveRemoteNotification(userInfo, completionHandler: completionHandler)
    }
}
```


### Migration from Cocoapods to SPM

#### Cocoapods -> SPM
If you would like to migrate from Cocoapods to SPM, follow these steps:

1. If PPG ios-sdk was the only library installed by Pods, run `pod deintegrate` to remove any Pods-related files. If you are using Pods for any other dependencies, then remove PPG_framework references manually. Also detach it from project and NSE targets.
2. Add library using SPM. Xcode -> File -> Add Package Dependency. Provide github url and choose your project target.
3. Manually add library to NotificationServiceExtension target.
4. Clean and rebuild the project.
5. If you face any problems with derived data try running `rm -rf ~Library/Developer/Xcode/DerivedData/*` in your project directory. Then restart Xcode and clean and rebuild project.


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

#### Cocoapods integration
If you are using Cocoapods you need to add NSE to Podfile. Next to your application target add:
(Replace PPGNotificationServiceExtension with the name you set)

```bash
target 'PPGNotificationServiceExtension' do
  use_frameworks!
  use_modular_headers!
  pod 'PPG_framework', :git => 'https://github.com/ppgco/ios-sdk.git', :tag => '4.3.0'
end
```
**Note:** While compiling app with Service Extension you might face a problem with UIApplication.shared
To bypass it you will need to add this at the end of your Podfile:

```bash
 post_install do |installer|
   installer.pods_project.targets.each do |target|
     target.build_configurations.each do |config|
       config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'No'
      end
   end
 end
```
Error will be resolved internally in sdk in next releases.

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

### Dynamic Groups (Segments)

Assign or unassign subscribers to dynamic groups for targeted push notifications:

```swift
let beacon = Beacon()
beacon.customId = "user-xyz"

// Assign subscriber to a group
beacon.assignToGroup("premium-users")  // groupId

// Unassign subscriber from a group
beacon.unassignFromGroup("trial-users")  // groupId

beacon.send { result in }
```

### Unsubscribe user
`PPG.unsubscribeUser { result in ... }`


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
