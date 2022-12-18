//
//  FeedView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import SwiftUI

struct FeedView: View {
    var date: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: Date())
    }
    
    @Environment(\.defaultMinListRowHeight) var minRowHeight
    @State var showFeedSettingsPage: Bool = false
    @State var testBoolA = false
    @AppStorage("showPostNumbers") var showPostNumbers = 5
    
    // Maintain a copy of list in @State from constants:
    
    @State var feedPosts: [Post] = []
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack {
                    TitleAndSubTitle(title: "Recent", subTitle: date, style: .reverse)
                    PostStack(posts: $feedPosts)
                    NavigationLink("See More") {
                        FeedSourcePage(nil, loadAllFeedSource: true)
                    }
                    
                    Divider()
                    
                    Text("Sources")
                        .font(.title2)
                        .fontWeight(.bold)
                        .hStackLeading()
                    
                    List {
                        ForEach(defaultFeedSources, id:\.id) { feedSource in
                            NavigationLink(feedSource.name) {
//                                PostsPage(posts: feedSource.fetchRecentPost(), name: feedSource.name)
                                FeedSourcePage(feedSource)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .frame(minWidth: 200,maxWidth: .infinity, minHeight: minRowHeight * 3)
                    
                    Spacer()
                }
                .padding([.leading,.trailing])
            }
            .onChange(of: showPostNumbers) { _ in
                self.feedPosts = showUserFeedPost(number: showPostNumbers)
            }
            .navigationTitle("Feed")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showFeedSettingsPage = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showFeedSettingsPage) {
                NavigationStack {
                    List {
                        Section {
                            Stepper("Feed count: \(showPostNumbers)", value: $showPostNumbers, in: 1...100)
                        } header: {
                            Text("Settings")
                        }
                    }
                    .navigationTitle("Feed Settings")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    while self.feedPosts.count == 0 {
                        self.feedPosts = showUserFeedPost(number: showPostNumbers)
                        // this is too violent of a solution...
                        // TODO: change this to a notification listener and listen to network permission change.
                        // 
                    }
                }
            }
        }
    }
}
