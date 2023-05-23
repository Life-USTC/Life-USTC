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
        AsyncView { feeds in
            FeedVStackView(feeds: feeds)
        } loadData: {
            try await feedSource.fetchRecentPost()
        } refreshData: {
            try await feedSource.forceUpdatePost()
        }
        .navigationTitle(feedSource.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AllSourceView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @AppStorage("useNotification", store: userDefaults) var useNotification = true

    var body: some View {
        AsyncView { feeds in
            FeedVStackView(feeds: feeds)
        } loadData: {
            appDelegate.clearBadgeNumber()
            return try await FeedSource.recentFeeds(number: nil)
        } refreshData: {
            for source in FeedSource.allToShow {
                _ = try await source.forceUpdatePost()
            }
            return try await FeedSource.recentFeeds(number: nil)
        }
        .navigationTitle("Feed")
        .navigationBarTitleDisplayMode(.inline)
    }
}
