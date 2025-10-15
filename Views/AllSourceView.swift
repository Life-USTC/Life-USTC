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
    @State private var showingFeedSettings = false

    var feedsSearched: [Feed] {
        let feeds = feedSources.flatMap(\.feed)

        guard !searchText.isEmpty else {
            return feeds
        }

        let keywords =
            searchText
            .lowercased()
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }

        guard !keywords.isEmpty else {
            return feeds
        }

        return feeds.filter { feed in
            let titleLowercased = feed.title.lowercased()
            let sourceLowercased = feed.source.lowercased()

            // Check if all keywords are found in either title or source name
            return keywords.allSatisfy { keyword in
                titleLowercased.contains(keyword) || sourceLowercased.contains(keyword)
            }
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(
                    feedsSearched.sorted(by: { $0.datePosted > $1.datePosted })
                ) {
                    FeedView(feed: $0)
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
        .navigationBarTitleDisplayMode(.large)
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
