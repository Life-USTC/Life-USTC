//
//  FeedList.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import SwiftUI

struct FeedListView: View {
    @Binding var feeds: [Feed]
    @State var showSharePage = false
    var body: some View {
        ForEach(feeds, id: \.id) { post in
            FeedView(feed: post)
        }
    }
}

struct FeedVStackView: View {
    let name: String
    @Binding var feeds: [Feed]
    @Binding var status: AsyncViewStatus
    var postsSorted: [TimePeroid: [Feed]] {
        var result: [TimePeroid: [Feed]] = [.day: [], .week: [], .month: [], .year: [], .longerThanAYear: []]
        for post in feeds {
            for timePeroid in TimePeroid.allCases {
                if timePeroid.dateRange.contains(post.datePosted) {
                    result[timePeroid]!.append(post)
                }
            }
        }
        return result
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
                                    key.makeView()
                                    FeedListView(feeds: Binding.constant(value))
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
