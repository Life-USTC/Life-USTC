//
//  FeedVStackView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import SwiftUI

struct FeedSourceView: View {
    var feedSource: FeedSource

    var body: some View {
        List {
            ForEach(
                feedSource.feed.sorted(by: { $0.datePosted > $1.datePosted }),
                id: \.id
            ) {
                FeedView(feed: $0)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(feedSource.name)
    }
}
