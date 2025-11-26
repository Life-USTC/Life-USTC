//
//  AllSourceView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/25.
//

import SwiftUI

struct AllSourceView: View {
    @ManagedData(.feedSources) var feedSources: [FeedSource]
    @AppStorage("readFeedURLList", store: .appGroup) var readFeedURLList: [String] = []
    @AppStorage("feedReadCutoffDate", store: .appGroup) var feedReadCutoffDate: Date?

    @State var searchText = ""
    @State var showingFeedSettings = false
    @State var selectedIndex = 0

    private var defaultCutoffDate: Date {
        Calendar.current.date(from: DateComponents(year: 2025, month: 11, day: 26)) ?? .distantPast
    }

    private var cutoffDate: Date {
        if let d = feedReadCutoffDate { return d }
        feedReadCutoffDate = defaultCutoffDate
        return defaultCutoffDate
    }

    private func isRead(_ feed: Feed) -> Bool {
        if feed.datePosted < cutoffDate { return true }
        return readFeedURLList.contains(feed.url.absoluteString)
    }

    private func hasUnread(_ source: FeedSource) -> Bool {
        source.feed.contains { !isRead($0) }
    }

    private func markAllRead(for source: FeedSource) {
        let urls = source.feed
            .filter { $0.datePosted >= cutoffDate }
            .map { $0.url.absoluteString }
        let union = Set(readFeedURLList).union(urls)
        readFeedURLList = Array(union)
    }

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

    var feedsSorted: [Feed] {
        feedsSearched.sorted(by: { feed1, feed2 in feed1.datePosted > feed2.datePosted })
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                if _feedSources.status.refresh == .waiting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                        .hStackCenter()
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(Array(feedSources.enumerated()), id: \.1.id) { i, source in
                            Button {
                                if selectedIndex == i + 1 {
                                    selectedIndex = 0
                                } else {
                                    selectedIndex = i + 1
                                }
                                markAllRead(for: source)
                            } label: {
                                Label {
                                    Text(source.name)
                                } icon: {
                                    FeedSourceUnreadIcon(
                                        imageName: source.image ?? "doc.richtext",
                                        hasUnread: hasUnread(source)
                                    )
                                }
                                .labelStyle(
                                    FeedSourceLabelStyle(
                                        dimmed: selectedIndex != 0 && selectedIndex != i + 1
                                    )
                                )
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

                MasonryTwoColumnView(
                    items: feedsSorted,
                    estimatedHeight: { feed in
                        feed.imageURL == nil ? 92 : 260
                    }
                ) { feed in
                    FeedView(feed: feed)
                }

                if feedsSearched.isEmpty {
                    Text("No feeds found.")
                        .foregroundStyle(.secondary)
                        .hStackCenter()
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
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
                    Label("Feed Settings", systemImage: "gearshape")
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
    var dimmed: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 6) {
            configuration.icon
                .symbolRenderingMode(.hierarchical)
                .font(.title2)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(Color(.systemGray6))
                )
                .clipShape(Circle())

            configuration.title
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Spacer()
        }
        .frame(width: 64, height: 100)
        .opacity(dimmed ? 0.35 : 1.0)
    }
}

struct FeedSourceButtonStyle: ButtonStyle {
    var selected: Bool
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(color)
    }
}

private struct FeedSourceUnreadIcon: View {
    var imageName: String
    var hasUnread: Bool

    var body: some View {
        Image(systemName: imageName)
            .overlay(alignment: .topTrailing) {
                if hasUnread {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                }
            }
    }
}

private struct MasonryTwoColumnView<Data: Identifiable, Content: View>: View {
    let items: [Data]
    let estimatedHeight: (Data) -> CGFloat
    @ViewBuilder let content: (Data) -> Content

    private var splitted: (left: [Data], right: [Data]) {
        var left: [Data] = []
        var right: [Data] = []
        var hl: CGFloat = 0
        var hr: CGFloat = 0
        for item in items {
            let h = estimatedHeight(item)
            if hl <= hr {
                left.append(item)
                hl += h
            } else {
                right.append(item)
                hr += h
            }
        }
        return (left, right)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            LazyVStack(spacing: 12) {
                ForEach(splitted.left) { item in
                    content(item)
                }
            }
            LazyVStack(spacing: 12) {
                ForEach(splitted.right) { item in
                    content(item)
                }
            }
        }
    }
}
