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

    var destinationView: some View {
        Group {
            if useReeed {
                ReeeederView(url: feed.url)
            } else {
                Browser(url: feed.url)
            }
        }
    }

    var body: some View {
        NavigationLink {
            destinationView
        } label: {
            FeedViewPreview(feed: feed)
                .contextMenu {
                    ShareLink(item: feed.url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } preview: {
                    destinationView
                        .frame(height: 250)
                }
        }
    }
}

struct FeedViewPreview: View {
    let feed: Feed
    var color: Color {
        Color(hex: feed.colorHex ?? "#FFFFFF")
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(feed.source)
                    .font(.system(.caption2, weight: .heavy))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .foregroundColor(.white)
                    .background {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(0.9))
                    }

                Text(feed.datePosted, style: .timer)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            if let imageURL = feed.imageURL {
                AsyncImage(url: imageURL) {
                    if let image = $0.image {
                        image.resizable().aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }
            } else {
                Spacer(minLength: 2)
            }

            Text(feed.title)
                .font(.system(.title3, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .padding(.vertical, 5)
    }
}

struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            FeedView(feed: .example)
        }
        .frame(height: 500)
        .padding()
    }
}
