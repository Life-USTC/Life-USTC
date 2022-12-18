//
//  Feed.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import SwiftUI

/// Used to convert post -> View
struct PostCard: View {
    let post: Post
    var date: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: post.timePosted)
    }
    var body: some View {
        NavigationLink {
            Browser(url: post.url ?? URL(string: "https://example.com")!, title: post.title)
        } label: {
            Card(cardTitle: post.title,
                 cardDescription: post.description ,
                 leadingPropertyList: post.keywords.map{($0, nil)},
                 trailingPropertyList: [date, post.source],
                 imageURL: post.image)
            .contextMenu {
                if let url = post.url {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

/// Used to provide a seprate Destination For [Post] Type.
struct PostStack: View {
    @Binding var posts: [Post]
    @State var showSharePage = false
    var body: some View {
        if posts.isEmpty {
            ProgressView()
                .frame(width: 50, height: 50)
        } else {
            ForEach(posts, id:\.id) { post in
                PostCard(post: post)
            }
        }
    }
}

struct PostListPage: View {
    let name: LocalizedStringKey
    @Binding var posts: [Post] {
        willSet {
            updatePosts()
        }
    }
    @State var postsSorted: [TimeIntervalEnum: [Post]] = [.day: [], .week: [], .month: [], .year: [],.longerThanAYear: []]
    func updatePosts() {
        for post in posts {
            for timeIntervalCase in TimeIntervalEnum.allCases {
                if (timeIntervalCase.rangeToContain.contains(post.timePosted)) {
                    postsSorted[timeIntervalCase]!.append(post)
                }
            }
        }
    }
    
    func showTitle(key: TimeIntervalEnum) -> some View {
        TitleAndSubTitle(title: key.descriptionString,
                         subTitle: key.showDate,
                         style: .reverse)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    ForEach(postsSorted.sorted(by: {$0.key.rawValue < $1.key.rawValue}), id:\.key.hashValue) { key, value in
                        VStack {
                            showTitle(key: key)
                            PostStack(posts: Binding.constant(value))
                        }
                        .padding(.bottom, 40)
                    }
                }
                .padding([.leading,.trailing])
            }
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                updatePosts()
            }
        }
    }
    
    init(_ inPosts: Binding<[Post]>, name: String) {
        self._posts = inPosts
        self.name = LocalizedStringKey(name)
    }
    
    init(_ inPosts: Binding<[Post]>, name: LocalizedStringKey) {
        self._posts = inPosts
        self.name = name
    }
    
}

struct FeedSourcePage: View {
    let feedSource: (any FeedSource)?
    var loadAllFeedSource: Bool = false
    @State var posts: [Post] = []
    @State var refreshButtonHint = 0.0
    
    func updatePosts() {
        DispatchQueue.main.async {
            if loadAllFeedSource {
                posts = showUserFeedPost(number: nil)
            } else {
                posts = feedSource?.fetchRecentPost() ?? []
            }
        }
    }
    
    init(_ feedSource: (any FeedSource)?, loadAllFeedSource: Bool = false) {
        self.feedSource = feedSource
        self.loadAllFeedSource = loadAllFeedSource
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if posts.count == 0 {
                    ProgressView()
                } else {
                    PostListPage($posts, name: feedSource?.name ?? "All")
                }
            }
            .navigationTitle(feedSource?.name ?? "All")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation {
                            refreshButtonHint += 1
                            self.posts = []
                            updatePosts()
                            refreshButtonHint += 1
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .rotationEffect(.degrees(180.0 * refreshButtonHint))
                    }
                    .disabled(Int(refreshButtonHint) % 2 == 1)
                }
            }
        }
        .onAppear {
            updatePosts()
        }
    }
}
