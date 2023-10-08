//
//  AllSourceView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/25.
//

import SwiftUI

struct AllSourceView: View {
    @ManagedData(.feedSource) var feedSources: [FeedSource]
    @State var searchText = ""

    var feeds: [Feed] {
        feedSources.flatMap(\.feed)
    }

    var feedsSearched: [Feed] {
        guard searchText.isEmpty else {
            return feeds.filter {
                $0.title.contains(searchText)
            }
        }
        return feeds
    }

    var body: some View {
        List {
            Section {
                ForEach(
                    feedsSearched.sorted(by: { $0.datePosted > $1.datePosted })
                ) {
                    FeedView(feed: $0)
                }
            } header: {
                AsyncStatusLight(status: _feedSources.status)
            } footer: {
                Spacer()
                    .frame(height: 70)
            }
        }
        .listStyle(.sidebar)
        //.asyncStatusOverlay(_feedSources.status, showLight: false)
        .refreshable {
            _feedSources.triggerRefresh()
        }
        .searchable(text: $searchText)
        .navigationTitle("Feed")
        .navigationBarTitleDisplayMode(.large)
    }
}
