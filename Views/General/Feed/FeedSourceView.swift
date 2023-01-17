//
//  FeedSourceView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import SwiftUI

struct FeedSourceView: View {
    let feedSource: FeedSource
    @State var feeds: [Feed] = []
    @State var status: AsyncViewStatus = .inProgress

    var body: some View {
        NavigationStack {
            FeedVStackView(name: feedSource.name, feeds: $feeds, status: $status)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            asyncBind($feeds, status: $status) {
                                try await feedSource.forceUpdatePost()
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                }
        }
        .onAppear {
            asyncBind($feeds, status: $status) {
                try await feedSource.fetchRecentPost()
            }
        }
    }
}

struct AllSourceView: View {
    @State var feeds: [Feed] = []
    @State var status: AsyncViewStatus = .inProgress

    var body: some View {
        NavigationStack {
            FeedVStackView(name: "Feed", feeds: $feeds, status: $status)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            status = .inProgress
                            asyncBind($feeds, status: $status) {
                                try await FeedSource.recentFeeds(number: nil)
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                }
        }
        .onAppear {
            asyncBind($feeds, status: $status) {
                try await FeedSource.recentFeeds(number: nil)
            }
        }
    }
}
