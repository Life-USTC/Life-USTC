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

    var preview: some View {
        FeedViewPreview(feed: feed)
    }

    var destination: some View {
        Group {
            if useReeed {
                ReeeederView(url: feed.url)
            } else {
                Browser(url: feed.url)
            }
        }
    }

    var body: some View {
        NavigationLinkAddon {
            destination
        } label: {
            preview
                .contextMenu {
                    ShareLink(item: feed.url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } preview: {
                    NavigationStack {
                        GeometryReader { geo in
                            destination
                                .frame(height: geo.size.height)
                        }
                    }
                }
        }
    }
}

struct FeedViewPreview: View {
    let feed: Feed

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(feed.datePosted.formatted())
                Text(feed.source)
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.secondary)

            if let imageURL = feed.imageURL {
                AsyncImage(url: imageURL) {
                    if let image = $0.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }
            } else {
                Spacer(minLength: 2)
            }

            Text(feed.title)
                .foregroundColor(.primary)
                .font(.title3)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .hStackLeading()
        .padding(.vertical, 5)
    }
}

struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            List {
                FeedView(feed: .example)
            }
            .frame(height: 500)
        }
        .padding()
    }
}
