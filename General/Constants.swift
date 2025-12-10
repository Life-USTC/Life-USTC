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
        suiteName: "group.dev.tiankaima.Life-USTC"
    )!
}

extension Bundle {
    var releaseNumber: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var buildNumber: String? {
        infoDictionary?["CFBundleVersion"] as? String
    }

    var versionDescription: String {
        "Ver: \(releaseNumber ?? "") build\(buildNumber ?? "")"
    }

    var shortVersionDescription: String {
        "v\(releaseNumber ?? "")build\(buildNumber ?? "")"
    }
}

enum Constants {
    static let userAgent =
        "Mozilla/5.0 (iPod; CPU iPhone OS 12_0 like macOS) AppleWebKit/602.1.50 (KHTML, like Gecko) Version/12.0 Mobile/14A5335d Safari/602.1.50"
    static let demoUserName = "demo"
    static let demoPassword = "demo"
}
