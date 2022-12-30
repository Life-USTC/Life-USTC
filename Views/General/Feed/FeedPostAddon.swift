//
//  FeedView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import SwiftUI

struct PostStack: View {
    @Binding var posts: [FeedPost]
    @State var showSharePage = false
    var body: some View {
        ForEach(posts, id: \.id) { post in
            FeedPostView(post: post)
        }
    }
}

struct PostListPage: View {
    let name: String
    @Binding var posts: [FeedPost]
    @Binding var status: AsyncViewStatus
    var postsSorted: [HistoryEnum: [FeedPost]] {
        var result: [HistoryEnum: [FeedPost]] = [.day: [], .week: [], .month: [], .year: [], .longerThanAYear: []]
        for post in posts {
            for timeIntervalCase in HistoryEnum.allCases {
                if timeIntervalCase.coveringDate.contains(post.datePosted) {
                    result[timeIntervalCase]!.append(post)
                }
            }
        }
        return result
    }

    func showTitle(key: HistoryEnum) -> some View {
        TitleAndSubTitle(title: key.representingString,
                         subTitle: key.coveringDateString,
                         style: .reverse)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if status == .inProgress {
                    ProgressView()
                } else {
                    VStack {
                        ForEach(postsSorted.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key.hashValue) { key, value in
                            if !value.isEmpty {
                                VStack {
                                    showTitle(key: key)
                                    PostStack(posts: Binding.constant(value))
                                }
                                .padding(.bottom, 40)
                            }
                        }
                    }
                    .padding([.leading, .trailing])
                }
            }
            .navigationTitle(Text(name))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
