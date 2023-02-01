//
//  FeedView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import Reeeed
import SwiftUI

struct FeedView: View {
    @AppStorage("useReeed") var useReeed = true
    let feed: Feed
    var date: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: feed.datePosted)
    }

    @State var showPostDetail = false
    var body: some View {
        NavigationLinkAddon {
            Group {
                if useReeed {
                    ReeeederView(url: feed.url)
                } else {
                    Browser(url: feed.url)
                }
            }
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
                    NavigationStack {
                        GeometryReader { geo in
                            ReeeederView(url: feed.url)
                                .frame(height: geo.size.height)
                        }
                        .toolbar(.hidden)
                    }
                }
        }
    }
}

struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        FeedView(feed: Feed.example)
    }
}
