//
//  CurriculumWeekViewVertical.swift
//  学在科大
//
//  Created by TianKai Ma on 2024/4/15.
//

import SwiftUI

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
                    Color.backgroundWhite.colorInvert().opacity(0.06)
                } else {
                    Color.clear
                }

                ForEach(lectures.filter { (date.add(day: index) ... date.add(day: index + 1)).contains($0.startDate) })
                { lecture in
                    LectureCardView(lecture: lecture)
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
