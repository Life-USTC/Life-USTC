//
//  FeedModel.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import Foundation
import FeedKit

/* TODO: shooort notice here: the ustc label is used to check if the image is actually part of the post, not some sort of icon
   TODO: find a better way to deal with this once we have a better solution...*/
let findImageURLRegex = try! Regex(#"(htt[^\s]+ustc[^\s]+(jpg|jpeg|png|tiff)\b)"#)
let httpToHttpsRegex = try! Regex("^http[^s]//")

struct FeedPost: Codable {
    var id = UUID()
    
    var title: String
    var timePosted: Date
    var source: String // this doesn't need to be the author, it's the source that matters
    var url: URL
    
    var keywords: [String]
    var imageURL: URL?
    var description: String?
    
    mutating func updateIDFromCache() {
        // find the url in the postIDCacheList, if that url is already in the list, then use the same id
        if let index = postIDCacheList.firstIndex(where: {$0.url == url}) {
            self.id = postIDCacheList[index].id
        } else {
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
        self.timePosted = timePosted
        self.source = source
        self.imageURL = imageURL
        self.description = description
        updateIDFromCache()
    }
    
    init(item: RSSFeedItem, source: String) {
        // try force upgrading the http protocol to https
        self.url = URL(string: (item.link?.replacing(httpToHttpsRegex, with: "https://"))!)!
        
        self.title = item.title ?? "No title Found From RSS Feed"
        self.keywords = item.categories?.map {$0.value ?? ""} ?? []
        self.timePosted = item.pubDate ?? Date()
        
        self.source = source
        
        let match = item.content?.contentEncoded?.firstMatch(of: findImageURLRegex)
        if let match {
            self.imageURL = URL(string: String(match.0))
        }
        self.description = item.description
        updateIDFromCache()
    }
}
