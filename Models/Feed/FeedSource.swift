//
//  FeedSource.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import FeedKit
import SwiftUI

class FeedSource {
    static var all: [FeedSource] = [FeedSource(url: ustcOAAFeedURL, name: "教务处", image: "person.crop.square.fill.and.at.rectangle"),
                                    FeedSource(url: ustcHomePageFeedURL, name: "校主页", image: "icloud.square.fill")]

    var url: URL
    var name: String
    var id: UUID
    var description: String?
    var image: String? // system image

    func fetchRecentPost() async throws -> [Feed] {
        let cache = FeedCache.feedSourceCache(using: id)
        if cache != nil, !cache!.feeds.isEmpty, cache!.lastUpdated.addingTimeInterval(7200) > Date() {
            return cache!.feeds
        }

        let data = try await forceUpdatePost()
        return data
    }

    func forceUpdatePost() async throws -> [Feed] {
        print("!!! Refresh \(name) RSSFeedPost")
        let result = FeedParser(URL: url).parse()
        switch result {
        case let .success(fetch):
            if let feeds = fetch.rssFeed?.items?.map({ Feed(item: $0, source: self.name) }) {
                FeedCache.update(using: id, with: feeds)
                return feeds
            } else {
                throw EncodingError.invalidValue(fetch, .init(codingPath: [], debugDescription: ""))
            }
        case let .failure(error):
            throw error
        }
    }

    init(url: URL, name: String, id: UUID? = nil, description: String? = nil, image: String? = nil) {
        self.url = url
        self.name = name
        if let id {
            self.id = id
        } else {
            self.id = UUID(name: name, nameSpace: .oid)
        }
        self.description = description
        self.image = image
    }
}