//
//  FeedSourceCollection.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import FeedKit
import SwiftUI
import SwiftyJSON

class FeedSourceDelegate: ManagedRemoteUpdateProtocol {
    static let shared = FeedSourceDelegate()

    @ManagedData(.feedSourceList) var feedSourceList: [FeedSource]

    func refresh() async throws -> [FeedSource] {
        guard var result = try await _feedSourceList.retrive() else {
            throw BaseError.runtimeError("Feed source list fetched failed")
        }

        for source in feedSourceList {
            var source = source
            let parseResult = FeedParser(URL: source.url).parse()
            switch parseResult {
            case let .success(fetched):
                guard
                    let feeds = fetched.rssFeed?.items?
                        .map({ Feed(item: $0, source: source.name) })
                else {
                    throw BaseError.runtimeError(
                        "No feeds found for \(source.name)"
                    )
                }
                source.feed = feeds
                result.removeAll(where: { $0.name == source.name })
                result.append(source)
            case let .failure(error): throw error
            }
        }

        return result
    }
}

extension ManagedDataSource<[FeedSource]> {
    static let feedSource = ManagedDataSource(
        local: ManagedLocalStorage("feedSource", validDuration: 60 * 2),
        remote: FeedSourceDelegate.shared
    )
}
