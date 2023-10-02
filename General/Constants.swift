//
//  Constants.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/30.
//

import Foundation

extension UserDefaults {
    /// Use .appGroup for storing data that widget and app shares.
    /// Use .default for UI settings though.
    static let appGroup = UserDefaults(
        suiteName: "group.com.linzihan.XZKDiOS"
    )!
}

let userAgent =
    #"Mozilla/5.0 (iPod; CPU iPhone OS 12_0 like macOS) AppleWebKit/602.1.50 (KHTML, like Gecko) Version/12.0 Mobile/14A5335d Safari/602.1.50 life-at-ustc/1.0"#

let exampleURL = URL(string: "https://example.com")!

var appShouldPresentDemo: Bool {
    get {
        UserDefaults.appGroup.object(forKey: "appShouldPresentDemo") as? Bool ?? false
    }
    set {
        UserDefaults.appGroup.set(newValue, forKey: "appShouldPresentDemo")
    }
}

var appShouldNOTUpdate: Bool {
    get {
        UserDefaults.appGroup.object(forKey: "appShouldNOTUpdateAnything") as? Bool ?? false
    }
    set {
        UserDefaults.appGroup.set(newValue, forKey: "appShouldNOTUpdateAnything")
    }
}

let demoUserName = "demo"
let demoPassword = "demo"
