//
//  FeedSource.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import FeedKit
import SwiftUI
import SwiftyJSON

private let importantLabels: Set<String> = ["!!important", "Important", "!!notice"]

class FeedSource {
    static var all: [FeedSource] {
        do {
            let data = try AutoUpdateDelegate.feedList.retriveLocal()
            var data_json: JSON?
            if let data {
                data_json = try JSON(data: data)
            } else {
                if let path = Bundle.main.path(forResource: "feed_source", ofType: "json") {
                    let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                    data_json = try JSON(data: data)
                }
            }

            guard let data_json else {
                return []
            }

            var result: [FeedSource] = []
            for (_, source) in data_json["sources"] {
                let url = URL(string: source["url"].stringValue)!
                let name = source["locales"]["zh"].stringValue
                let description = source["description"].stringValue
                let image = source["icons"]["sf-symbols"].string ?? "newspaper"
                let colorString = source["color"].string // hex string with "#"
                let color = colorString != nil ? Color(hex: colorString!) : nil
                result.append(FeedSource(url: url, name: name, description: description, image: image, color: color))
            }

            return result
        } catch {
            print(error)
            return []
        }
    }

    static var allToShow: [FeedSource] {
        let namesToRemove: [String] = .init(rawValue: UserDefaults().string(forKey: "feedSourceNameListToRemove") ?? "") ?? []

        var result = all
        for name in namesToRemove {
            result.removeAll(where: { $0.name == name })
        }
        return result
    }

    static func find(_ name: String) -> FeedSource? {
        all.first(where: { $0.name == name })
    }

    var url: URL
    var name: String
    var id: UUID
    var description: String?
    var image: String? // system image
    var color: Color?

    func fetchRecentPost() async throws -> [Feed] {
        let cache = FeedCache.feedSourceCache(using: id)
        if cache != nil, !cache!.feeds.isEmpty, cache!.lastUpdated.addingTimeInterval(7200) > Date() {
            return cache!.feeds
        }

        let data = try await forceUpdatePost()
        return data
    }

    func forceUpdatePost(loopCount: Int = 0) async throws -> [Feed] {
        do {
            print("!!! Refresh \(name) RSSFeedPost")
            let result = FeedParser(URL: url).parse()
            switch result {
            case let .success(fetch):
                if let feeds = fetch.rssFeed?.items?.map({ Feed(item: $0, source: self.name) }) {
                    FeedCache.update(using: id, with: feeds)
                    return feeds
                }
            case let .failure(error):
                throw error
            }
        } catch {}

        try await Task.sleep(for: .seconds(5))
        if loopCount < 10 {
            return try await forceUpdatePost(loopCount: loopCount + 1)
        } else {
            throw BaseError.runtimeError("Error when parsing posts")
        }
    }

    init(url: URL, name: String, id: UUID? = nil, description: String? = nil, image: String? = nil, color: Color? = nil) {
        self.url = url
        self.name = name
        if let id {
            self.id = id
        } else {
            self.id = UUID(name: name, nameSpace: .oid)
        }
        self.description = description
        self.image = image
        self.color = color
    }

    /// Return a given amount of Feed from cache, which should contain all posts
    static func recentFeeds(number: Int?) async throws -> [Feed] {
        var result: [Feed] = []
        var important: [Feed] = []
        for source in FeedSource.allToShow {
            let feeds = try await source.fetchRecentPost()
            for feed in feeds {
                if feed.keywords.isDisjoint(with: importantLabels) {
                    result.append(feed)
                } else {
                    important.append(feed)
                }
            }
        }

        result.sort(by: { $0.datePosted > $1.datePosted })
        important.sort(by: { $0.datePosted > $1.datePosted })
        result.insert(contentsOf: important, at: 0)

        if (number ?? 1) > result.count {
            for source in FeedSource.allToShow {
                _ = try await source.forceUpdatePost()
            }
            return try await recentFeeds(number: number)
        }

        // TODO: (BUG) if we don't "force" this function to be async, it seems to run off main thread,
        // and since sorting this feeds might take a while, this could lead to UI unresponsiveness.
        // adding a sleep here to show a progressview
        try await Task.sleep(for: .microseconds(300))

        if let number {
            return Array(result.prefix(number))
        } else {
            return result
        }
    }
}

// Delegate to update a given file from URL, and store it locally in the app's document directory
// also provides method to retrive data from local file, asynchronizely
class AutoUpdateDelegate {
    var name: String
    var remoteURL: URL
    var localURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
    }

    init(name: String, remoteURL: URL) {
        self.name = name
        self.remoteURL = remoteURL
    }

    func update() async throws {
        print("network<\(name)>: updating from url \(remoteURL)")
        let data = try await URLSession.shared.data(from: remoteURL)
        try data.0.write(to: localURL)
    }

    func isAvailable() -> Bool {
        FileManager.default.fileExists(atPath: localURL.path)
    }

    func retrive() async throws -> Data {
        if isAvailable() {
            print("network<\(name)>: local cache found, using it")
            return try Data(contentsOf: localURL)
        } else {
            print("network<\(name)>: local cache not found, updating")
            try await update()
            return try await retrive()
        }
    }

    func retriveLocal() throws -> Data? {
        if isAvailable() {
            print("network<\(name)>: local cache found, using it")
            return try Data(contentsOf: localURL)
        } else {
            print("network<\(name)>: local cache not found, updating for next time")
            Task {
                try? await update()
            }
            return nil
        }
    }
}

let feedListURL = URL(string: "https://life-ustc.tiankaima.dev/feed_source.json")!
extension AutoUpdateDelegate {
    static var feedList: AutoUpdateDelegate = .init(name: "feed_source.json", remoteURL: feedListURL)

    static var allFiles: [AutoUpdateDelegate] {
        [feedList]
    }

    static func updateAll() async throws {
        for file in allFiles {
            try await file.update()
        }
    }
}
