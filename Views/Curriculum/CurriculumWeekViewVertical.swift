//
//  CurriculumWeekViewVertical.swift
//  Life@USTC
//
//  Created by TianKai Ma on 2024/4/15.
//

import SwiftUI

private let daysOfWeek: [String] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

struct CurriculumWeekViewVerticalNew: View {
    var lectures: [Lecture]
    var referenceDate: Date
    var hideWeekend: Bool

    var todayStart: Date { referenceDate.stripTime() }
    var weekStart: Date { todayStart.startOfWeek() }

    @ViewBuilder
    func makeVStack(index: Int, heightPerClass: Double) -> some View {
        let isToday = weekStart.add(day: index) == Date().stripTime()
        let lecutresFiltered = lectures.filter {
            (weekStart.add(day: index) ... weekStart.add(day: index + 1)).contains($0.startDate)
        }

        VStack {
            Text(daysOfWeek[index])
                .font(.system(.caption2, design: .monospaced, weight: .light))

            ZStack(alignment: .top) {
                if isToday {
                    Color.white
                        .blendMode(.exclusion)
                        .opacity(0.04)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .ignoresSafeArea()
                } else {
                    Color.clear
                }

                ForEach(lecutresFiltered) { lecture in
                    LectureCardView(lecture: lecture)
                        .frame(
                            width: .infinity,
                            height: heightPerClass * Double(lecture.length) - 4
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
        GeometryReader { geo in
            HStack(alignment: .top, spacing: 0) {
                if hideWeekend {
                    ForEach(1 ..< 6) { index in
                        makeVStack(index: index, heightPerClass: geo.size.height / 13)
                            .frame(width: geo.size.width / 5, height: geo.size.height)
                    }
                } else {
                    ForEach(0 ..< 7) { index in
                        makeVStack(index: index, heightPerClass: geo.size.height / 13)
                            .frame(width: geo.size.width / 7, height: geo.size.height)
                    }
                }
            }
        }
        .background {
            Color.clear
                .contentShape(Rectangle())
        }
    }
}
