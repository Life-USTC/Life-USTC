//
//  AllSourceView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/25.
//

import SwiftUI

struct AllSourceView: View {
    @ManagedData(.feedSource) var feedSources: [FeedSource]
    var feeds: [Feed] {
        feedSources.flatMap(\.feed)
    }

    var body: some View {
        List {
            Section {
                ForEach(
                    feeds.sorted(by: { $0.datePosted > $1.datePosted })
                ) {
                    FeedView(feed: $0)
                }
            } header: {
                AsyncStatusLight(status: _feedSources.status)
            }
        }
        .scrollContentBackground(.hidden)
        .asyncStatusOverlay(_feedSources.status, showLight: false)
        .refreshable {
            _feedSources.triggerRefresh()
        }
        .navigationTitle("Feed")
        .navigationBarTitleDisplayMode(.large)
    }
}
