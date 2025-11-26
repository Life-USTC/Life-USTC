//
//  FeedSource.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import FeedKit
import SwiftUI
import SwiftyJSON

struct FeedSource: Codable, Identifiable, Equatable {
    var id = UUID()
    var url: URL
    var name: String
    var description: String?
    var image: String?  // system image
    var colorHex: String?

    var feed: [Feed] = []
}

extension FeedSource: ExampleArrayDataProtocol, ExampleDataProtocol {
    static let examples: [FeedSource] = [
        .init(
            url: URL(string: "https://www.teach.ustc.edu.cn/category/notice/feed")!,
            name: "教务处",
            description: "",
            image: "person.crop.square.fill.and.at.rectangle",
            colorHex: "7676D0",
            feed: [.example]
        )
    ]
}
