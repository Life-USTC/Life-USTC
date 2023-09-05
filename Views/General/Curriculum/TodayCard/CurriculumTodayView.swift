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
    
    @ViewBuilder
    func makeWidget(
        with lecture: Lecture?,
        text: String? = nil,
        color: Color = .blue
    )
        -> some View
    {
        if let lecture {
            VStack(alignment: .leading) {
                VStack (alignment: .leading) {
                    HStack {
                        Text("Class")
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.mint.opacity(0.8))
                            )
                        Text(lecture.location)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .foregroundColor(.mint)
                    }
                    Text(lecture.name)
                        .lineLimit(2)
                        .fontWeight(.bold)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text(lecture.startDate.stripHMwithTimezone())
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.mint)
                    HStack {
                        Text(lecture.endDate.stripHMwithTimezone())
                        Spacer()
                        Text(lecture.teacher)
                    }
                    .font(.subheadline)
                    .fontWeight(.regular)
                    .foregroundColor(.gray.opacity(0.8))
                }
            }
        }
        else {
            VStack(alignment: .center, spacing: 20) {
                        Image(systemName: "moon.stars")
                            .font(.system(size: 50))
                            .fontWeight(.regular)
                            .frame(width: 60, height: 60)
                            .padding(5)
                            .fontWeight(.heavy)
                            .foregroundColor(.mint.opacity(0.8))
                        Text("No courses today!")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding()
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
