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

    var body: some View {
        NavigationLink {
            if useReeed {
                ReeeederView(url: feed.url)
            } else {
                Browser(url: feed.url)
            }
        } label: {
            FeedViewPreview(feed: feed)
                .contextMenu {
                    ShareLink(item: feed.url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } preview: {
                    if useReeed {
                        ReeeederView(url: feed.url)
                            .frame(minWidth: 400)
                    } else {
                        Browser(url: feed.url)
                            .frame(minWidth: 400)
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
                Text(feed.source)
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .foregroundColor(.white)
                    .background {
                        RoundedRectangle(cornerRadius: 4)
                            .fill({ () -> Color in
                                switch feed.source {
                                case "校主页":
                                    return (Color.blue.opacity(0.6))
                                case "教务处":
                                    return (Color.purple.opacity(0.6))
                                case "应用通知":
                                    return (Color.accentColor.opacity(0.6))
                                default:
                                    return (Color.secondary.opacity(0.6))
                                }
                            }())
                    }
                Text(feed.datePosted.formatted())
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
