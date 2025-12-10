//
//  Feed.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import FeedKit
import Foundation
import SwiftData
import SwiftUI

@Model
final class Feed {
    @Relationship(deleteRule: .cascade, inverse: \FeedSource.feeds) var source: FeedSource?

    var title: String
    var keywords: Set<String>
    var detailText: String?
    var datePosted: Date
    @Attribute(.unique) var url: URL
    var imageURL: URL?
    var colorHex: String?

    var color: Color {
        if let hex = colorHex {
            return Color(hex: hex)
        }
        return source?.color ?? Color.fromSeed(title)
    }

    init(
        title: String,
        keywords: Set<String>,
        detailText: String? = nil,
        datePosted: Date,
        url: URL,
        imageURL: URL? = nil,
        colorHex: String? = nil
    ) {
        self.title = title
        self.keywords = keywords
        self.detailText = detailText
        self.datePosted = datePosted
        self.url = url
        self.imageURL = imageURL
        self.colorHex = colorHex
    }
}

extension Feed {
    @MainActor
    static func update() async throws {
        if SwiftDataStack.isPresentingDemo { return }

        try await FeedSource.update()

        let descriptor = FetchDescriptor<FeedSource>()
        let feedSources = try SwiftDataStack.modelContext.fetch(descriptor)

        for feedSource in feedSources {
            try await Feed.update(for: feedSource)
        }
    }

    @MainActor
    static func update(for feedSource: FeedSource) async throws {
        if SwiftDataStack.isPresentingDemo { return }

        let parseResult = try? await withCheckedThrowingContinuation { continuation in
            FeedParser(URL: feedSource.url)
                .parseAsync { result in
                    switch result {
                    case .success(let success):
                        continuation.resume(returning: success)
                    case .failure(let failure):
                        continuation.resume(throwing: failure)
                    }
                }
        }

        if let rssItems = parseResult?.rssFeed?.items {
            for item in rssItems {
                let feedURL = URL(string: item.link ?? "example.com")!
                let feedTitle = item.title ?? "!!No title found for this Feed"
                let feedKeywords = Set(item.categories?.map { $0.value ?? "" } ?? [])
                let feedDescription = item.description
                let feedDate = item.pubDate ?? Date()
                let feedColorHex = feedSource.colorHex

                var feedImageURL: URL?
                if let enclosure = item.enclosure, enclosure.attributes?.type == "image/jpeg",
                    let urlString = enclosure.attributes?.url
                {
                    feedImageURL = URL(string: urlString)
                }

                try SwiftDataStack.modelContext.upsert(
                    predicate: #Predicate<Feed> { $0.url == feedURL },
                    update: { feed in
                        feed.title = feedTitle
                        feed.keywords = feedKeywords
                        feed.detailText = feedDescription
                        feed.datePosted = feedDate
                        feed.imageURL = feedImageURL
                        feed.colorHex = feedColorHex
                        feed.source = feedSource
                    },
                    create: {
                        let newFeed = Feed(
                            title: feedTitle,
                            keywords: feedKeywords,
                            detailText: feedDescription,
                            datePosted: feedDate,
                            url: feedURL,
                            imageURL: feedImageURL,
                            colorHex: feedColorHex
                        )
                        newFeed.source = feedSource
                        return newFeed
                    }
                )
            }
        } else if let atomEntries = parseResult?.atomFeed?.entries {
            for entry in atomEntries {
                let feedURL = URL(string: entry.links?.first?.attributes?.href ?? "example.com")!
                let feedTitle = entry.title ?? "!!No title found for this Feed"
                let feedKeywords = Set(entry.categories?.map { $0.attributes?.label ?? "" } ?? [])
                let feedDescription = entry.summary?.value
                let feedDate = entry.updated ?? Date()
                let feedColorHex = feedSource.colorHex

                try SwiftDataStack.modelContext.upsert(
                    predicate: #Predicate<Feed> { $0.url == feedURL },
                    update: { feed in
                        feed.title = feedTitle
                        feed.keywords = feedKeywords
                        feed.detailText = feedDescription
                        feed.datePosted = feedDate
                        feed.colorHex = feedColorHex
                        feed.source = feedSource
                    },
                    create: {
                        let newFeed = Feed(
                            title: feedTitle,
                            keywords: feedKeywords,
                            detailText: feedDescription,
                            datePosted: feedDate,
                            url: feedURL,
                            colorHex: feedColorHex
                        )
                        newFeed.source = feedSource
                        return newFeed
                    }
                )
            }
        }
    }

    convenience init(item: RSSFeedItem, source: FeedSource) {
        self.init(
            title: item.title ?? "!!No title found for this Feed",
            keywords: Set(item.categories?.map { $0.value ?? "" } ?? []),
            detailText: item.description,
            datePosted: item.pubDate ?? Date(),
            url: URL(string: item.link ?? "example.com")!,
            colorHex: source.colorHex
        )

        self.source = source

        if let enclosure = item.enclosure, enclosure.attributes?.type == "image/jpeg",
            let urlString = enclosure.attributes?.url
        {
            self.imageURL = URL(string: urlString)
        }
    }

    convenience init(entry: AtomFeedEntry, source: FeedSource) {
        self.init(
            title: entry.title ?? "!!No title found for this Feed",
            keywords: Set(entry.categories?.map { $0.attributes?.label ?? "" } ?? []),
            detailText: entry.summary?.value,
            datePosted: entry.updated ?? Date(),
            url: URL(string: entry.links?.first?.attributes?.href ?? "example.com")!,
            colorHex: source.colorHex
        )

        self.source = source
    }
}
