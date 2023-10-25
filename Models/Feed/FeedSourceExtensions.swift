//
//  FeedSourceExtensions.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import FeedKit
import SwiftUI
import SwiftyJSON

class FeedSourceDelegate: ManagedRemoteUpdateProtocol<[FeedSource]> {
    static let shared = FeedSourceDelegate()

    @AppStorage("feedSourceNameListToRemove") var removedNameList: [String] = []
    @ManagedData(.feedSourceList) var feedSourceList: [FeedSource]

    override func refresh() async throws -> [FeedSource] {
        guard var result = try await _feedSourceList.retrive() else {
            throw BaseError.runtimeError("Feed source list fetched failed")
        }

        for source in feedSourceList {
            if removedNameList.contains(source.name) {
                continue
            }

            var source = source
            let parseResult = try? await withCheckedThrowingContinuation {
                continuation in
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
                    Feed(item: $0, source: source)
                })
            {
                source.feed = feeds
                result.removeAll(where: { $0.name == source.name })
                result.append(source)
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
