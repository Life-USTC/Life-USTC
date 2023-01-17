//
//  FeedCache.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import SwiftUI

/// Abstract about Feed cache process
class FeedCache {
    static var defaults = UserDefaults.standard

    /// Maintain an array of Feed, id linked with single FeedSource
    struct FeedSourceCache: Codable {
        var id: UUID
        var feeds: [Feed]
        var lastUpdated: Date
    }

    private static var feedSourceCaches: [FeedSourceCache] = {
        do {
            let decoder = JSONDecoder()
            if let feedSourceCacheData = defaults.data(forKey: "feedSourceCache") {
                return try decoder.decode([FeedSourceCache].self, from: feedSourceCacheData)
            }
        } catch {}
        return []
    }()

    /// Load everything from disk
    static func load() throws {
        let decoder = JSONDecoder()
        if let feedSourceCacheData = defaults.data(forKey: "feedSourceCache") {
            feedSourceCaches = try decoder.decode([FeedSourceCache].self, from: feedSourceCacheData)
        }
    }

    static func save() throws {
        let encoder = JSONEncoder()
        let feedSourceCacheData = try encoder.encode(feedSourceCaches)
        defaults.set(feedSourceCacheData, forKey: "feedSourceCache")
    }

    static func update(using id: UUID, with: [Feed]) {
        feedSourceCaches.removeAll(where: { $0.id == id })
        feedSourceCaches.append(FeedSourceCache(id: id, feeds: with, lastUpdated: Date()))
        exceptionCall(save)
    }

    static func feedSourceCache(using id: UUID) -> FeedSourceCache? {
        return feedSourceCaches.first(where: { $0.id == id })
    }
}

extension ContentView {
    func loadFeedCache() throws {
//        try FeedCache.load()
    }
}
