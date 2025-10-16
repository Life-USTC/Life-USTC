//
//  AllSourceView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/25.
//

import SwiftUI

struct AllSourceView: View {
    @ManagedData(.feedSources) var feedSources: [FeedSource]

    @State var searchText = ""
    @State var showingFeedSettings = false

    var feedsSearched: [Feed] {
        let feeds = feedSources.flatMap(\.feed)

        guard !searchText.isEmpty else {
            return feeds
        }

        let keywords =
            searchText
            .lowercased()
            .split(separator: " ")
            .map { substring in String(substring) }
            .filter { keyword in !keyword.isEmpty }

        guard !keywords.isEmpty else {
            return feeds
        }

        return feeds.filter { feed in
            keywords.allSatisfy { keyword in
                feed.title.lowercased().contains(keyword) || feed.source.lowercased().contains(keyword)
            }
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(
                    feedsSearched.sorted(by: { feed1, feed2 in feed1.datePosted > feed2.datePosted })
                ) { feed in
                    FeedView(feed: feed)
                }
                .asyncStatusOverlay(_feedSources.status)

                if feedsSearched.isEmpty {
                    Text("No feeds found.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                AsyncStatusLight(status: _feedSources.status)
            }
        }
        .refreshable {
            _feedSources.triggerRefresh()
        }
        .searchable(text: $searchText)
        .navigationTitle("Feed")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingFeedSettings = true
                } label: {
                    Label("Feed Settings", systemImage: "gear")
                }
            }
        }
        .sheet(isPresented: $showingFeedSettings) {
            NavigationStack {
                FeedSettingView(dismissAction: {
                    showingFeedSettings = false
                })
            }
        }
    }
}
