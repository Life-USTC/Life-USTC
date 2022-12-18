//
//  FeedModel.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import Foundation
import FeedKit

enum FeedType: Codable {
    case rss
    case builtin
}

let findImageURL = try! Regex(#"(htt[^\s]+ustc[^\s]+(jpg|jpeg|png|tiff)\b)"#)

struct Post: Codable {
    var url: URL? // how could a Post not have a url linked to it???
    var title: String
    var keywords: [String]
    var timePosted: Date
    var source: String
    var image: URL?
    var description: String?
    var id = UUID()
    
    mutating func matchUUID() {
        // find the url in the postIDCacheList, if that url is already in the list, then use the same id
        if let url = url {
            if let index = postIDCacheList.firstIndex(where: {$0.url == url}) {
                self.id = postIDCacheList[index].id
            } else {
                postIDCacheList.append(PostIDChache(url: url, id: id))
                savePostIDCache()
            }
        }
    }
    
    init(url: URL? = nil, title: String, keywords: [String], timePosted: Date, source: String, image: URL? = nil, description: String? = nil) {
        self.url = url
        self.title = title
        self.keywords = keywords
        self.timePosted = timePosted
        self.source = source
        self.image = image
        self.description = description
        matchUUID()
    }
    
    init(item: RSSFeedItem, source: String) {
        let httpTohttpsRegex = try! Regex("^http[^s]//")
        self.url = URL(string: item.link?.replacing(httpTohttpsRegex, with: "https://") ?? "https://example.com")
        self.title = item.title ?? "No title Found"
        self.keywords = item.categories?.map {$0.value ?? ""} ?? []
        self.timePosted = item.pubDate ?? Date()
        self.source = source
        let match = item.content?.contentEncoded?.firstMatch(of: findImageURL)
        if let match {
            self.image = URL(string: String(match.0))
        }
        self.description = item.description
        matchUUID()
    }
}

struct PostCache: Codable {
    var time: Date
    var posts: [Post]
    var id: UUID // to match feedSource
}

struct PostIDChache: Codable {
    var url: URL
    var id: UUID
}

var postIDCacheList: [PostIDChache] = []
var postCacheList: [PostCache] = []

// when loading the app, try load the cache from local storage, related code are written here:
func loadPostCache() {
    // load the cache from /document/postCache.json
    // also load the postIDCacheList.json
    let decoder = JSONDecoder()
    
    if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let fileURL = dir.appendingPathComponent("postCache.json")
        do {
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                // create the file if it does not exist
                FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
                return
            }
            
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            postCacheList = try decoder.decode([PostCache].self, from: data)
        } catch {
            print(error)
        }
        
        let fileURL2 = dir.appendingPathComponent("postIDCacheList.json")
        do {
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                // create the file if it does not exist
                FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
                return
            }
            
            let data = try Data(contentsOf: fileURL2, options: .mappedIfSafe)
            postIDCacheList = try decoder.decode([PostIDChache].self, from: data)
        } catch {
            print(error)
        }
        
//        print(postCacheList)
//        print(postIDCacheList)
        
    }
}

func savePostCache() {
    // save the cache to /document/postCache.json
    // also save the postIDCacheList.json
    if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let fileURL = dir.appendingPathComponent("postCache.json")
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(postCacheList)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print(error)
        }
    }
}

func savePostIDCache() {
    if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let fileURL = dir.appendingPathComponent("postIDCacheList.json")
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(postIDCacheList)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print(error)
        }
    }
}

var depth = 0
func showUserFeedPost(number: Int?) -> [Post] {
    // load several posts from the cache (sorted with timePosted)
    // also top posts from the cache if the post is marked with "!important" as a keyword
    
    var result: [Post] = []
    var important: [Post] = []
    for cache in postCacheList {
        for post in cache.posts {
            if post.keywords.contains("!important") {
                important.append(post)
            } else {
                result.append(post)
            }
        }
    }
    result.sort(by: {$0.timePosted > $1.timePosted})
    important.sort(by: {$0.timePosted > $1.timePosted})
    result.insert(contentsOf: important, at: 0)
    
    // if the result does not have enough posts, force refresh all feeds
    if result.count < 10 {
        for source in feedSourceList {
            _ = source.fetchRecentPost()
        }
        return []
    }
    
    if let number {
        return Array(result.prefix(number))
    } else {
        return result
    }
}

protocol FeedSource {
    var type: FeedType { get }
    var name: String { get }
    var id: UUID { get }
    
    func fetchRecentPost() -> [Post] // this could be loaded from local storage
    func forceGetRecentPost() -> [Post] // this requires a network request
}

var feedSourceList: [FeedSource] = defaultFeedSources // all new sources should be added to this list

struct RSSFeedSource: FeedSource{
    var type: FeedType = .rss
    var url: URL
    var name: String
    var id = UUID()
    
    func fetchRecentPost() -> [Post] {
        // if the cache is not expired, return the cache
        // expired means the cache is older than 2 hours
        // if the cache is expired, return the cache for now and perform a background update
        // if the cache is not found, call forceGetRecentPost()
        
        let cache = postCacheList.first(where: {$0.id == self.id})
        if let cache {
            if cache.posts.count == 0 {
                let data = self.forceGetRecentPost()
                return data
            }
            if cache.time > Date().addingTimeInterval(-7200) {
                return cache.posts
            } else {
                DispatchQueue.global(qos: .background).async {
                    let data = self.forceGetRecentPost()
                    postCacheList.append(PostCache(time: Date(), posts: data, id: self.id))
                    savePostCache()
                }
                return cache.posts
            }
        } else {
            let data = self.forceGetRecentPost()
            return data
        }
    }
    
    func forceGetRecentPost() -> [Post] {
        debugPrint("!!! Refresh \(self.name) RSSFeedPost")
        let parser = FeedParser(URL: self.url)
        let result = parser.parse()
        switch result {
        case .success(let feed):
            let data: [Post] = feed.rssFeed?.items?.map {Post(item: $0, source: self.name)} ?? []
            // this means the feed is updated, so we need to update the cache
            // logic problem here, remove the old cache and add the new one
            postCacheList.removeAll(where: {$0.id == self.id})
            postCacheList.append(PostCache(time: Date(), posts: data, id: self.id))
            savePostCache()
            return data
        case .failure(let error):
            print(error)
            return []
        }
    }
    
    init(url: URL, name: String, id: UUID, flag: Bool = false) {
        self.url = url
        self.name = name
        self.id = id
        
        // add to the feedSourceList
        if flag {
            feedSourceList.append(self)
        }
    }
}


