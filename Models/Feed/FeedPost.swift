//
//  FeedPost.swift
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

struct FeedPost: Codable {
    var id = UUID()
    var title: String
    var source: String
    var keywords: [String]
    var description: String?
    var datePosted: Date
    var url: URL
    var imageURL: URL?

    /// Find the id from cache with the given URL
    ///
    /// This is to say, we maintain a list of url-id list in local cache to make sure other stuff are user-friendly
    mutating func updateIDFromCache() {
        // find the url in the cache
        if let index = postIDCacheList.firstIndex(where: { $0.url == url }) {
            // if that url is already in the list, then use the same id
            id = postIDCacheList[index].id
        } else {
            // else, add the new-generated id (during init process) and add that to cache
            postIDCacheList.append(FeedPostIDCache(url: url, id: id))
        }
    }

    init(url: URL,
         title: String,
         keywords: [String] = [],
         timePosted: Date,
         source: String,
         imageURL: URL? = nil,
         description: String? = nil)
    {
        self.url = url
        self.title = title
        self.keywords = keywords
        datePosted = timePosted
        self.source = source
        self.imageURL = imageURL
        self.description = description
        updateIDFromCache()
    }

    init(item: RSSFeedItem, source: String) {
        // try force upgrading the http protocol to https
        // temporarily disable this function as we add *.ustc.edu.cn to a whitelist
        url = URL(string: item.link!)!
//        url = URL(string: (item.link?.replacing(httpRegex, with: "https://"))!)!

        title = item.title ?? "!!No title found for this Feed"
        keywords = item.categories?.map { $0.value ?? "" } ?? []
        datePosted = item.pubDate ?? Date()

        self.source = source

        // if we find a URL to image inside the content, return it as the image for that
        let match = item.content?.contentEncoded?.firstMatch(of: imageURLRegex)
        if let match {
            imageURL = URL(string: String(match.0))
        }
        description = item.description
        updateIDFromCache()
    }
}
