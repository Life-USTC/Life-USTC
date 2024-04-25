//
//  CurriculumWeekView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/20.
//

import Charts
import SwiftUI

struct CurriculumWeekView: View {
    var lectures: [Lecture]
    var _date: Date
    var currentSemesterName: String
    var weekNumber: Int?
    var fontSize: Double = 10

    var date: Date {
        _date.startOfWeek()
    }
    var behavior: CurriculumBehavior {
        SchoolExport.shared.curriculumBehavior
    }
    var mergedTimes: [Int] {
        (behavior.shownTimes + behavior.highLightTimes).sorted()
    }

    func length(_ lecture: Lecture) -> Int {
        (lecture.endIndex ?? 0) - (lecture.startIndex ?? 0) + 1
    }

    var body: some View {
        Chart {
            if (date ... date.add(day: 7)).contains(Date().stripTime()) {
                // See GH#2
                BarMark(
                    xStart: .value(
                        "Start Time",
                        mergedTimes.first!
                    ),

                    xEnd: .value(
                        "End Time",
                        mergedTimes.last!
                    ),
                    y: .value("Date", Date().stripTime(), unit: .day)
                )
                .foregroundStyle(Color.accentColor.opacity(0.2))
            }

            ForEach(lectures) { lecture in
                BarMark(
                    xStart: .value(
                        "Start Time",
                        behavior.convertTo(lecture.startDate.HHMM)
                    ),

                    xEnd: .value(
                        "End Time",
                        behavior.convertTo(lecture.endDate.HHMM)
                    ),
                    y: .value("Date", lecture.startDate.stripTime(), unit: .day)
                )
                .foregroundStyle((lecture.course?.color() ?? .mint).opacity(0.4))
                .annotation(position: .overlay) {
                    HStack {
                        Text(lecture.name.truncated(length: length(lecture) > 2 ? 6 : 4))
                            .font(.system(size: 15, weight: .light))
                        Text("@\(lecture.location)")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    }
                    .minimumScaleFactor(0.01)
                }
            }
        }
        .chartXAxis {
            AxisMarks(position: .top, values: behavior.shownTimes) { value in
                if let _hhmm = value.as(Int.self) {
                    let hhmm = behavior.convertFrom(_hhmm)
                    AxisValueLabel {
                        Text(
                            "\(hhmm / 60, specifier: "%02d"):\(hhmm % 60, specifier: "%02d")"
                        )
                        .font(.system(size: fontSize - 1))
                    }
                    AxisGridLine()
                }
            }

            if (mergedTimes.first! ... mergedTimes.last!)
                .contains(behavior.convertTo(Date().stripDate().HHMM))
            {
                AxisMarks(
                    position: .bottom,
                    values: [behavior.convertTo(Date().stripDate().HHMM)]
                ) { _ in
                    AxisGridLine(stroke: .init(dash: []))
                        .foregroundStyle(.red)
                }
            }

            AxisMarks(position: .bottom, values: behavior.highLightTimes) {
                value in
                if let _hhmm = value.as(Int.self) {
                    let hhmm = behavior.convertFrom(_hhmm)
                    AxisValueLabel(anchor: .topTrailing) {
                        Text(
                            "\(hhmm / 60, specifier: "%02d"):\(hhmm % 60, specifier: "%02d")"
                        )
                        .foregroundColor(.blue)
                    }
                    AxisGridLine()
                        .foregroundStyle(.blue)
                }
            }
        }
        .chartXScale(domain: mergedTimes.first! ... mergedTimes.last!)
        .chartYAxis {
            AxisMarks(position: .leading, values: .stride(by: .day)) { _ in
                AxisGridLine()
            }

            AxisMarks(position: .leading, values: [date.add(day: 7)]) { _ in
                AxisGridLine()
            }
        }
        .chartYScale(domain: date ... date.add(day: 7))
        .if(lectures.isEmpty) {
            $0
                .redacted(reason: .placeholder)
                .blur(radius: 2)
                .overlay {
                    Text("No lectures this week")
                        .font(.system(.title2, design: .rounded))
                        .foregroundColor(.secondary)
                }
        }
    }
}
