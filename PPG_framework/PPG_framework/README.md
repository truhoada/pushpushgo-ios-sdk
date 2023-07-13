#  Setup Guide

### [ Create certificate and upload it ]

### [ install framework (cocoapods or direct download), remember to add pod to extension target ]

### Add required code to AppDelegate

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
    PPG.initializeNotifications(projectId: "<your_app_id>", apiToken: "<your_api_token>")
    
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
    
    UNUserNotificationCenter.current().delegate = self
    
    return true
}
```

```
func applicationDidBecomeActive(_ application: UIApplication) {
  // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

  PPG.sendEventsDataToApi()
}
```

```
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    PPG.sendDeviceToken(deviceToken) { _ in }
}
```

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
          withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    
    // Display notification when app is in foreground, optional
    completionHandler([.alert, .badge, .sound])
}
```

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {

    // Send information about clicked notification to framework
    PPG.notificationClicked(response: response)

    // Open external link from push notification
    // Remove this section if this behavior is not expected
    guard let url = PPG.getUrlFromNotificationResponse(response: response)
        else {
            completionHandler()
            return
        }
    UIApplication.shared.open(url)
    //
    completionHandler()
}
```

### Add required capabilities

1. Click on top item in your project hierarchy.
2. Select your project on target list.
3. Select `Signing & Capabilities`.
4. You can add capability by clicking on `+ Capability` button that is placed under `Signing & Capabilities` button.
5. Add `Background Modes` capability unless it is already on your capability list. Then select `Remote notifications`.
6. Add `Push notifications` capability unless it is already on your capability list.
7. Make sure that your `Provisioning Profile` has required capabilities. If you didn't add them while creating Provisioning Profile for your app you should go to your Apple Developer Center to add them. Then refresh your profile in Xcode project.

### Create Notification Service Extension

This step is not required but it allows application to display notifications with images.

1. Open your Xcode project
2. Go to `File -> New -> Target`.
3. Select `Notification Service Extension`.
4. Choose a suitable name for it (for example `PPGNotificationServiceExtension`).
5. Open `NotificationService.swift` file.
6. Change `didReceive` function to: (use dispatch_group here to make sure that extension returns only when delivery event is sent and notification content is updated)

```swift
override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    self.contentHandler = contentHandler
    self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

    guard let content = bestAttemptContent else { return }

    // Wait for delivery event result & image fetch before returning from extension
    let group = DispatchGroup()
    group.enter()
    group.enter()

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

### Send Event
Event's purpose is to tell API about newly received notifications. 
You should send events every time when user:

1. Received notification in extension
`PPG.notificationDelivered(notificationRequest: UNNotificationRequest, handler: @escaping (_ result: ActionResult)`

2. Click on notification
`PPG.notificationClicked(response: UNNotificationResponse)`

2. Click button inside notification
`PPG.notificationButtonClicked(response: response, button: 1)`

Available values for `button` are `1` and `2`
