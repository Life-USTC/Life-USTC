//
//  FeedSource.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import FeedKit
import SwiftData
import SwiftUI
import SwiftyJSON

@Model
final class FeedSource {
    var feeds: [Feed] = []

    @Attribute(.unique) var url: URL
    var name: String
    var detailText: String?
    var image: String?  // sf symbol
    var colorHex: String?

    var color: Color {
        if let hex = colorHex {
            return Color(hex: hex)
        }
        return Color.fromSeed(name)
    }

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
    }
}

extension FeedSource {
    @MainActor
    static func update() async throws {
        if SwiftDataStack.isPresentingDemo { return }

        let (data, _) = try await URLSession.shared.data(
            from: SchoolSystem.current.remoteFeedURL
        )
        let json = try JSON(data: data)

        for sourceJSON in json["sources"].arrayValue {
            let sourceURL = URL(string: sourceJSON["url"].stringValue)!
            let sourceName = sourceJSON["locales"]["zh"].stringValue
            let sourceDescription = sourceJSON["description"].stringValue
            let sourceImage = sourceJSON["icons"]["sf-symbols"].stringValue
            let sourceColor = sourceJSON["color"].stringValue

            try SwiftDataStack.modelContext.upsert(
                predicate: #Predicate<FeedSource> { $0.url == sourceURL },
                update: { source in
                    source.name = sourceName
                    source.detailText = sourceDescription
                    source.image = sourceImage
                    source.colorHex = sourceColor
                },
                create: {
                    FeedSource(
                        url: sourceURL,
                        name: sourceName,
                        detailText: sourceDescription,
                        image: sourceImage,
                        colorHex: sourceColor
                    )
                }
            )
        }
    }
}
