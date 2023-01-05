//
//  FeedSource.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import FeedKit
import SwiftUI

struct FeedSource {
    static var all: [FeedSource] = []

    var url: URL
    var name: String
    var id: UUID
    var description: String?
    var image: String?

    var cache: FeedCache.FeedSourceCache? {
        FeedCache.feedSourceCaches.first(where: { $0.id == self.id })
    }

    var parser: FeedParser {
        return FeedParser(URL: url)
    }

    func fetchRecentPost() async throws -> [Feed] {
        if cache != nil, !cache!.feeds.isEmpty, cache!.lastUpdated.addingTimeInterval(7200) > Date() {
            return cache!.feeds
        }

        let data = try await forceUpdatePost()
        return data
    }

    func forceUpdatePost() async throws -> [Feed] {
        debugPrint("!!! Refresh \(name) RSSFeedPost")
        let result = parser.parse()
        switch result {
        case let .success(fetch):
            if let feeds = fetch.rssFeed?.items?.map({ Feed(item: $0, source: self.name) }) {
                FeedCache.update(id: id, with: feeds)
                return feeds
            } else {
                throw EncodingError.invalidValue(fetch, .init(codingPath: [], debugDescription: ""))
            }
        case let .failure(error):
            throw error
        }
    }

    func updateRequest() {
        asyncCall(forceUpdatePost)
    }

    init(url: URL, name: String, description: String? = nil, image: String? = nil) {
        self.url = url
        self.name = name
        id = UUID(name: name, nameSpace: .oid)
        self.description = description
        self.image = image
        FeedSource.all.append(self)
    }
}
