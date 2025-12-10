//
//  FeedSource.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import FeedKit
import SwiftData
import SwiftUI
import SwiftyJSON

@Model
final class FeedSource {
    var feeds: [Feed] = []

    @Attribute(.unique) var url: URL
    var name: String
    var detailText: String?
    var image: String?  // sf symbol
    var colorHex: String?

    init(
        url: URL,
        name: String,
        detailText: String? = nil,
        image: String? = nil,
        colorHex: String? = nil,
        feed: [Feed] = []
    ) {
        self.url = url
        self.name = name
        self.detailText = detailText
        self.image = image
        self.colorHex = colorHex
    }
}

extension Feed {
    @MainActor
    static func update() async throws {
        @AppStorage("feedSourceNameListToRemove") var removedNameList: [String] = []

        let (data, _) = try await URLSession.shared.data(
            from: SchoolSystem.current.remoteFeedURL
        )
        let json = try JSON(data: data)

        for sourceJSON in json["sources"].arrayValue {
            let sourceURL = URL(string: sourceJSON["url"].stringValue)!
            let sourceName = sourceJSON["locales"]["zh"].stringValue
            let sourceDescription = sourceJSON["description"].stringValue
            let sourceImage = sourceJSON["icons"]["sf-symbols"].stringValue
            let sourceColor = sourceJSON["color"].stringValue

            let feedSource = try SwiftDataStack.modelContext.upsert(
                predicate: #Predicate<FeedSource> { $0.url == sourceURL },
                update: { source in
                    source.name = sourceName
                    source.detailText = sourceDescription
                    source.image = sourceImage
                    source.colorHex = sourceColor
                },
                create: {
                    FeedSource(
                        url: sourceURL,
                        name: sourceName,
                        detailText: sourceDescription,
                        image: sourceImage,
                        colorHex: sourceColor
                    )
                }
            )

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
                    let feedColorHex = sourceColor

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
                    let feedColorHex = sourceColor

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
    }
}
