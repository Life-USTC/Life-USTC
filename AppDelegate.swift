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
    @LoginClient(.ustcCAS) var ustcCasClient: UstcCasClient
    @LoginClient(.ustcAAS) var ustcAASClient: UstcAASClient

    func startup() {
        _ustcCasClient.clearLoginStatus()
        _ustcAASClient.clearLoginStatus()
    }

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        startup()
        return true
    }
}
