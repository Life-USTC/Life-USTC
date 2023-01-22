//
//  FeedVStackView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import SwiftUI

struct FeedListView: View {
    let feeds: [Feed]
    @State var showFullPage = false

    var body: some View {
        if showFullPage {
            ForEach(feeds, id: \.id) { post in
                GeometryReader { geo in
                    FeedView(feed: post)
                        .frame(width: geo.size.width)
                }
                .frame(height: cardHeight)
            }
        } else {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    ForEach(0 ..< min(feeds.count, 3)) { index in
                        FeedView(feed: feeds[index])
                            .frame(width: geo.size.width)
                            .offset(y: -Double(index * 20))
                            .zIndex(-Double(index))
                    }
                    Button {
                        showFullPage.toggle()
                    } label: {
                        Color.gray
                            .opacity(0.01) // 你觉得你是Color.clear吗? 我觉得你是
                    }
                }
            }
            .frame(height: cardHeight + 40)
        }
    }
}

struct FeedVStackView: View {
    let name: String
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
                TitleAndSubTitle(title: key.caption, subTitle: key.dateRangeCaption, style: .reverse)
                FeedListView(feeds: value, showFullPage: key == .day || key == .week)
            }
            .padding(.bottom, 40)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    ForEach(postsSorted.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key.hashValue) { key, value in
                        makeView(key, value)
                    }
                }
                .padding([.leading, .trailing])
            }
            .navigationTitle(Text(name))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
