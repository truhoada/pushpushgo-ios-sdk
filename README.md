#  Setup Guide

### [ Create certificate and upload it ]

### [ install framework (cocoapods or direct download), remember to add pod to extension target ]

### Add required code to AppDelegate

Open AppDelegate.swift file
Add required imports

```
import UserNotifications
import PPG_framework
```

Add initialization code to gioven functions

```
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.

    // Initialize PPG framework
    PPG.initNotifications("<your_app_id>", application, handler: { result in
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

```
func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
          withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    
    // Display notification when app is in foreground, optional
    completionHandler([.alert, .badge, .sound])
}
```

```
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
6. Change `didReceive` function to:

```
override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    self.contentHandler = contentHandler
    bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
            
    if let bestAttemptContent = bestAttemptContent {
        contentHandler(PPG.modifyNotification(bestAttemptContent))
    }
}

```

# Usage guide

### Create and send Beacon
```
let beacon = Beacon()
beacon.addSelector("Test_Selector", "value")
beacon.addTag("new_tag", "new_tag_label")
beacon.addTagToDelete("tag_to_delete")
beacon.send { result in ... }
```

### Unsubscribe user
`PPG.unsubscribeUser { result in ... }`

### Send Event
Event's purpose is to tell API about newly received notifications. 
You should send events every time when user:

1. Click on notification
`PPG.notificationClicked(response: response) { _ in }`

2. Click button inside notification
`PPG.notificationButtonClicked(response: response, button: 1) { _ in }`
Available values for `button` are `1` and `2`
