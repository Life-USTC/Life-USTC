//
//  USTC+QCKDView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/24.
//

import SwiftUI

struct USTCQCKDEventDetailView: View {
    var event: UstcQCKDEvent
    var body: some View {
        List {
            Section {
                AsyncImage(url: event.imageURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFit()
                    } else {
                        ProgressView()
                    }
                }

                Text(event.name)
                    .multilineTextAlignment(.trailing)
                    .font(.title)
            }

            Section {
                HTMLStringView(htmlContent: event.description)
                    .frame(height: 150)

                HStack {
                    Label("Info", systemImage: "quote.bubble.rtl")
                    Spacer()
                    Text(event.infoDescription)
                }

                HStack {
                    Label("Rating", systemImage: "star.circle")
                    Spacer()
                    Text(event.ratingTxt)
                }

                HStack(alignment: .top) {
                    Label("Time", systemImage: "calendar.badge.clock")
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(event.startTime)
                        Text(event.endTime)
                    }
                }
            } header: {
                Text("Description")
            }

            Section {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Hosting Department", systemImage: "building.2")
                    HStack {
                        Spacer()
                        Text(event.hostingDepartment)
                            .multilineTextAlignment(.trailing)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Label("Contact Information", systemImage: "phone")
                    HStack {
                        Spacer()
                        Text(event.contactInformation)
                            .multilineTextAlignment(.trailing)
                    }
                }
            } header: {
                Text("More Information")
            }
        }
        .navigationTitle(event.name)
    }
}

struct USTCQCKDEventView: View {
    var event: UstcQCKDEvent

    var body: some View {
        NavigationLink {
            USTCQCKDEventDetailView(event: event)
        } label: {
            mainView
        }
    }

    var mainView: some View {
        AsyncImage(url: event.imageURL) { phase in
            ZStack {
                RoundedRectangle(cornerRadius: 10.0)
                    .fill(Color.gray)
                    .frame(width: 300, height: 200)
                if let image = phase.image {
                    image
                        .centerCropped()
                        .frame(width: 300, height: 200)
                } else {
                    ProgressView()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10.0))
        .overlay {
            LinearGradient(colors: [.clear, .black], startPoint: .init(x: 0.5, y: 0.25), endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 10.0))
        }
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 5) {
                Text(event.name)
                    .multilineTextAlignment(.leading)
                    .font(.title2)

                HStack {
                    Image(systemName: "calendar.badge.clock")
                    Text(event.timeDescription)
                }
                .font(.caption)

                HStack {
                    Image(systemName: "star.circle")
                    Text(event.ratingTxt)

                    Spacer()

                    Image(systemName: "quote.bubble.rtl")
                    Text(event.infoDescription)

                    Spacer()
                }
                .font(.caption)
            }
            .foregroundColor(.white)
            .padding()
        }
    }
}

struct USTCQCKDEventListView: View {
    var events: [UstcQCKDEvent] = []
    var buttonStatus: AsyncViewStatus?
    var reloadFunc: () async throws -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(events) { event in
                    USTCQCKDEventView(event: event)
                }

                Button {
                    Task {
                        try await reloadFunc()
                    }
                } label: {
                    Label("Fetch more", systemImage: "clock.arrow.2.circlepath")
                }
                .asyncViewStatusMask(status: buttonStatus)
            }
        }
    }
}

struct USTCQCKDView: View {
    @StateObject var ustcQCKDDelegate = USTCQCKDDelegate.shared
    @State var selection: String = "Available"
    var body: some View {
        VStack {
            Picker(selection: $selection) {
                Text("Available")
                    .tag("Available")
                Text("Done")
                    .tag("Done")
                Text("My")
                    .tag("My")

            } label: {
                Text("Picker")
            }
            .pickerStyle(.segmented)

            TabView(selection: $selection) {
                USTCQCKDEventListView(events: ustcQCKDDelegate.data.availableEvents, buttonStatus: ustcQCKDDelegate.status) {
                    try await ustcQCKDDelegate.fetchMorePage(for: "Available")
                }
                .tabItem {
                    Text("Available")
                }
                .tag("Available")

                USTCQCKDEventListView(events: ustcQCKDDelegate.data.doneEvents, buttonStatus: ustcQCKDDelegate.status) {
                    try await ustcQCKDDelegate.fetchMorePage(for: "Done")
                }
                .tabItem {
                    Text("Done")
                }
                .tag("Done")

                USTCQCKDEventListView(events: ustcQCKDDelegate.data.myEvents, buttonStatus: ustcQCKDDelegate.status) {
                    try await ustcQCKDDelegate.fetchMorePage(for: "My")
                }
                .tabItem {
                    Text("My")
                }
                .tag("My")
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .padding(.horizontal)
        .navigationTitle("QCKD")
    }
}

struct USTCQCKD_PreviewProvider: PreviewProvider {
    static var previews: some View {
//        USTCQCKDView()
        USTCQCKDEventDetailView(event: .example)
    }
}
