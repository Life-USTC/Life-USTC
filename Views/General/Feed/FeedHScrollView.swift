//
//  FeedHScrollView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/24.
//

import SwiftUI

struct FeedHScrollView: View {
    @State var feeds: [Feed] = []
    @State var runOnce = false
    @AppStorage("homeShowPostNumbers") var feedPostNumber = 4
    @State var status: AsyncViewStatus = .inProgress
    var feedPostIDList: [UUID] {
        feeds.map { $0.id }
    }

    var featureList: some View {
        VStack {
            EmptyView()
        }
    }

    // exract a function to make infinite loop
    func scrollTo(proxy: ScrollViewProxy, id: UUID) {
        Task {
            try await Task.sleep(for: .seconds(3))
            withAnimation {
                proxy.scrollTo(id)
            }
            let index = feedPostIDList.firstIndex(of: id) ?? -1
            var nextIndex = index + 1
            nextIndex = feedPostIDList.indices.contains(nextIndex) ? nextIndex : 0
            scrollTo(proxy: proxy, id: feedPostIDList[nextIndex])
        }
    }

    var mainView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 0) {
                    ForEach(feeds, id: \.id) { post in
                        FeedView(feed: post)
                            .id(post.id)
                    }
                }
                .frame(width: cardWidth * Double(feedPostNumber))
            }
            .scrollDisabled(true)
            .task {
                while status != .success {}
                if let id = feedPostIDList.first {
                    scrollTo(proxy: proxy, id: id)
                }
            }
        }
    }

    var body: some View {
        Group {
            if status == .inProgress {
                ProgressView()
                    .frame(width: cardWidth, height: cardHeight)
            } else {
                mainView
            }
        }
        .onAppear {
            asyncBind($feeds, status: $status) {
                try await FeedCache.recentFeeds(number: feedPostNumber)
            }
        }
    }
}
