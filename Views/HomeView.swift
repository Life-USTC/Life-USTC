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

var currentWeekDayString: String {
    daysOfWeek[(currentWeekDay + 6) % 7]
}

private struct HomeFeature {
    var title: String
    var subTitle: String
    var destination: AnyView
    var preview: AnyView
}

struct HomeView: View {
    private var features: [HomeFeature] =
        [.init(title: "Feed", subTitle: currentDateString, destination: .init(AllSourceView()), preview: .init(FeedHScrollView())),
         .init(title: "Curriculum", subTitle: currentWeekDayString, destination: .init(CurriculumView()), preview: .init(CurriculumPreview())),
         .init(title: "Exam", subTitle: "", destination: .init(ExamView()), preview: .init(ExamPreview()))]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                ForEach(features, id: \.title) { feature in
                    HStack {
                        TitleAndSubTitle(title: feature.title, subTitle: feature.subTitle, style: .reverse)
                        NavigationLink(destination: feature.destination) {
                            Label("More", systemImage: "chevron.right.2")
                                .labelStyle(.iconOnly)
                        }
                    }
                    feature.preview
                    Divider()
                }
            }
            .padding([.leading, .trailing])
            .navigationTitle("Life@USTC")
        }
    }
}
