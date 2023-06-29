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

    func startJSRuntime() {
        let _ = LUJSRuntime.shared
    }

    /// What to execute after 1.0.2 update
    func version1_0_2Update() {
        // if inside userDefaults, key version is greater than 1.0.2, then return
        if let version = userDefaults.string(forKey: "version"), version.versionCompare("1.0.2") == .orderedAscending {
            return
        }

        // if inside userDefaults, key feedSourceCache exists, then delete it
        if userDefaults.object(forKey: "feedSourceCache") != nil {
            userDefaults.removeObject(forKey: "feedSourceCache")
        }

        if UserDefaults.standard.object(forKey: "homeShowPostNumbers") != nil {
            UserDefaults.standard.removeObject(forKey: "homeShowPostNumbers")
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
