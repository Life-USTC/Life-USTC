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

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                Text("Current:")
                ForEach(lectureListA) { lecture in
                    LectureView(lecture: lecture)
                }
            }

            Divider()

            VStack(alignment: .leading) {
                Text("Upcoming:")
                ForEach(lectureListB) { lecture in
                    LectureView(lecture: lecture, color: .blue)
                }
            }
        }
    }
}
