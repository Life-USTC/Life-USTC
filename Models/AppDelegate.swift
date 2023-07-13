//
//  AppDelegate.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/10.
//

import SwiftUI
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, XGPushDelegate, ObservableObject {
    @Published var tpnsLog: String = ""

#if IOS_SIMULATOR
    func preparePreviews() {
        InAppNotificationDelegate.shared.addInfoMessage("Preview debug message")
    }
#endif

    func startJSRuntime() {
        let _ = LUJSRuntime.shared
    }

    func shouldRunUpdate(on version: String) -> Bool {
#if DEBUG
        // Update on developing: if previousVersion <= version
        if let previousVersion = userDefaults.string(forKey: "version"),
           previousVersion.versionCompare(version) == .orderedAscending
        {
            return false
        }
#else
        // Update on release: if previousVersion < version
        if let previousVersion = userDefaults.string(forKey: "version"),
           previousVersion.versionCompare(version) == .orderedAscending ||
           previousVersion.versionCompare(version) == .orderedSame
        {
            return false
        }
#endif

        print("Version <= \(version); Updating to version \(version)")
        return true
    }

    /// What to execute after 1.0.2 update
    func version1_0_2Update() {
        if !shouldRunUpdate(on: "1.0.2") {
            return
        }

        // if inside userDefaults, key feedSourceCache exists, then delete it
        if userDefaults.object(forKey: "feedSourceCache") != nil {
            userDefaults.removeObject(forKey: "feedSourceCache")
        }

        if UserDefaults.standard.object(forKey: "homeShowPostNumbers") != nil {
            UserDefaults.standard.removeObject(forKey: "homeShowPostNumbers")
        }

        if userDefaults.object(forKey: "passportUsername") != nil {
            userDefaults.removeObject(forKey: "passportUsername")
        }

        if userDefaults.object(forKey: "passportPassword") != nil {
            userDefaults.removeObject(forKey: "passportPassword")
        }

        if userDefaults.object(forKey: "semesterID") != nil {
            userDefaults.setValue(Int(userDefaults.string(forKey: "semesterID") ?? "0") ?? 0, forKey: "semesterIDInt")
            userDefaults.removeObject(forKey: "semesterID")
        }

        // set version to 1.0.2
        userDefaults.set("1.0.2", forKey: "version")
    }

#if IOS_SIMULATOR
    // dummy definitions to avoid using TPNS service inside simulator
    // as XCFramework lib isn't fully supported with Apple chips
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        startJSRuntime()
        version1_0_2Update()

        preparePreviews()
        return true
    }

    func startTPNS() {}

    func stopTPNS() {}

    func clearBadgeNumber() {}
#else
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        startJSRuntime()
        version1_0_2Update()
        if userDefaults.bool(forKey: "useNotification") {
            startTPNS()
        }
        return true
    }

    func startTPNS() {
        XGPush.defaultManager().isEnableDebug = true
        XGPush.defaultManager().configureClusterDomainName("tpns.sh.tencent.com")
        XGPush.defaultManager().appDelegate = self
        XGPush.defaultManager().startXG(withAccessID: 1_680_015_447, accessKey: "IOSAEBOQD6US", delegate: self)
    }

    func stopTPNS() {
        XGPush.defaultManager().stopXGNotification()
    }

    func clearBadgeNumber() {
        XGPush.defaultManager().setBadge(0)
        XGPush.defaultManager().xgApplicationBadgeNumber = 0
    }

    func xgPushDidRegisteredDeviceToken(_: String?, xgToken _: String?, error _: Error?) {
        // When TPNS is started:
    }

    func xgPushDidFinishStop(_: Bool, error _: Error?) {
        // When stop TPNS is requested, callback here
    }

    func xgPushDidReceiveRemoteNotification(_: Any) async -> UInt {
        1
    }

    func xgPushDidRequestNotificationPermission(_: Bool, error _: Error?) {}

    func xgPushLog(_ logInfo: String?) {
        if let logInfo {
            DispatchQueue.main.async {
                self.tpnsLog += "\n" + logInfo
                self.objectWillChange.send()
            }
        }
    }
#endif
}
