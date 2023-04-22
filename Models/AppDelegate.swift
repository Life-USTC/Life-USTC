//
//  AppDelegate.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/10.
//

import SwiftUI

#if os(iOS)

var tpnsLog: String = ""

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, XGPushDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        XGPush.defaultManager().clearTPNSCache()
        XGPush.defaultManager().isEnableDebug = true
        XGPush.defaultManager().configureClusterDomainName("tpns.sh.tencent.com")
        XGPush.defaultManager().appDelegate = self
        XGPush.defaultManager().startXG(withAccessID: 1_680_015_447, accessKey: "IOSAEBOQD6US", delegate: self)
        return true
    }

    func xgPushDidRegisteredDeviceToken(_: String?, xgToken _: String?, error _: Error?) {}

    func xgPushDidReceiveRemoteNotification(_: Any) async -> UInt {
        1
    }

    func xgPushLog(_ logInfo: String?) {
        if let logInfo {
            tpnsLog += "\n" + logInfo
        }
    }
}
#else

#endif
