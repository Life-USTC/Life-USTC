//
//  HomeView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import SwiftUI

struct HomeView: View {
    
    @State var feedPosts: [Post] = []
    var feedPostIDList: [UUID] {
        feedPosts.map({$0.id})
    }
    let semaphore = DispatchSemaphore(value: 2)
    let feedPostNumber = 4
    
    var featureList: some View {
        VStack{
            EmptyView()
        }
    }
    @State var runOnce = false
    
    func scrollTo(proxy: ScrollViewProxy, id: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
            withAnimation {
                proxy.scrollTo(id)
            }
            let index = feedPostIDList.firstIndex(of: id) ?? -1
            var nextIndex = index + 1
            nextIndex = feedPostIDList.indices.contains(nextIndex) ? nextIndex : 0
            scrollTo(proxy: proxy, id: feedPostIDList[nextIndex])
        }
    }
    
    var feedHStack: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                HStack {
                    ForEach(feedPosts, id:\.id) { post in
                        PostCard(post: post)
                            .id(post.id)
                    }
                }
                .frame(width: (UIScreen.main.bounds.width - 30) * Double(feedPostNumber))
            }
            .scrollDisabled(true)
            .onAppear {
                if !runOnce {
                    runOnce = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
                        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
                        scrollTo(proxy: proxy, id: feedPostIDList.first!)
                    }
                }
            }
        }
    }
    
    var mainView: some View {
        VStack {
            TitleAndSubTitle(title: "Feed", subTitle: currentDateString,style: .reverse)
            Group {
                if feedPosts.isEmpty {
                    ProgressView()
                        .frame(width: UIScreen.main.bounds.width - 30, height: 200)
                } else {
                    feedHStack
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    while self.feedPosts.count == 0 {
                        self.feedPosts = showUserFeedPost(number: feedPostNumber)
                        // this is too violent of a solution...
                        // TODO: change this to a notification listener and listen to network permission change.
                        //
                    }
                    semaphore.signal()
                }
            }
            
            // rest of the body, use .padding here to avoid framing problem.
            // TODO: find a better way to control the size of each post, and avoid adding new struct-view to the proj and try add modifier to PostStack()
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                mainView
                featureList
            }
            .padding()
            .navigationTitle("Life@USTC")
        }
    }
}
