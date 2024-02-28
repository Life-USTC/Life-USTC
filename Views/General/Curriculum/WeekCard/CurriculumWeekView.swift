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

    var body: some View {
        VStack {
            HStack {
                Text(date ... date.add(day: 6))

                if let weekNumber {
                    Spacer()

                    Text("Week \(weekNumber)")
                }

                Spacer()

                Text(currentSemesterName)
            }
            .font(.system(.caption2, design: .monospaced, weight: .light))

            mainView
        }
    }

    var mainView: some View {
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
                .foregroundStyle(by: .value("Course Name", lecture.name.truncated(length: 6)))
                .annotation(position: .overlay) {
                    Text(lecture.name)
                        .font(.system(size: fontSize))
                        .foregroundColor(.white)
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

struct CurriculumWeekViewVertical: View {
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

    var body: some View {
        VStack(alignment: .center) {
            HStack {
                Text(date ... date.add(day: 6))
                
                if let weekNumber {
                    Spacer()
                    
                    if (date ... date.add(day: 7)).contains(Date().stripTime()) {
                        Text(String(format: "Week %@".localized, String(weekNumber)))
                    } else {
                        Text(String(format: "Week %@ [NOT CURRENT]".localized, String(weekNumber)))
                    }
                } else if !(date ... date.add(day: 7)).contains(Date().stripTime()) {
                    Spacer()

                    Text("[NOT CURRENT]")
                }

                Spacer()

                Text(currentSemesterName)
            }
            .font(.system(.caption2, design: .monospaced, weight: .light))

            mainView
        }
    }
    var mainView: some View {
        Chart {
            if (date ... date.add(day: 7)).contains(Date().stripTime()) {
                // See GH#2
                BarMark(
                    x: .value("Date", Date().stripTime(), unit: .day),
                    yStart: .value(
                        "Start Time",
                        -mergedTimes.first!
                    ),

                    yEnd: .value(
                        "End Time",
                        -mergedTimes.last!
                    )
                )
                .foregroundStyle(Color.accentColor.opacity(0.2))
            }

            ForEach(lectures) { lecture in
                BarMark(
                    x: .value("Date", lecture.startDate.stripTime(), unit: .day),
                    yStart: .value(
                        "Start Time",
                        -behavior.convertTo(lecture.startDate.HHMM)
                    ),

                    yEnd: .value(
                        "End Time",
                        -behavior.convertTo(lecture.endDate.HHMM)
                    )
                )
                .foregroundStyle(by: .value("Course Name", lecture.name.truncated(length: 6)))
                .annotation(position: .overlay) {
                    VStack {
                        Text(lecture.name)
                            .font(.system(size: fontSize))
                            .multilineTextAlignment(.center)
                        Text(lecture.location)
                            .font(.system(size: fontSize - 1))
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom, values: .stride(by: .day)) { _ in
                AxisGridLine()
            }
        }
        .chartXScale(domain: date ... date.add(day: 7))
        .chartYAxis {
            AxisMarks(position: .leading, values: behavior.shownTimes.map { -$0 }) { value in
                if let _hhmm = value.as(Int.self) {
                    let hhmm = behavior.convertFrom(-_hhmm)
                    AxisValueLabel(anchor: .topTrailing) {
                        Text(
                            "\(hhmm / 60, specifier: "%02d"):\(hhmm % 60, specifier: "%02d")"
                        )
                    }
                    AxisGridLine()
                }
            }

            AxisMarks(position: .leading, values: behavior.highLightTimes.map { -$0 }) {
                value in
                if let _hhmm = value.as(Int.self) {
                    let hhmm = behavior.convertFrom(-_hhmm)
                    AxisValueLabel(anchor: .bottomTrailing) {
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
        .chartYScale(domain: -mergedTimes.last! ... -mergedTimes.first!)
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
