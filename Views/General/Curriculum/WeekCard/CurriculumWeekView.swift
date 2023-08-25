//
//  CurriculumWeekView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/20.
//

import Charts
import SwiftUI

struct CurriculumWeekView: View {
    @State var lectures: [Lecture] = []
    @State var _date: Date = .now

    var date: Date {
        _date.startOfWeek()
    }
    var behavior: CurriculumBehavior {
        SchoolExport.shared.curriculumBehavior
    }
    var mergedTimes: [Int] {
        (behavior.shownTimes + behavior.highLightTimes).sorted()
    }

    var body: some View {
        Chart {
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
                .foregroundStyle(by: .value("Course Name", lecture.name))
                .annotation(position: .overlay) {
                    Text(lecture.name).font(.caption).foregroundColor(.white)
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
                    }
                    AxisGridLine()
                }
            }

            AxisMarks(
                position: .bottom,
                values: [behavior.convertTo(Date().stripDate().HHMM)]
            ) { _ in
                AxisGridLine(stroke: .init(dash: []))
                    .foregroundStyle(.red)
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
        .frame(height: 230)
    }
}
