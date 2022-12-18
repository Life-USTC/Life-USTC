//
//  Constants.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import Foundation

let homepage_ustc_url = "https://www.ustc.edu.cn/system/resource/code/rss/rssfeedg.jsp?type=list&treeid=1002&viewid=249541&mode=10&dbname=vsb&owner=1585251974&ownername=zz&contentid=221571,221572,221573,221574&number=100&httproot="
let teach_ustc_url = "https://www.teach.ustc.edu.cn/category/notice/feed"

let defaultFeedSources = [RSSFeedSource(url:URL(string: teach_ustc_url)!,
                                        name: "教务处",
                                        id: UUID(uuidString: "60f508b8-a688-4bd4-81f1-6538621a873d")!),
                          RSSFeedSource(url: URL(string: homepage_ustc_url)!,
                                        name: "校主页",
                                        id: UUID(uuidString: "936bb0ac-94cd-411e-8551-39ea649af947")!)]

