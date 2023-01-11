//
//  Notification.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/9.
//

import SwiftUI

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
