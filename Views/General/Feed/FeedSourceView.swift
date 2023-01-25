//
//  FeedSourceView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import SwiftUI

struct FeedSourceView: View {
    let feedSource: FeedSource

    var body: some View {
        NavigationStack {
            AsyncView { feeds in
                FeedVStackView(feeds: feeds)
            } loadData: {
                try await feedSource.fetchRecentPost()
            } refreshData: {
                try await feedSource.forceUpdatePost()
            }
            .navigationBarTitle(feedSource.name, displayMode: .inline)
        }
    }
}

struct AllSourceView: View {
    var body: some View {
        NavigationStack {
            AsyncView { feeds in
                FeedVStackView(feeds: feeds)
            } loadData: {
                try await FeedSource.recentFeeds(number: nil)
            } refreshData: {
                try await FeedSource.recentFeeds(number: nil)
            }
            .navigationBarTitle("Feed", displayMode: .inline)
        }
    }
}
