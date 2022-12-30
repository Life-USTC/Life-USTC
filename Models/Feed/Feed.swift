//
//  Feed.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import SwiftUI

/// Maintain a list of FeedPost, usually comes from one feed source
struct FeedPostCache: Codable {
    var lastUpdated: Date
    var posts: [FeedPost]
    var id: UUID
}

/// Make a list that links url to id.
struct FeedPostIDCache: Codable {
    var url: URL
    var id: UUID
}

var postIDCacheList: [FeedPostIDCache] = [] {
    didSet {
        do {
            try savePostIDCache()
        } catch {
            print(error)
        }
    }
}

var postCacheList: [FeedPostCache] = [] {
    didSet {
        do {
            try savePostCache()
        } catch {
            print(error)
        }
    }
}

/*
 MARK: Question, should this be async?
 MARK: I'm questioning since majority of document/tutorials would suggest that file read/write is done almost instantly,
 MARK: but I highly doubt that...
 */
func loadPostCache() throws {
    let decoder = JSONDecoder()
    if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        var fileURL = dir.appendingPathComponent("postCache.json")
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
            return
        }
        var data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        postCacheList = try decoder.decode([FeedPostCache].self, from: data)
        fileURL = dir.appendingPathComponent("postIDCacheList.json")
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            // create the file if it does not exist
            FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
            return
        }
        data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        postIDCacheList = try decoder.decode([FeedPostIDCache].self, from: data)
    }
}

/*
 TODO: these two functions might be called more than expected, try refactor them to something like dispatch with signals,
 TODO: saving to file only when post stops to refresh or something like that
*/
func savePostCache() throws {
    if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let fileURL = dir.appendingPathComponent("postCache.json")
        let encoder = JSONEncoder()
        let data = try encoder.encode(postCacheList)
        try data.write(to: fileURL, options: .atomic)
    }
}

func savePostIDCache() throws {
    if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let fileURL = dir.appendingPathComponent("postIDCacheList.json")
        let encoder = JSONEncoder()
        let data = try encoder.encode(postIDCacheList)
        try data.write(to: fileURL, options: .atomic)
    }
}

/// Return a given amount of FeedPost in a async way.
func showUserFeedPost(number: Int?) async throws -> [FeedPost] {
    var result: [FeedPost] = []
    var important: [FeedPost] = []
    for cache in postCacheList {
        for post in cache.posts {
            // TODO: should cover more labels, [Important, !warning], sth like that.
            if post.keywords.contains("!important") {
                important.append(post)
            } else {
                result.append(post)
            }
        }
    }
    // since we return the result directly to view, this should be sorted in a reversed order
    result.sort(by: { $0.datePosted > $1.datePosted })
    important.sort(by: { $0.datePosted > $1.datePosted })
    result.insert(contentsOf: important, at: 0)

    // if the result does not have enough posts, force refresh all feeds
    if result.count < 10 {
        for source in feedSourceList {
            try _ = await source.forceUpdatePost()
        }
        return try await showUserFeedPost(number: number)
    }
    
    if let number {
        return Array(result.prefix(number))
    } else {
        return result
    }
}
