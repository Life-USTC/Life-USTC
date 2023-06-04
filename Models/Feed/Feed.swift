//
//  Feed.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import FeedKit
import Foundation
import LoremSwiftum

/*
 TODO: short notice here: the ustc label is used to check if the image is actually part of the post, not some sort of icon
 TODO: find a better way to deal with this once we have a better solution...
 */
// let imageURLRegex = try! Regex(#"(htt[^\s]+ustc[^\s]+(jpg|jpeg|png|tiff)\b)"#)
let imageURLRegex = try! Regex(#"(http[^\s]+(jpg|jpeg|png|tiff)\b)"#)
let shortUstcLinkRegex = try! Regex(#"https?://www.ustc.edu.cn/info/\d+/\d+.htm"#)
let httpRegex = try! Regex("^http[^s]//")

let filteredImageURLList = [URL(string: "https://s.w.org/images/core/emoji/11/72x72/21a9.png")!]

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

    static let example = Feed(title: Lorem.sentence,
                              source: Lorem.word,
                              keywords: [Lorem.word, Lorem.word],
                              description: Lorem.sentences(2),
                              datePosted: Date(),
                              url: exampleURL,
                              imageURL: URL(string: "https://picsum.photos/300/300"))

    var feedSource: FeedSource? {
        FeedSource.find(source)
    }

    init(id: UUID = UUID(),
         title: String,
         source: String,
         keywords: Set<String>,
         description: String? = nil,
         datePosted: Date,
         url: URL,
         imageURL: URL? = nil)
    {
        self.id = id
        self.title = title
        self.source = source
        self.keywords = keywords
        self.description = description
        self.datePosted = datePosted
        self.url = url
        self.imageURL = imageURL
    }

    init(item: RSSFeedItem, source: String) {
        title = item.title ?? "!!No title found for this Feed"
        self.source = source
        keywords = Set(item.categories?.map { $0.value ?? "" } ?? [])
        description = item.description
        datePosted = item.pubDate ?? Date()
        url = URL(string: item.link!)!

        // Try find an image-URL inside content, if found, set it as the image preview
        if let match = item.content?.contentEncoded?.firstMatch(of: imageURLRegex) {
            imageURL = URL(string: String(match.0).urlEncoded!)!
            if filteredImageURLList.contains(imageURL!) {
                imageURL = nil
            }
        }

        id = UUID(name: url.absoluteString, nameSpace: .url)
        Feed.all.append(self)
    }
}
