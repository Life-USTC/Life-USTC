//
//  HomeView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import SwiftUI

struct HomeView: View {
    
    @State var feedPosts: [FeedPost] = []
    @State var runOnce = false
    @AppStorage("homeShowPostNumbers") var feedPostNumber = 4
    @State var status: AsyncViewStatus = .inProgress
    var feedPostIDList: [UUID] {
        feedPosts.map({$0.id})
    }
    
    var featureList: some View {
        VStack{
            EmptyView()
        }
    }
    
    // exract a function to make infinite loop
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
                        FeedPostView(post: post)
                            .id(post.id)
                    }
                }
                .frame(width: (UIScreen.main.bounds.width - 30) * Double(feedPostNumber))
            }
            .scrollDisabled(true)
            .onAppear {
                // the onAppear function would be called whenever the view 'disappear' and 're-appeared' from end-user's view,
                // which means even the user switched under tabview, the function would be called once again.
                // using runOnce to make sure the scroll loop is created only once...
                // Not sure if SwiftUI have a seprate modifier for that...
                if !runOnce {
                    runOnce = true
                    _ = Task {
                        while (status != .success) {}
                        if let id = feedPostIDList.first {
                            scrollTo(proxy: proxy, id: id)
                        }
                    }
                }
            }
        }
    }
    
    var mainView: some View {
        VStack {
            TitleAndSubTitle(title: "Feed", subTitle: currentDateString,style: .reverse)
            Group {
                if status == .inProgress {
                    ProgressView()
                        .frame(width: UIScreen.main.bounds.width - 30, height: 200)
                } else {
                    feedHStack
                }
            }
            .onAppear {
                showUserFeedPost(number: feedPostNumber, posts: $feedPosts, status: $status)
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
