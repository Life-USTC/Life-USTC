//
//  Constants.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/30.
//

import Foundation

extension UserDefaults {
    static let appGroup = UserDefaults(
        suiteName: "group.dev.tiankaima.Life-USTC"
    )!
}

let userAgent =
    #"Mozilla/5.0 (iPod; CPU iPhone OS 12_0 like macOS) AppleWebKit/602.1.50 (KHTML, like Gecko) Version/12.0 Mobile/14A5335d Safari/602.1.50 life-at-ustc/1.0"#

let exampleURL = URL(string: "https://example.com")!
