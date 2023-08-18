//
//  FeedSourceView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/22.
//

import SwiftUI

struct FeedSourceView: View {
    @StateObject var feedSource: FeedSource
    var feeds: [Feed] {
        feedSource.data
    }

    var body: some View {
        FeedVStackView(feeds: feeds)
            .asyncViewStatusMask(status: feedSource.status)
            .refreshable {
                feedSource.userTriggerRefresh()
            }
            .navigationTitle(feedSource.name)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct AllSourceView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @AppStorage("useNotification", store: UserDefaults.appGroup) var useNotification = true
    @State var feeds: [Feed] = []
    @State var status: AsyncViewStatus = .inProgress

    var body: some View {
        FeedVStackView(feeds: feeds)
            .task {
                appDelegate.clearBadgeNumber()
                do {
                    self.feeds = try await FeedSource.recentFeeds(number: nil)
                    self.status = .success
                } catch {
                    self.status = .failure(error.localizedDescription)
                }
            }
            .refreshable {
                self.status = .cached
                do {
                    try await AutoUpdateDelegate.feedList.update()
                    for source in FeedSource.allToShow {
                        _ = try await source.refreshCache()
                    }
                    self.feeds = try await FeedSource.recentFeeds(number: nil)
                    self.status = .success
                } catch {
                    self.status = .failure(error.localizedDescription)
                }
            }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
    }
}
