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
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        true
    }

    func startTPNS() {}

    func stopTPNS() {}
#else
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
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

    func xgPushDidRegisteredDeviceToken(_: String?, xgToken _: String?, error _: Error?) {
        // When TPNS is started:
    }

    func xgPushDidFinishStop(_: Bool, error _: Error?) {
        // When stop TPNS is requested, callback here
    }

    func xgPushDidReceiveRemoteNotification(_: Any) async -> UInt {
        1
    }

    func xgPushDidRequestNotificationPermission(_ isEnable: Bool, error: Error?) {
#if DEBUG
        if !isEnable || error != nil {
            print("Request Notification failed")

            DispatchQueue.main.async {
                // sadly this isn't working as the startup page have multiple sheet before alert could show up
                let controller = UIApplication.shared.windows.first?.rootViewController as? UIViewController
                let alert = UIAlertController(title: "Alert", message: "Message", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Click", style: .default, handler: nil))
                controller?.present(alert, animated: true)
            }
        }
#endif
    }

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
