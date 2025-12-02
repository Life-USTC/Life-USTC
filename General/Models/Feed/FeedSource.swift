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
            let feedSource = FeedSource(
                url: URL(string: sourceJSON["url"].stringValue)!,
                name: sourceJSON["locales"]["zh"].stringValue,
                detailText: sourceJSON["description"].stringValue,
                image: sourceJSON["icons"]["sf-symbols"].stringValue,
                colorHex: sourceJSON["color"].stringValue
            )

            SwiftDataStack.modelContext.insert(feedSource)

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

            if let feeds = parseResult?.rssFeed?.items?
                .map({
                    Feed(item: $0, source: feedSource)
                })
                ?? parseResult?.atomFeed?.entries?
                .map({
                    Feed(entry: $0, source: feedSource)
                })
            {
                for feed in feeds {
                    SwiftDataStack.modelContext.insert(feed)
                }
            }
        }
    }
}
