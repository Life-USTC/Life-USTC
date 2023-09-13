//
//  FeedSource.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import SwiftUI

struct FeedSource: Codable, Identifiable, Equatable, ExampleDataProtocol {
    var id = UUID()
    var url: URL
    var name: String
    var description: String?
    var image: String?  // system image
    var colorHex: String?

    var feed: [Feed] = []

    static let example = FeedSource(
        url: exampleURL,
        name: "School News",
        description: "This is an example feed source",
        image: "doc.richtext",
        colorHex: "ff0000",
        feed: [.example]
    )
}

extension FeatureWithView {
    init(_ feedSource: FeedSource) {
        self.init(
            image: feedSource.image ?? "doc.richtext",
            title: feedSource.name,
            subTitle: feedSource.description ?? "",
            destinationView: { FeedSourceView(feedSource: feedSource) }
        )
    }
}
