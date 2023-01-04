//
//  FeedConstants.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import Foundation

let ustcHomePageFeedURL = URL(string: "https://www.ustc.edu.cn/system/resource/code/rss/rssfeedg.jsp?type=list&treeid=1002&viewid=249541&mode=10&dbname=vsb&owner=1585251974&ownername=zz&contentid=221571,221572,221573,221574&number=100&httproot=")!
let ustcOAAFeedURL = URL(string: "https://www.teach.ustc.edu.cn/category/notice/feed")!

// MARK: This shall NOT be used, use FeedSource.all to list all feedSource.
let defaultFeedSources = [FeedSource(url: ustcOAAFeedURL, name: "教务处", image: "person.crop.square.fill.and.at.rectangle"),
                          FeedSource(url: ustcHomePageFeedURL, name: "校主页", image: "icloud.square.fill")]
