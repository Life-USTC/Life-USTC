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
                    .multilineTextAlignment(.center)
                    .font(.title2)
                    .fontWeight(.heavy)
            }

            Section {
                HTMLStringView(htmlContent: event.description)
                    .frame(height: 145)

                HStack {
                    HStack {
                        Image(systemName: "quote.bubble.rtl")
                            .foregroundColor(Color.accentColor)
                        Text("Info")
                            .fontWeight(.heavy)
                    }
                    .font(.callout)

                    Spacer()
                    Text(event.infoDescription)
                }

                HStack {
                    HStack {
                        Image(systemName: "star.circle")
                            .foregroundColor(Color.accentColor)
                        Text("Rating")
                            .fontWeight(.heavy)
                    }
                    .font(.callout)

                    Spacer()
                    Text(event.ratingTxt)
                }

                HStack(alignment: .top) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(Color.accentColor)
                        Text("Time")
                            .fontWeight(.heavy)
                    }
                    .font(.callout)

                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(event.startTime)
                        Text(event.endTime)
                    }
                }
            } header: {
                Text("Description")
            }

            if !event.children.isEmpty {
                Section {
                    ForEach(event.children) { subEvent in
                        USTCQCKDEventView(event: subEvent)
                    }

                } header: {
                    Text("Sub-Events")
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Image(systemName: "building.2")
                            .foregroundColor(Color.accentColor)
                        Text("Hosting Department")
                            .fontWeight(.heavy)
                    }
                    .font(.callout)
                    HStack {
                        Spacer()
                        Text(event.hostingDepartment)
                            .multilineTextAlignment(.trailing)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Image(systemName: "phone")
                            .foregroundColor(Color.accentColor)
                        Text("Contact Information")
                            .fontWeight(.heavy)
                    }
                    .font(.callout)
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
            HStack(alignment: .center) {
                if let image = phase.image {
                    image
                        .centerCropped()
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                } else {
                    ProgressView()
                        .frame(width: 70, height: 70)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(event.name)
                        .multilineTextAlignment(.leading)
                        .font(.title3)
                        .fontWeight(.heavy)
                        .lineLimit(1)

                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(Color.accentColor)
                        Text(event.startTime)
                    }
                    .font(.caption)

                    HStack {
                        Image(systemName: "star.circle")
                            .foregroundColor(Color.accentColor)
                        Text(event.ratingTxt)
                        Spacer()
                    }
                    .font(.caption)

                    HStack {
                        Image(systemName: "quote.bubble.rtl")
                            .foregroundColor(Color.accentColor)
                        Text(event.infoDescription)
                        Spacer()
                    }
                    .font(.caption)
                }
                .foregroundColor(.black)
            }
        }
        .padding(5)
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
                    Divider()
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

let selections = ["Available", "Done", "My"]

struct USTCQCKDView: View {
    @StateObject var ustcQCKDDelegate = USTCQCKDDelegate.shared
    @State var selection: String = "Available"
    var body: some View {
        VStack {
            Picker(selection: $selection) {
                ForEach(selections, id: \.self) { text in
                    Text(text)
                        .id(text)
                }
            } label: {
                Text("Picker")
            }
            .pickerStyle(.segmented)

            TabView(selection: $selection) {
                ForEach(selections, id: \.self) { text in
                    USTCQCKDEventListView(events: ustcQCKDDelegate.data.eventLists[text] ?? [],
                                          buttonStatus: ustcQCKDDelegate.status) {
                        try await ustcQCKDDelegate.fetchMorePage(for: text)
                    }
                    .tag(text)
                    .refreshable {
                        ustcQCKDDelegate.userTriggerRefresh()
                    }
                }
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
