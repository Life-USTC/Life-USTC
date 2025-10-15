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

    var feeds: [Feed] {
        feedSources.flatMap(\.feed)
    }

    var feedsSearched: [Feed] {
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

                if feedsSearched.isEmpty {
                    Text("No feeds found.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                AsyncStatusLight(status: _feedSources.status)
            }
        }
        .listStyle(.sidebar)
        .refreshable {
            _feedSources.triggerRefresh()
        }
        .searchable(text: $searchText)
        .navigationTitle("Feed")
        .navigationBarTitleDisplayMode(.large)
    }
}
