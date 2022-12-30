//
//  FeedSourceView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import SwiftUI

struct FeedSourceView: View {
    let feedSource: any FeedSource
    @State var posts: [FeedPost] = []
    @State var status: AsyncViewStatus = .inProgress

    var body: some View {
        NavigationStack {
            PostListPage(name: feedSource.name, posts: $posts, status: $status)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            asyncBind($posts, status: $status) {
                                try await feedSource.fetchRecentPost()
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                }
        }
        .onAppear {
            asyncBind($posts, status: $status) {
                try await feedSource.fetchRecentPost()
            }
        }
    }
}

struct AllSourceView: View {
    @State var posts: [FeedPost] = []
    @State var status: AsyncViewStatus = .inProgress

    var body: some View {
        NavigationStack {
            PostListPage(name: "Feed", posts: $posts, status: $status)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            status = .inProgress
                            asyncBind($posts, status: $status) {
                                try await showUserFeedPost(number: nil)
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                }
        }
        .onAppear {
            asyncBind($posts, status: $status) {
                try await showUserFeedPost(number: nil)
            }
        }
    }
}
