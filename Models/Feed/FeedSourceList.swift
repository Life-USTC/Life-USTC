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

    override init() {
        // Note: Init is guararenteed to run before Wrapper.wrappedValue is accessible.
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
