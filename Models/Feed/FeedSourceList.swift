//
//  FeedSourceList.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import Foundation
import SwiftUI
import SwiftyJSON

let FeedSourceListLocalStorage = ManagedLocalStorage<[FeedSource]>(
    "FeedSourceList",
    validDuration: 3600 * 24
)

class FeedSourceListDelegate: ManagedRemoteUpdateProtocol<[FeedSource]> {
    static let shared = FeedSourceListDelegate()

    override func refresh() async throws -> [FeedSource] {
        let (data, _) = try await URLSession.shared.data(
            from: SchoolExport.shared.remoteFeedURL
        )
        let json = try JSON(data: data)

        return json["sources"].arrayValue
            .map { subJson in
                FeedSource(
                    url: URL(string: subJson["url"].stringValue)!,
                    name: subJson["locales"]["zh"].stringValue,
                    description: subJson["description"].stringValue,
                    image: subJson["icons"]["sf-symbols"].stringValue,
                    colorHex: subJson["color"].stringValue
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
