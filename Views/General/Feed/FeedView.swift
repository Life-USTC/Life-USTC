//
//  FeedView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import SwiftUI

struct FeedView: View {
    let feed: Feed
    var date: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: feed.datePosted)
    }

    @State var showPostDetail = false
    var body: some View {
        NavigationLink {
            Browser(url: feed.url, title: feed.title)
        } label: {
            Card(cardTitle: feed.title,
                 cardDescription: feed.description,
                 leadingPropertyList: feed.keywords.map { ($0, nil) },
                 trailingPropertyList: [date, feed.source],
                 imageURL: feed.imageURL)
                .contextMenu {
                    if let url = feed.url {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                } preview: {
                    Browser(url: feed.url, title: feed.title)
                        .frame(width: cardWidth)
                }
        }
    }
}
