//
//  FeedSourceView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import SwiftUI

struct FeedSourceView: View {
    var feedSource: FeedSource

    var body: some View {
        FeedVStackView(feeds: feedSource.feed)
            .navigationTitle(feedSource.name)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct AllSourceView: View {
    @ManagedData(.feedSource) var feedSources: [FeedSource]
    var feeds: [Feed] {
        feedSources.flatMap(\.feed)
    }

    var body: some View {
        List {
            Section {
                ForEach(
                    feeds.sorted(by: { $0.datePosted > $1.datePosted }),
                    id: \.id
                ) {
                    FeedView(feed: $0)
                }
            } header: {
                AsyncStatusLight(status: _feedSources.status)
            }

            Spacer()
                .frame(height: 70)
        }
        .scrollContentBackground(.hidden)
        .asyncStatusOverlay(_feedSources.status, showLight: false)
        .refreshable {
            _feedSources.triggerRefresh()
        }
        .navigationTitle("Feed")
        .navigationBarTitleDisplayMode(.inline)
    }
}
