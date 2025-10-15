//
//  FeedDelegate.swift
//  学在科大
//
//  Created by TianKai Ma on 10/15/25.
//

import FeedKit
import SwiftUI
import SwiftyJSON

class FeedDelegate: ManagedRemoteUpdateProtocol<[FeedSource]> {
    static let shared = FeedDelegate()

    @AppStorage("feedSourceNameListToRemove") var removedNameList: [String] = []

    override func refresh() async throws -> [FeedSource] {

        let (data, _) = try await URLSession.shared.data(
            from: SchoolExport.shared.remoteFeedURL
        )
        let json = try JSON(data: data)

        let initialSources = json["sources"].arrayValue
            .map { subJson in
                FeedSource(
                    url: URL(string: subJson["url"].stringValue)!,
                    name: subJson["locales"]["zh"].stringValue,
                    description: subJson["description"].stringValue,
                    image: subJson["icons"]["sf-symbols"].stringValue,
                    colorHex: subJson["color"].stringValue
                )
            }
            .filter { !removedNameList.contains($0.name) }

        let feedSources = await withTaskGroup(of: FeedSource.self) { group in
            for source in initialSources {
                group.addTask {
                    var updatedSource = source

                    let parseResult = try? await withCheckedThrowingContinuation { continuation in
                        FeedParser(URL: source.url)
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
                            Feed(item: $0, source: updatedSource)
                        })
                        ?? parseResult?.atomFeed?.entries?
                        .map({
                            Feed(entry: $0, source: updatedSource)
                        })
                    {
                        updatedSource.feed = feeds
                    }

                    return updatedSource
                }
            }

            var results = [FeedSource]()
            for await source in group {
                results.append(source)
            }
            return results
        }

        return feedSources
    }
}

extension ManagedDataSource<[FeedSource]> {
    static let feedSources = ManagedDataSource(
        local: ManagedLocalStorage("feedSources", validDuration: 60 * 2),
        remote: FeedDelegate.shared
    )
}
