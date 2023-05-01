//
//  FeedView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import Reeeed
import SwiftUI

enum FeedViewStyle: String {
    case V1
    case V2
    case V3
}

struct FeedView: View {
    @AppStorage("useReeed") var useReeed = true
    @AppStorage("feedViewStyle") var feedViewStyle: FeedViewStyle = .V3
    let feed: Feed

    var preview: some View {
        Group {
            switch feedViewStyle {
            case .V1:
                Card(cardTitle: feed.title,
                     cardDescription: feed.description,
                     leadingPropertyList: feed.keywords.map { ($0, nil) },
                     trailingPropertyList: [.init(feed.datePosted), feed.source],
                     imageURL: feed.imageURL)
            case .V2:
                FeedViewV2(feed: feed)
            case .V3:
                FeedViewV3(feed: feed)
            }
        }
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

struct FeedViewV2: View {
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

struct FeedViewV3: View {
    let feed: Feed
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(feed.datePosted.description)
                Text(feed.source)
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.secondary)
            
            Spacer(minLength: 2)
            
            Text(feed.title)
                .foregroundColor(.primary)
                .font(.title3)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .padding(.vertical, 5)
        .hStackLeading()
    }
}

struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            FeedView(feedViewStyle: .V1, feed: .example)
            FeedView(feedViewStyle: .V2, feed: .example)
            FeedView(feedViewStyle: .V3, feed: .example)
                .frame(height: 80)
        }
        .padding()
    }
}
