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
    var colorHex: String?

    static let example = Feed(
        title: Lorem.sentence,
        source: Lorem.word,
        keywords: [Lorem.word, Lorem.word],
        description: Lorem.sentences(2),
        datePosted: Date(),
        url: exampleURL,
        imageURL: URL(string: "https://picsum.photos/300/300")!,
        colorHex: "ff0000"
    )
}

extension Feed {
    init(item: RSSFeedItem, source: FeedSource) {
        title = item.title ?? "!!No title found for this Feed"
        self.source = source.name
        keywords = Set(item.categories?.map { $0.value ?? "" } ?? [])
        description = item.description
        datePosted = item.pubDate ?? Date()
        url = URL(string: item.link!)!
        colorHex = source.colorHex
    }
    
    init(entry: AtomFeedEntry, source: FeedSource) {
        title = entry.title ?? "!!No title found for this Feed"
        self.source = source.name
        keywords = Set(entry.categories?.map { $0.attributes?.label ?? "" } ?? [])
        description = entry.summary?.value
        datePosted = entry.updated ?? Date()
        url = URL(string: entry.links?.first?.attributes?.href ?? "example.com")!
        colorHex = source.colorHex
    }
}
