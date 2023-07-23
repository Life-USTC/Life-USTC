//
//  FeedVStackView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import SwiftUI

struct FeedVStackView: View {
    var feeds: [Feed]
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

    @ViewBuilder func makeView(_ key: TimePeroid, _ value: [Feed]) -> some View {
        if !value.isEmpty {
            VStack {
                VStack(alignment: .leading) {
                    Text(key.dateRangeCaption)
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                    Text(key.caption)
                        .font(.title2)
                        .bold()
                }
                .hStackLeading()
                ForEach(value, id: \.id) { post in
                    FeedView(feed: post)
                }
            }
            .padding(.bottom, 40)
        }
    }

    var body: some View {
        List {
            ForEach(feeds.sorted(by: { $0.datePosted > $1.datePosted }), id: \.id) {
                FeedView(feed: $0)
            }

            Spacer()
                .frame(height: 70)
        }
        .scrollContentBackground(.hidden)
    }
}
