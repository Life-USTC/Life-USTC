//
//  Notification.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/9.
//

import SwiftUI

#if os(iOS)
var deviceTokenString: String?

func tryRequestAuthorization() {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.badge, .alert, .sound]) { granted, error in
        if error != nil || granted == false {
            print(error!)
            return
        }
    }
}

func registerDeviceToken() async throws {
    if let token = deviceTokenString {
        var request = URLRequest(url: URL(string: "https://life-ustc.tiankaima.cn/api/newUser?token=\(token)")!)
        request.httpMethod = "POST"
        _ = try await URLSession.shared.data(for: request)
    }
}

func unRegisterDeviceToken() async throws {
    if let token = deviceTokenString {
        var request = URLRequest(url: URL(string: "https://life-ustc.tiankaima.cn/api/removeUser?token=\(token)")!)
        request.httpMethod = "POST"
        _ = try await URLSession.shared.data(for: request)
    }
}

#endif
