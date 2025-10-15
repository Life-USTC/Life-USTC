//
//  FeedVStackView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import SwiftUI

struct FeedVStackView: View {
    var feeds: [Feed]

    var body: some View {
        List {
            ForEach(
                feeds.sorted(by: { $0.datePosted > $1.datePosted }),
                id: \.id
            ) {
                FeedView(feed: $0)
            }
        }
        .scrollContentBackground(.hidden)
    }
}

struct FeedSourceView: View {
    var feedSource: FeedSource

    var body: some View {
        FeedVStackView(feeds: feedSource.feed)
            .navigationTitle(feedSource.name)
            .navigationBarTitleDisplayMode(.inline)
    }
}
