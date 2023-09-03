//
//  Feed.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import FeedKit
import Foundation
import LoremSwiftum

struct Feed: Codable, Identifiable, Equatable {
    var id: UUID = .init()
    var title: String
    var source: String
    var keywords: Set<String>
    var description: String?
    var datePosted: Date
    var url: URL
    var imageURL: URL?

    static let example = Feed(
        title: Lorem.sentence,
        source: Lorem.word,
        keywords: [Lorem.word, Lorem.word],
        description: Lorem.sentences(2),
        datePosted: Date(),
        url: exampleURL,
        imageURL: URL(string: "https://picsum.photos/300/300")!
    )
}

extension Feed {
    init(item: RSSFeedItem, source: String) {
        title = item.title ?? "!!No title found for this Feed"
        self.source = source
        keywords = Set(item.categories?.map { $0.value ?? "" } ?? [])
        description = item.description
        datePosted = item.pubDate ?? Date()
        url = URL(string: item.link!)!
    }
}
