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
        title: "我校成功举办2025年度教师教学能力提升营",
        source: Lorem.word,
        keywords: ["信息"],
        description: Lorem.sentences(2),
        datePosted: Date(),
        url: exampleURL,
        imageURL: URL(string: "https://www.teach.ustc.edu.cn/wp-content/uploads/2025/10/202510302.jpg")!,
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

        if let enclosure = item.enclosure, enclosure.attributes?.type == "image/jpeg",
            let urlString = enclosure.attributes?.url
        {
            imageURL = URL(string: urlString)
        }
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
