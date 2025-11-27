//
//  CurriculumWeekViewVertical.swift
//  Life@USTC
//
//  Created by TianKai Ma on 2024/4/15.
//

import SwiftUI

private struct LectureView: View {
    var lecture: Lecture

    var length: Int {
        (lecture.endIndex ?? 0) - (lecture.startIndex ?? 0) + 1
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 5)
                .fill(lecture.course?.color.opacity(0.1) ?? Color.blue.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(lecture.startDate.clockTime)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))

                Group {
                    Text(lecture.name)
                        .font(.system(size: 15, weight: .light))
                        .lineLimit(2, reservesSpace: false)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.01)
                    Text(lecture.location)
                        .font(.system(size: 13, weight: .light, design: .monospaced))
                        .lineLimit(2, reservesSpace: false)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.01)
                }

                Spacer()

                if length > 1 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(lecture.teacherName)
                            .font(.system(size: 10))
                            .lineLimit(2, reservesSpace: false)
                            .multilineTextAlignment(.trailing)
                            .minimumScaleFactor(0.01)

                        Text(lecture.endDate.clockTime)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .hStackTrailing()
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
        }
        .lectureSheet(lecture: lecture)
    }
}

private let daysOfWeek: [String] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

struct CurriculumWeekViewVerticalNew: View {
    var lectures: [Lecture]
    var _date: Date
    var weekNumber: Int?
    var hideWeekend: Bool

    var date: Date {
        _date.startOfWeek()
    }

    @ViewBuilder
    func makeVStack(index: Int, heightPerClass: Double) -> some View {
        VStack {
            Text(daysOfWeek[index])
                .font(.system(.caption2, design: .monospaced, weight: .light))

            ZStack(alignment: .top) {
                if date.add(day: index) == Date().stripTime() {
                    Color("BackgroundWhite").colorInvert().opacity(0.06)
                } else {
                    Color.clear
                }

                ForEach(lectures.filter { (date.add(day: index) ... date.add(day: index + 1)).contains($0.startDate) })
                { lecture in
                    LectureView(lecture: lecture)
                        .frame(
                            width: .infinity,
                            height: heightPerClass * Double((lecture.endIndex ?? 0) - (lecture.startIndex ?? 0) + 1) - 4
                        )
                        .offset(y: Double((lecture.startIndex ?? 1) - 1) * heightPerClass + 2)
                        .padding(2)
                }

                Rectangle()
                    .fill(Color.accentColor.opacity(0.4))
                    .frame(height: 1)
                    .offset(y: 5 * heightPerClass + 1.5)

                Rectangle()
                    .fill(Color.accentColor.opacity(0.4))
                    .frame(height: 1)
                    .offset(y: 10 * heightPerClass + 1.5)
            }
        }
    }

    var body: some View {
        if hideWeekend {
            GeometryReader { geo in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(1 ..< 6) { index in
                        makeVStack(index: index, heightPerClass: geo.size.height / 13)
                            .frame(width: geo.size.width / 5, height: geo.size.height)
                    }
                }
                .background {
                    Color.clear
                        .contentShape(Rectangle())
                }
            }
        } else {
            GeometryReader { geo in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(0 ..< 7) { index in
                        makeVStack(index: index, heightPerClass: geo.size.height / 13)
                            .frame(width: geo.size.width / 7, height: geo.size.height)
                    }
                }
                .background {
                    Color.clear
                        .contentShape(Rectangle())
                }
            }
        }
    }
}
