//
//  FeedSource.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import FeedKit
import SwiftData
import SwiftUI

@Model
final class FeedSource {
    @Attribute(.unique) var id = UUID()
    var url: URL
    var name: String
    var detailText: String?
    var image: String?  // sf symbol
    var colorHex: String?
    var feed: [Feed] = []

    init(
        url: URL,
        name: String,
        detailText: String? = nil,
        image: String? = nil,
        colorHex: String? = nil,
        feed: [Feed] = []
    ) {
        self.url = url
        self.name = name
        self.detailText = detailText
        self.image = image
        self.colorHex = colorHex
        self.feed = feed
    }
}

extension FeedSource {
    var feedQuery: [Feed] {
        let context = SwiftDataStack.context
        let myID = self.persistentModelID
        let descriptor = FetchDescriptor<Feed>(predicate: #Predicate { $0.sourceRef?.persistentModelID == myID })
        return (try? context.fetch(descriptor)) ?? []
    }
}
