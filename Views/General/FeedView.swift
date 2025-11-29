//
//  FeedView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import Reeeed
import SwiftUI

private struct FeedViewPreview: View {
    let feed: Feed
    let isRead: Bool
    var color: Color {
        Color(hex: feed.colorHex ?? "#FFFFFF")
    }
    var hasImage: Bool { feed.imageURL != nil }
    private let imageHeight: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let imageURL = feed.imageURL {
                RetryAsyncImage(url: imageURL, height: imageHeight)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(feed.title)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundColor(isRead ? Color(.tertiaryLabel) : .primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                HStack(spacing: 6) {
                    Text(feed.source?.name ?? "Unknown")
                        .font(.system(.caption2, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color.opacity(0.9))
                        }

                    Text(feed.datePosted.formatted(.relative(presentation: .named)))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)

                    if !isRead {
                        Circle()
                            .fill(.blue)
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
    }
}

private struct RetryAsyncImage: View {
    let url: URL
    let height: CGFloat

    let cornerRadius: CGFloat = 8
    let maxRetries: Int = 2
    @State var attempt: Int = 0
    @State var scheduling: Bool = false

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: height)
                    .clipped()
            case .failure(_):
                if attempt < maxRetries {
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color(.systemGray5))
                    }
                    .frame(height: height)
                    .onAppear {
                        if !scheduling {
                            scheduling = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                attempt += 1
                                scheduling = false
                            }
                        }
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color(.systemGray5))
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 24, weight: .bold))
                    }
                    .frame(height: height)
                    .onTapGesture {
                        attempt = 0
                    }
                }
            default:
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color(.systemGray6))
                    ProgressView()
                }
                .frame(height: height)
            }
        }
        .id(attempt)
    }
}

struct FeedView: View {
    let feed: Feed
    @AppStorage("readFeedURLList", store: .appGroup) var readFeedURLList: [String] = []
    @AppStorage("feedReadCutoffDate", store: .appGroup) var feedReadCutoffDate: Date?

    private var defaultCutoffDate: Date {
        Calendar.current.date(from: DateComponents(year: 2025, month: 11, day: 26)) ?? .distantPast
    }

    private var cutoffDate: Date {
        if let d = feedReadCutoffDate { return d }
        feedReadCutoffDate = defaultCutoffDate
        return defaultCutoffDate
    }

    private var isRead: Bool {
        if feed.datePosted < cutoffDate { return true }
        return readFeedURLList.contains(feed.url.absoluteString)
    }

    private func markRead() {
        let key = feed.url.absoluteString
        if !readFeedURLList.contains(key) {
            readFeedURLList.append(key)
        }
    }

    var body: some View {
        NavigationLink {
            Browser(
                url: feed.url,
                title: LocalizedStringKey(stringLiteral: feed.title)
            )
        } label: {
            FeedViewPreview(feed: feed, isRead: isRead)
                .frame(maxWidth: .infinity, alignment: .leading)
                // .background(
                //     RoundedRectangle(cornerRadius: 10)
                //         .fill(Color(.systemBackground))
                // )
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
                .contextMenu {
                    ShareLink(item: feed.url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } preview: {
                    ReeeederView(url: feed.url)
                        .frame(width: 350, height: 600)
                }
        }
        .simultaneousGesture(TapGesture().onEnded { markRead() })
    }
}
