//
//  USTC+QCKDView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/24.
//

import SwiftUI

struct USTCQCKDEventView: View {
    var event: UstcQCKDEvent

    var body: some View {
        AsyncImage(url: event.imageURL) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10.0))
            }
        }
        .overlay {
            LinearGradient(colors: [.clear, .black], startPoint: .center, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 10.0))
        }
        .overlay(alignment: .bottom) {
            VStack(alignment: .leading) {
                Text(event.name)
                    .font(.title2)
                //                Text(event.description)
                //                    .font(.footnote)
                Text(event.timeDescription)
                    .font(.caption2)
                Text(event.ratingTxt)
                    .font(.footnote)
            }
            .foregroundColor(.white)
            .padding()
        }
    }
}

struct USTCQCKDEventListView: View {
    var events: [UstcQCKDEvent] = []

    var body: some View {
        ScrollView {
            ForEach(events) { event in
                USTCQCKDEventView(event: event)
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
                USTCQCKDEventListView(events: ustcQCKDDelegate.data.availableEvents)
                    .tabItem {
                        Text("Available")
                    }
                    .tag("Available")

                USTCQCKDEventListView(events: ustcQCKDDelegate.data.doneEvents)
                    .tabItem {
                        Text("Done")
                    }
                    .tag("Done")

                USTCQCKDEventListView(events: ustcQCKDDelegate.data.myEvents)
                    .tabItem {
                        Text("My")
                    }
                    .tag("My")
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .asyncViewStatusMask(status: ustcQCKDDelegate.status)
        }
        .padding(.horizontal)
    }
}

struct USTCQCKD_PreviewProvider: PreviewProvider {
    static var previews: some View {
        USTCQCKDView()
    }
}
