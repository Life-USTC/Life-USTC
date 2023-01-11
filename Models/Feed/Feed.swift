//
//  Feed.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import FeedKit
import Foundation

/*
 TODO: short notice here: the ustc label is used to check if the image is actually part of the post, not some sort of icon
 TODO: find a better way to deal with this once we have a better solution...
 */
// let imageURLRegex = try! Regex(#"(htt[^\s]+ustc[^\s]+(jpg|jpeg|png|tiff)\b)"#)
let imageURLRegex = try! Regex(#"(htt[^\s]+(jpg|jpeg|png|tiff)\b)"#)
let httpRegex = try! Regex("^http[^s]//")

class Feed: Codable {
    static var all: [Feed] = []
    var id = UUID()
    var title: String
    var source: String
    var keywords: Set<String>
    var description: String? // Short sentences to covey the point
    var datePosted: Date
    var url: URL
    var imageURL: URL? // preview image URL

    init(item: RSSFeedItem, source: String) {
        title = item.title ?? "!!No title found for this Feed"
        self.source = source
        keywords = Set(item.categories?.map { $0.value ?? "" } ?? [])
        description = item.description
        datePosted = item.pubDate ?? Date()
        url = URL(string: item.link!)!

        // Try find an image-URL inside content, if found, set it as the image preview
        if let match = item.content?.contentEncoded?.firstMatch(of: imageURLRegex) {
            imageURL = URL(string: String(match.0))
        } else {
            // try load the content of URL:
            Task {
                let webPage = try String(contentsOf: url)
                if let webPageMatch = webPage.firstMatch(of: imageURLRegex) {
                    imageURL = URL(string: String(webPageMatch.0))
                }
            }
        }

        id = UUID(name: url.absoluteString, nameSpace: .url)
        Feed.all.append(self)
    }
}
