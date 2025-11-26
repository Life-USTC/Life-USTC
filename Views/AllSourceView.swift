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
    @State var selectedIndex = 0

    var feedsSearched: [Feed] {
        let feeds: [Feed]
        if selectedIndex == 0 {
            feeds = feedSources.flatMap(\.feed)
        } else {
            let idx = selectedIndex - 1
            if feedSources.indices.contains(idx) {
                feeds = feedSources[idx].feed
            } else {
                feeds = []
            }
        }

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
                VStack(alignment: .leading) {
                    AsyncStatusLight(status: _feedSources.status)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // Button {
                            //     selectedIndex = 0
                            // } label: {
                            //     Label("All", systemImage: "doc.richtext")
                            //         .labelStyle(FeedSourceLabelStyle())
                            // }
                            // .buttonStyle(FeedSourceButtonStyle(selected: selectedIndex == 0, color: Color.accentColor))

                            ForEach(Array(feedSources.enumerated()), id: \.1.id) { i, source in
                                Button {
                                    if selectedIndex == i + 1 {
                                        selectedIndex = 0
                                    } else {
                                        selectedIndex = i + 1
                                    }
                                } label: {
                                    Label(source.name, systemImage: source.image ?? "doc.richtext")
                                        .labelStyle(FeedSourceLabelStyle())
                                }
                                .buttonStyle(
                                    FeedSourceButtonStyle(
                                        selected: selectedIndex == i + 1,
                                        color: Color(hex: source.colorHex ?? "#767676")
                                    )
                                )
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
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
                FeedSetingsPage(dismissAction: {
                    showingFeedSettings = false
                })
            }
        }
    }
}

struct FeedSourceLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 6) {
            configuration.icon
                .symbolRenderingMode(.hierarchical)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color(.systemGray6))
                )
                .clipShape(Circle())

            configuration.title
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 72, height: 72)
    }
}

struct FeedSourceButtonStyle: ButtonStyle {
    var selected: Bool
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? color.opacity(0.15) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? color : Color(.separator), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}
