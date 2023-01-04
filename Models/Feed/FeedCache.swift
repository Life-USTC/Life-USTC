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
    static let importantLabels: Set<String> = ["!!important", "Important", "!!notice"]
    
    /// Maintain an array of Feed, id linked with single FeedSource
    struct FeedSourceCache: Codable {
        var id: UUID
        var feeds: [Feed]
        var lastUpdated: Date
    }
    
    static var feedSourceCaches: [FeedSourceCache] = [] {
        didSet {
            exceptionCall(save)
        }
    }

    /// Load everything from disk
    static func load() throws {
        let decoder = JSONDecoder()
        if let feedSourceCacheData = defaults.data(forKey: "feedSourceCache") {
            feedSourceCaches = try decoder.decode([FeedSourceCache].self, from: feedSourceCacheData)
        }
    }
    
    static func save() throws {
        print("Save called")
        let encoder = JSONEncoder()
        let feedSourceCacheData = try encoder.encode(feedSourceCaches)
        defaults.set(feedSourceCacheData, forKey: "feedSourceCache")
    }
    
    static func update(id: UUID, with: [Feed]) {
        feedSourceCaches.removeAll(where: {$0.id == id})
        feedSourceCaches.append(FeedSourceCache(id: id, feeds: with, lastUpdated: Date()))
    }

    /// Return a given amount of Feed from cache, which should contain all posts
    static func recentFeeds(number: Int?) async throws -> [Feed] {
        var result: [Feed] = []
        var important: [Feed] = []
        for cache in feedSourceCaches {
            for cache in cache.feeds {
                if cache.keywords.isDisjoint(with: importantLabels) {
                    result.append(cache)
                } else {
                    important.append(cache)
                }
            }
        }
        
        result.sort(by: { $0.datePosted > $1.datePosted })
        important.sort(by: { $0.datePosted > $1.datePosted })
        result.insert(contentsOf: important, at: 0)

        if result.count < 10 {
            for source in FeedSource.all {
                // signal every source to reload
                try _ = await source.forceUpdatePost()
            }
            // sleep for 1 second before continues; for future versions, try balancing the number for max performance
            try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
            return try await recentFeeds(number: number)
        }

        if let number {
            return Array(result.prefix(number))
        } else {
            return result
        }
    }

}

extension ContentView {
    func loadFeedCache() throws {
        try FeedCache.load()
    }
}
