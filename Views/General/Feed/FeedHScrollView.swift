//
//  FeedHScrollView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/24.
//

import SwiftUI

struct FeedHScrollView: View {
    @State var posts: [FeedPost] = []
    @State var runOnce = false
    @AppStorage("homeShowPostNumbers") var feedPostNumber = 4
    @State var status: AsyncViewStatus = .inProgress
    var feedPostIDList: [UUID] {
        posts.map { $0.id }
    }

    var featureList: some View {
        VStack {
            EmptyView()
        }
    }

    // exract a function to make infinite loop
    func scrollTo(proxy: ScrollViewProxy, id: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
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
                    ForEach(posts, id: \.id) { post in
                        FeedPostView(post: post)
                            .id(post.id)
                    }
                }
                .frame(width: cardWidth * Double(feedPostNumber))
            }
            .scrollDisabled(true)
            .onAppear {
                // the onAppear function would be called whenever the view 'disappear' and 're-appeared' from end-user's view,
                // which means even the user switched under tabview, the function would be called once again.
                // using runOnce to make sure the scroll loop is created only once...
                // Not sure if SwiftUI have a seprate modifier for that...
                if !runOnce {
                    runOnce = true
                    _ = Task {
                        while status != .success {}
                        if let id = feedPostIDList.first {
                            scrollTo(proxy: proxy, id: id)
                        }
                    }
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
            asyncBind($posts, status: $status) {
                try await showUserFeedPost(number: feedPostNumber)
            }
        }
    }
}
