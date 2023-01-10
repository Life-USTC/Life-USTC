//
//  AppDelegate.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/10.
//

import SwiftUI

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions _:
                     [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    {
        UNUserNotificationCenter.current().delegate = self

        application.registerForRemoteNotifications()
        return true
    }

    func application(_: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)
    {
        print(deviceToken)
        //   self.sendDeviceTokenToServer(data: deviceToken)
    }

    func application(_: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error)
    {
        print(error)
        // Try again later.
    }

    private func application(application _: UIApplication, didReceiveRemoteNotification userInfo: [NSObject: AnyObject]) {
        print(userInfo)
    }

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Update the app interface directly.

        // Show a banner
        completionHandler(.banner)
    }
}
