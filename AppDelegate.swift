//
//  AppDelegate.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/10.
//

import SwiftUI
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate,
    UNUserNotificationCenterDelegate, XGPushDelegate, ObservableObject
{
    @Published var tpnsLog: String = ""

    #if IOS_SIMULATOR
    func preparePreviews() {
        InAppNotificationDelegate.shared.addInfoMessage("Preview debug message")
    }
    #endif

    func startJSRuntime() { let _ = LUJSRuntime.shared }

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

    #if IOS_SIMULATOR
    // dummy definitions to avoid using TPNS service inside simulator
    // as XCFramework lib isn't fully supported with Apple chips
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        startJSRuntime()

        preparePreviews()
        return true
    }

    func startTPNS() {}

    func stopTPNS() {}

    func clearBadgeNumber() {}
    #else
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        startJSRuntime()
        if UserDefaults.appGroup.value(forKey: "useNotification") as? Bool ?? true {
            startTPNS()
        }

        if UserDefaults.appGroup.value(forKey: "useBaiduStatistics") as? Bool ?? true {

        }

        return true
    }

    func startTPNS() {
        XGPush.defaultManager().isEnableDebug = true
        XGPush.defaultManager()
            .configureClusterDomainName("tpns.sh.tencent.com")
        XGPush.defaultManager().appDelegate = self
        XGPush.defaultManager()
            .startXG(
                withAccessID: 1_680_015_447,
                accessKey: "IOSAEBOQD6US",
                delegate: self
            )
    }

    func stopTPNS() {
        XGPush.defaultManager().stopXGNotification()
    }

    func startBaiduStatistics() {
        let statTracker = BaiduMobStat.default()
        statTracker.shortAppVersion = Bundle.main.releaseNumber ?? "0.0.0"
        statTracker.enableDebugOn = true
        statTracker.start(withAppId: "000d3b0b91")
    }

    func clearBadgeNumber() {
        XGPush.defaultManager().setBadge(0)
        XGPush.defaultManager().xgApplicationBadgeNumber = 0
    }

    func xgPushDidRegisteredDeviceToken(
        _: String?,
        xgToken _: String?,
        error _: Error?
    ) {
        // When TPNS is started:
    }

    func xgPushDidFinishStop(_: Bool, error _: Error?) {
        // When stop TPNS is requested, callback here
    }

    func xgPushDidReceiveRemoteNotification(_: Any) async -> UInt { 1 }

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
