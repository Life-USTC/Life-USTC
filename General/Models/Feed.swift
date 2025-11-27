//
//  Feed.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import FeedKit
import Foundation
import SwiftData

@Model
final class Feed {
    var title: String
    var source: String
    var keywords: Set<String>
    var detailText: String?
    var datePosted: Date
    var url: URL
    var imageURL: URL?
    var colorHex: String?
    @Relationship var sourceRef: FeedSource?

    init(
        title: String,
        source: String,
        keywords: Set<String>,
        detailText: String? = nil,
        datePosted: Date,
        url: URL,
        imageURL: URL? = nil,
        colorHex: String? = nil
    ) {
        self.title = title
        self.source = source
        self.keywords = keywords
        self.detailText = detailText
        self.datePosted = datePosted
        self.url = url
        self.imageURL = imageURL
        self.colorHex = colorHex
    }
}

extension Feed {
    convenience init(item: RSSFeedItem, source: FeedSource) {
        self.init(
            title: item.title ?? "!!No title found for this Feed",
            source: source.name,
            keywords: Set(item.categories?.map { $0.value ?? "" } ?? []),
            detailText: item.description,
            datePosted: item.pubDate ?? Date(),
            url: URL(string: item.link ?? "example.com")!,
            colorHex: source.colorHex
        )

        self.sourceRef = source

        if let enclosure = item.enclosure, enclosure.attributes?.type == "image/jpeg",
            let urlString = enclosure.attributes?.url
        {
            self.imageURL = URL(string: urlString)
        }
    }

    convenience init(entry: AtomFeedEntry, source: FeedSource) {
        self.init(
            title: entry.title ?? "!!No title found for this Feed",
            source: source.name,
            keywords: Set(entry.categories?.map { $0.attributes?.label ?? "" } ?? []),
            detailText: entry.summary?.value,
            datePosted: entry.updated ?? Date(),
            url: URL(string: entry.links?.first?.attributes?.href ?? "example.com")!,
            colorHex: source.colorHex
        )
        self.sourceRef = source
    }
}
