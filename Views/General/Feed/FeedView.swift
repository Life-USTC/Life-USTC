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
            HStack {
                Text(feed.source)
                    .bold()
                Spacer()
                Text(String(feed.datePosted))
            }

            Divider()

            HStack {
                VStack(alignment: .leading) {
                    Text(feed.title)
                        .font(.title2)
                        .bold()
                        .multilineTextAlignment(.leading)
                    if let description = feed.description {
                        Text(description)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer()
                if let imageURL = feed.imageURL {
                    AsyncImage(
                        url: imageURL,
                        content: { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 80, maxHeight: 80)
                        },
                        placeholder: {
                            ProgressView()
                        }
                    )
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
