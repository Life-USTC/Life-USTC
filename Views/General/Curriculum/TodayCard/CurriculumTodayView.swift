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
                .frame(minHeight: 40, maxHeight: 50)

            VStack(alignment: .leading) {
                Text(lecture.name)
                    .lineLimit(1)
                    .font(.system(.body, weight: .semibold))

                HStack {
                    Text(lecture.location)
                    Text(lecture.teacher)
                }
                .lineLimit(1)
                .font(.system(.caption, weight: .light))

                Text(lecture.startDate ... lecture.endDate)
                    .lineLimit(1)
                    .font(
                        .system(.caption, design: .monospaced, weight: .medium)
                    )
            }

            Spacer()
        }
    }
}

struct CurriculumTodayView: View {
    var lectureListA: [Lecture] = []
    var lectureListB: [Lecture] = []
    var listAText: String? = "Today"
    var listBText: String? = "Tomorrow"

    @ViewBuilder
    func makeView(
        with lectures: [Lecture],
        text: String? = nil,
        color: Color = .blue
    )
        -> some View
    {
        VStack(alignment: .leading) {
            if let text {
                Text(text.localized)
                    .foregroundColor(.gray)
                    .font(.system(.title3, design: .monospaced, weight: .bold))
            }

            ForEach(lectures) { lecture in
                LectureView(lecture: lecture, color: color)
            }

            if lectures.isEmpty {
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color("AccentColor"))
                        .frame(width: 5)
                        .frame(minHeight: 40, maxHeight: 50)

                    VStack(alignment: .leading) {
                        Text("Nothing here")
                            .lineLimit(1)
                            .font(.system(.body, weight: .semibold))

                        Text("Enjoy!")
                            .lineLimit(1)
                            .font(
                                .system(
                                    .caption,
                                    design: .monospaced,
                                    weight: .medium
                                )
                            )
                            .foregroundColor(.gray)
                    }

                    Spacer()
                }
            }

            Spacer()
        }
    }

    var body: some View {
        VStack {
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
