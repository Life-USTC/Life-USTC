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

class FeedSource: ObservableObject {
    var url: URL
    var name: String
    var id: UUID
    var description: String?
    var image: String? // system image
    var color: Color?

    func parseCache() async throws -> [Feed] {
        guard let cache = FeedCache.feedSourceCache(using: id) else {
            throw BaseError.runtimeError("No id found inside cache for \(name)")
        }

        return cache.feeds
    }

    func refreshCache() async throws {
        print("!!! Refresh \(name) RSSFeedPost")
        let result = FeedParser(URL: url).parse()
        switch result {
        case let .success(fetch):
            if let feeds = fetch.rssFeed?.items?.map({ Feed(item: $0, source: self.name) }) {
                FeedCache.update(using: id, with: feeds)
                return
            }
        case let .failure(error):
            throw error
        }
    }

    init(url: URL,
         name: String,
         id: UUID? = nil,
         description: String? = nil,
         image: String? = nil,
         color: Color? = nil)
    {
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

//        userTriggerRefresh(forced: false)
    }
}

extension FeedSource {
    var requireUpdate: Bool {
        guard let cache = FeedCache.feedSourceCache(using: id) else {
            return true
        }
        return cache.feeds.isEmpty || cache.lastUpdated.addingTimeInterval(7200) < Date()
    }

    var featureWithView: FeatureWithView {
        .init(image: image ?? "doc.richtext",
              title: name,
              subTitle: description ?? "",
              destinationView: FeedSourceView(feedSource: self))
    }

    /// Return a given amount of Feed from cache, which should contain all posts
    static func recentFeeds(number: Int?) async throws -> [Feed] {
        var result: [Feed] = []
        var important: [Feed] = []
        for source in FeedSource.allToShow {
//            let feeds = try await source.retrive()
            let feeds: [Feed] = []
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

        if let number {
            return Array(result.prefix(number))
        } else {
            return result
        }
    }

    static var all: [FeedSource] = {
        do {
            let data = try AutoUpdateDelegate.feedList.retriveLocal()
            var data_json: JSON?
            if let data {
                data_json = try JSON(data: data)
            } else {
                if let path = Bundle.main.path(forResource: localFeedJSONName, ofType: "json") {
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
                let color = colorString != nil ? Color(hex: colorString!) : Color(hex: "#72C078")
                result.append(FeedSource(url: url, name: name, description: description, image: image, color: color))
            }

            return result
        } catch {
            print(error)
            return []
        }
    }()

    static var allToShow: [FeedSource] {
        let namesToRemove: [String] = .init(rawValue: UserDefaults.standard.string(forKey: "feedSourceNameListToRemove") ?? "") ?? []

        var result = all
        for name in namesToRemove {
            result.removeAll(where: { $0.name == name })
        }
        return result
    }

    static func find(_ name: String) -> FeedSource? {
        all.first(where: { $0.name == name })
    }
}
