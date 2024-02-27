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
                    Text(lecture.teacherName)
                }
                .lineLimit(1)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .bold()

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

struct LectureWidgetView: View {
    var lecture: Lecture
    var color: Color = .red

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(lecture.name)
                    .font(.headline)
                    .fontWeight(.bold)
                HStack {
                    Text("\(lecture.teacherName) @ \(lecture.location)")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.8))
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(lecture.startDate.stripHMwithTimezone())
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.mint)
                Text(lecture.endDate.stripHMwithTimezone())
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.8))
            }
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
        color: Color = Color("AccentColor")
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
        color: Color = Color("AccentColor")
    )
        -> some View
    {
        if let lecture {
            VStack(alignment: .leading) {
                VStack(alignment: .leading) {
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
                        Text(lecture.teacherName)
                    }
                    .font(.subheadline)
                    .fontWeight(.regular)
                    .foregroundColor(.gray.opacity(0.8))
                }
            }
        } else {
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

    @ViewBuilder
    func makeListWidget(
        with lectures: [Lecture],
        color: Color = Color("AccentColor"),
        numberToShow: Int = 2
    )
        -> some View
    {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Class")
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.mint)
                    )
                Spacer()
            }
            .padding(.bottom, 10)
            if !lectures.isEmpty {
                ForEach(Array(lectures.prefix(numberToShow).enumerated()), id: \.1.id) { index, lecture in
                    LectureWidgetView(lecture: lecture, color: color)
                    
                    if index < lectures.count - 1 {
                        Divider()
                            .padding(.vertical, 7)
                    }
                }
            } else {
                Text("No courses today!")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    var body: some View {
        VStack {
            makeView(
                with: lectureListA,
                text: listAText,
                color: .mint
            )
            Divider()
            makeView(
                with: lectureListB,
                text: listBText,
                color: .orange
            )
        }
    }
}
