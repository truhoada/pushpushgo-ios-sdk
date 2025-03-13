import SwiftUI
import UIKit
import UserNotifications

/// Base AppDelegate for both SwiftUI and UIKit apps
open class PPGAppDelegate: NSObject, UIApplicationDelegate {
    open func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = PPG.shared
        return true
    }
    
    open func applicationDidBecomeActive(_ application: UIApplication) {
        PPG.sendEventsDataToApi()
    }
    
    open func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PPG.sendDeviceToken(deviceToken) { _,_  in }
    }
    
    open func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        PPG.registerNotificationDeliveredFromUserInfo(userInfo: userInfo) { _ in
            completionHandler(.newData)
        }
    }
}

/// Extension for UIKit apps that already have AppDelegate
public extension UIApplicationDelegate {
    func PPGUserNotificationCenterDelegateSetUp() {
        UNUserNotificationCenter.current().delegate = PPG.shared
    }

    func PPGapplicationDidBecomeActive() {
        PPG.sendEventsDataToApi()
    }
    
    func PPGdidRegisterForRemoteNotificationsWithDeviceToken(_ deviceToken: Data) {
        PPG.sendDeviceToken(deviceToken) { _,_  in }
    }
    
    func PPGdidReceiveRemoteNotification(_ userInfo: [AnyHashable : Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        PPG.registerNotificationDeliveredFromUserInfo(userInfo: userInfo) { _ in
            completionHandler(.newData)
        }
    }
}
