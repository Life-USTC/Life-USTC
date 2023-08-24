//
//  FeedSourceList.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import Foundation
import SwiftyJSON

let FeedSourceListLocalStorage = ManagedLocalStorage<[FeedSource]>(
    "FeedSourceList",
    validDuration: 3600 * 24
)

class FeedSourceListDelegate: ManagedRemoteUpdateProtocol {
    static let shared = FeedSourceListDelegate()

    func refresh() async throws -> [FeedSource] {
        let (data, _) = try await URLSession.shared.data(
            from: SchoolExport.shared.remoteFeedURL
        )
        let json = try JSON(data: data)

        return json["sources"].arrayValue
            .map { feedSource in
                FeedSource(
                    url: URL(string: feedSource["url"].stringValue)!,
                    name: feedSource["locales"]["zh"].stringValue,
                    description: feedSource["description"].stringValue,
                    image: feedSource["icons"]["sf-symbols"].stringValue,
                    colorHex: feedSource["color"].stringValue
                )
            }
    }

    init() {
        // If "ManagedLocalStorage/feedSourceList.json" isn't found locally
        // copy it from main Bundle SchoolExport.shared.localFeedJSOName
        if FeedSourceListLocalStorage.data == nil {
            let path = Bundle.main.path(
                forResource: SchoolExport.shared.localFeedJSOName,
                ofType: "json"
            )!
            let data = try! Data(
                contentsOf: URL(fileURLWithPath: path),
                options: .mappedIfSafe
            )
            // Write to FeedSourceListLocalStorage.url
            FileManager.default.createFile(
                atPath: FeedSourceListLocalStorage.url.path,
                contents: data,
                attributes: nil
            )
        }
    }
}

extension ManagedDataSource<[FeedSource]> {
    static let feedSourceList = ManagedDataSource(
        local: FeedSourceListLocalStorage,
        remote: FeedSourceListDelegate.shared
    )
}
