//
//  FeedPostView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import SwiftUI

struct FeedPostView: View {
    let post: FeedPost
    var date: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: post.timePosted)
    }
    var body: some View {
        NavigationLink {
            Browser(url: post.url, title: post.title)
        } label: {
            Card(cardTitle: post.title,
                 cardDescription: post.description ,
                 leadingPropertyList: post.keywords.map{($0, nil)},
                 trailingPropertyList: [date, post.source],
                 imageURL: post.imageURL)
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
