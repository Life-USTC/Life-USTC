//
//  AppDelegate.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/10.
//

import SwiftUI

class AppDelegate: UIResponder, UIApplicationDelegate,
    UNUserNotificationCenterDelegate, ObservableObject
{
    func startup() {
        #if DEBUG
        // Ensure onboarding (welcome) can be shown during UI tests when requested
        if ProcessInfo.processInfo.arguments.contains("UI_TEST_RESET_ONBOARDING") {
            UserDefaults.standard.set(true, forKey: "firstLogin_3")
        }
        #endif
    }

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        startup()
        return true
    }
}
