//
//  HomeView.swift
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

let daysOfWeek: [String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

var currentWeekDay: Int {
    let calendar = Calendar.current
    let weekday = calendar.component(.weekday, from: Date())
    return (weekday + 6) % 7
}

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                HStack {
                    TitleAndSubTitle(title: "Feed", subTitle: currentDateString, style: .reverse)
                    NavigationLink(destination: AllSourceView()) {
                        Label("More", systemImage: "chevron.right.2")
                            .labelStyle(.iconOnly)
                    }
                }
                FeedHScrollView()
                Divider()

                HStack {
                    TitleAndSubTitle(title: "Curriculum", subTitle: daysOfWeek[currentWeekDay - 1], style: .reverse)
                    NavigationLink(destination: CurriculumView()) {
                        Label("More", systemImage: "chevron.right.2")
                            .labelStyle(.iconOnly)
                    }
                }
                CurriculumPreview()
                    .frame(width: cardWidth, height: cardHeight)
                Divider()
            }
            .padding()
            .navigationTitle("Life@USTC")
        }
    }
}
