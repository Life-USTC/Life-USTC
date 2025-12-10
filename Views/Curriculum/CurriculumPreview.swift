//
//  CurriculumPreview.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import SwiftUI

struct CurriculumPreview: View {
    var todayLectures: [Lecture] = []
    var tomorrowLectures: [Lecture] = []

    @ViewBuilder
    func makeView(
        with lectures: [Lecture],
        text: LocalizedStringKey? = nil,
    ) -> some View {
        VStack(spacing: 10) {
            if let text {
                Text(text)
                    .foregroundColor(.gray)
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                    .hStackLeading()
            }

            ForEach(lectures) { lecture in
                LectureView(lecture: lecture)
                    .lectureSheet(lecture: lecture)
            }
        }
    }

    var body: some View {
        VStack(spacing: 30) {
            if !todayLectures.isEmpty {
                makeView(with: todayLectures, text: "Today")
            }
            if !tomorrowLectures.isEmpty {
                makeView(with: tomorrowLectures, text: "Tomorrow")
            }
            if todayLectures.isEmpty && tomorrowLectures.isEmpty {
                ContentUnavailableView(
                    "Nothing here",
                    systemImage: "calendar.badge.checkmark",
                )
            }
        }
    }
}
