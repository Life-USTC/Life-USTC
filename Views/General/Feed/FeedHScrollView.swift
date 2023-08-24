//
//  FeedHScrollView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/24.
//

import SwiftUI

struct FeedHScrollView: View {
    @State var runOnce = false
    @AppStorage("homeShowPostNumbers") var feedPostNumber = 4

    // exract a function to make infinite loop
    func scrollTo(proxy: ScrollViewProxy, id: UUID, feedPostIDList: [UUID]) {
        Task {
            try await Task.sleep(for: .seconds(3))
            withAnimation { proxy.scrollTo(id) }
            let index = feedPostIDList.firstIndex(of: id) ?? -1
            var nextIndex = index + 1
            nextIndex =
                feedPostIDList.indices.contains(nextIndex) ? nextIndex : 0
            scrollTo(
                proxy: proxy,
                id: feedPostIDList[nextIndex],
                feedPostIDList: feedPostIDList
            )
        }
    }

    func makeView(with feeds: [Feed]) -> some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(feeds, id: \.id) { post in
                            FeedView(feed: post).id(post.id).padding(.top, 2)
                        }
                    }
                    .frame(width: geo.size.width * Double(feedPostNumber))
                }
                .scrollDisabled(false)
                .task {
                    let feedPostIDList = feeds.map(\.id)
                    if let id = feedPostIDList.first {
                        scrollTo(
                            proxy: proxy,
                            id: id,
                            feedPostIDList: feedPostIDList
                        )
                    }
                }
            }
        }
        .frame(height: cardHeight)
    }

    var body: some View {
        AsyncView { $feeds in
            makeView(with: feeds)
        } loadData: {
            try await FeedSource.recentFeeds(number: feedPostNumber)
        }
    }
}

struct FeedHScroll_Previews: PreviewProvider {
    static var previews: some View { NavigationStack { FeedHScrollView() } }
}
