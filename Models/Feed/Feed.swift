//
//  Feed.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import FeedKit
import Foundation

/*
 TODO: shooort notice here: the ustc label is used to check if the image is actually part of the post, not some sort of icon
 TODO: find a better way to deal with this once we have a better solution...
 */
let imageURLRegex = try! Regex(#"(htt[^\s]+ustc[^\s]+(jpg|jpeg|png|tiff)\b)"#)
let httpRegex = try! Regex("^http[^s]//")

struct Feed: Codable {
    static var all: [Feed] = []
    var id = UUID()
    var title: String
    var source: String
    var keywords: Set<String>
    /// Short sentences to covery the point
    var description: String?
    var datePosted: Date
    var url: URL
    /// Preview image URL for the post
    var imageURL: URL?

    init(item: RSSFeedItem, source: String) {
        title = item.title ?? "!!No title found for this Feed"
        self.source = source
        keywords = Set(item.categories?.map { $0.value ?? "" } ?? [])
        description = item.description

        datePosted = item.pubDate ?? Date()
        url = URL(string: item.link!)!

        // Try find an image-URL inside content, if found, set it as the image preview
        let match = item.content?.contentEncoded?.firstMatch(of: imageURLRegex)
        if let match {
            imageURL = URL(string: String(match.0))
        }

        id = UUID(name: url.absoluteString, nameSpace: .url)
        Feed.all.append(self)
    }
}
