//
//  AppDelegate.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/10.
//

import SwiftUI
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate,
    UNUserNotificationCenterDelegate, ObservableObject
{
    @LoginClient(.ustcCAS) var ustcCasClient: UstcCasClient
    @LoginClient(.ustcAAS) var ustcAASClient: UstcAASClient

    #if IOS_SIMULATOR
    func preparePreviews() {
        InAppNotificationDelegate.shared.addInfoMessage("Preview debug message")
    }
    #endif

    func shouldRunUpdate(on version: String) -> Bool {
        #if IOS_SIMULATOR
        // Update on developing: if previousVersion <= version
        if let previousVersion = UserDefaults.appGroup.string(
            forKey: "version"
        ), previousVersion.versionCompare(version) == .orderedDescending {
            return false
        }
        #else
        // Update on release: if previousVersion < version
        if let previousVersion = UserDefaults.appGroup.string(
            forKey: "version"
        ),
            previousVersion.versionCompare(version) == .orderedDescending
                || previousVersion.versionCompare(version) == .orderedSame
        {
            return false
        }
        #endif

        print("Version <= \(version); Updating to version \(version)")
        return true
    }

    func startup() {
        _ustcCasClient.clearLoginStatus()
        _ustcAASClient.clearLoginStatus()
    }

    #if IOS_SIMULATOR
    // dummy definitions to avoid using TPNS service inside simulator
    // as XCFramework lib isn't fully supported with Apple chips
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        preparePreviews()
        startup()
        return true
    }
    #else
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        startup()
        return true
    }
    #endif
}
