//
//  FeedView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import SwiftUI
var currentDateString: String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .none
    return dateFormatter.string(from: Date())
}

struct FeedView: View {
    
    @Environment(\.defaultMinListRowHeight) var minRowHeight
    @State var showFeedSettingsPage: Bool = false
    @State var testBoolA = false
    @AppStorage("showPostNumbers") var showPostNumbers = 5
    
    // Maintain a copy of list in @State from constants:
    
    @State var feedPosts: [FeedPost] = []
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack {
                    TitleAndSubTitle(title: "Recent", subTitle: currentDateString, style: .reverse)
                    PostStack(posts: $feedPosts)
                    NavigationLink("See More") {
                        AllSourceView()
                    }
                    
                    Divider()
                    
                    Text("Sources")
                        .font(.title2)
                        .fontWeight(.bold)
                        .hStackLeading()
                    
                    List {
                        ForEach(defaultFeedSources, id:\.id) { feedSource in
                            NavigationLink(feedSource.name) {
                                FeedSourceView(feedSource: feedSource)
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
                showUserFeedPost(number: showPostNumbers, posts: $feedPosts)
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
                showUserFeedPost(number: showPostNumbers, posts: $feedPosts)
            }
        }
    }
}
