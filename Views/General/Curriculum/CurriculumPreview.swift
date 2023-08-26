//
//  CurriculumPreview.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import SwiftUI

struct LectureView: View {
    var lecture: Lecture
    var color: Color = .red

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 5)
                .frame(maxHeight: 50)

            VStack(alignment: .leading) {
                Text(lecture.name)
                    .lineLimit(1)
                    .font(.system(.body, weight: .bold))

                HStack {
                    Text(lecture.location)
                    Text(lecture.name)
                }
                .lineLimit(1)
                .font(.system(.callout, weight: .light))

                Text(lecture.startDate ... lecture.endDate)
                    .lineLimit(1)
                    .font(.system(.caption, weight: .light))
            }
        }
    }
}

struct CurriculumPreview: View {
    var lectureListA: [Lecture]
    var lectureListB: [Lecture]
    var listAText: String = "Today"
    var listBText: String = "Tomorrow"

    @ViewBuilder
    func makeView(with lectures: [Lecture], text: String, color: Color = .blue)
        -> some View
    {
        VStack(alignment: .leading) {
            Text(text)
                .font(.system(.body, design: .monospaced, weight: .light))

            ForEach(lectures) { lecture in
                LectureView(lecture: lecture, color: color)
            }
            if lectures.isEmpty {
                LectureView(lecture: .example, color: .orange)
                    .redacted(reason: .placeholder)
            }

            Spacer()
        }
        .padding(.horizontal)
    }

    var body: some View {
        HStack {
            makeView(
                with: lectureListA,
                text: listAText,
                color: .red
            )
            Divider()
            makeView(
                with: lectureListB,
                text: listBText,
                color: .blue
            )
        }
    }
}

struct CurriculumTodayCard: View {
    @ManagedData(.curriculum) var curriculum: Curriculum

    var _date: Date = .now

    var date: Date { _date.stripTime() }

    var todayLectures: [Lecture] {
        curriculum.semesters.flatMap(\.courses).flatMap(\.lectures)
            .filter {
                (date ..< date.add(day: 1)).contains($0.startDate)
            }
    }

    var tomorrowLectures: [Lecture] {
        curriculum.semesters.flatMap(\.courses).flatMap(\.lectures)
            .filter {
                (date.add(day: 1) ..< date.add(day: 2)).contains($0.startDate)
            }
    }

    var body: some View {
        CurriculumPreview(
            lectureListA: todayLectures,
            lectureListB: tomorrowLectures
        )
        .asyncStatusOverlay(_curriculum.status, text: "Curriculum") {
            Button {
                _curriculum.triggerRefresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
        }
        .card()
    }
}
