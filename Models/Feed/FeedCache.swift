//
//  FeedCache.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import SwiftUI

/// Abstract about Feed cache process
// After v1.0.2, use document/FeedSourceCache.json to store FeedSourceCache
enum FeedCache {
    /// Maintain an array of Feed, id linked with single FeedSource
    struct FeedSourceCache: Codable {
        var id: UUID
        var feeds: [Feed]
        var lastUpdated: Date
    }

    static var fileURL: URL {
        try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("FeedSourceCache.json")
    }

    private static var feedSourceCaches: [FeedSourceCache] = {
        do {
            let decoder = JSONDecoder()
            let feedSourceCacheData = try Data(contentsOf: fileURL)
            return try decoder.decode([FeedSourceCache].self, from: feedSourceCacheData)
        } catch {}
        return []
    }()

    /// Load everything from disk
    static func load() throws {
        let decoder = JSONDecoder()
        let feedSourceCacheData = try Data(contentsOf: fileURL)
        feedSourceCaches = try decoder.decode([FeedSourceCache].self, from: feedSourceCacheData)
    }

    static func save() throws {
        let encoder = JSONEncoder()
        let feedSourceCacheData = try encoder.encode(feedSourceCaches)
        let fileURL = try FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("FeedSourceCache.json")
        try feedSourceCacheData.write(to: fileURL)
    }

    static func update(using id: UUID, with: [Feed]) {
        feedSourceCaches.removeAll(where: { $0.id == id })
        feedSourceCaches.append(FeedSourceCache(id: id, feeds: with, lastUpdated: Date()))
        exceptionCall(save)
    }

    static func feedSourceCache(using id: UUID) -> FeedSourceCache? {
        feedSourceCaches.first(where: { $0.id == id })
    }
}
