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
    @AppStorage("useNewUIForFeed") var useNewUI = true
    let feed: Feed
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
            Group {
                if useNewUI {
                    SecondFeedView(feed: feed)
                } else {
                    Card(cardTitle: feed.title,
                         cardDescription: feed.description,
                         leadingPropertyList: feed.keywords.map { ($0, nil) },
                         trailingPropertyList: [.init(feed.datePosted), feed.source],
                         imageURL: feed.imageURL)
                }
            }
            .contextMenu {
                if let url = feed.url {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            } preview: {
                NavigationStack {
                    GeometryReader { geo in
                        Group {
                            if useReeed {
                                ReeeederView(url: feed.url)
                            } else {
                                Browser(url: feed.url)
                            }
                        }
                        .frame(height: geo.size.height)
                    }
                    .toolbar(.hidden)
                }
            }
        }
    }
}

struct SecondFeedView: View {
    let feed: Feed

    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(feed.title)
                    .lineLimit(2, reservesSpace: true) // this is to fix frame size problem. might not look the best when met with single-line title
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.leading)
                HStack {
                    Text(feed.source)
                        .bold()
                    Text(String(feed.datePosted, long: true))
                    Spacer()
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            Divider()
            HStack {
                if let description = feed.description {
                    Text(description)
                        .font(.subheadline)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }
                if let imageURL = feed.imageURL {
                    Spacer()
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 80, maxHeight: 80)
                    } placeholder: {
                        ProgressView()
                    }
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .stroke(style: .init(lineWidth: 1))
                .fill(Color.accentColor)
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 4)
    }
}

struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            FeedView(feed: .example)
            SecondFeedView(feed: .example)
        }
        .padding()
    }
}
