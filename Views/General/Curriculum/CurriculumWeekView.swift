//
//  CurriculumWeekView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/20.
//

import Charts
import SwiftUI

struct CurriculumWeekView: View {
    @ManagedData(\.curriculum) var curriculum: Curriculum!
    @State var date: Date = .init()
    @State var lectures: [Lecture] = []

    func updateLectures() {
        lectures = curriculum.semesters.flatMap {
            $0.courses.flatMap(\.lectures)
        }
        .filter {
            $0.startDate.stripTime() < date && $0.startDate.stripTime() > date.add(day: -5)
        }
    }

    var body: some View {
        ScrollView {
            DatePicker(selection: $date, displayedComponents: .date) {
                Text("Date")
            }

            Chart {
                ForEach(lectures) { lecture in
                    BarMark(xStart: .value("Start Time", lecture.startDate.stripDate()),
                            xEnd: .value("End Time", lecture.endDate.stripDate()),
                            y: .value("Date", lecture.startDate.stripTime(), unit: .day))
                        .foregroundStyle(by: .value("Course Name", lecture.name))
                        .annotation(position: .overlay) {
                            Text(lecture.name)
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                }
            }
            .chartXAxis {
                AxisMarks(position: .top, values: .stride(by: .hour,
                                                          count: 2,
                                                          roundLowerBound: true,
                                                          roundUpperBound: true,
                                                          calendar: .autoupdatingCurrent)) { _ in
                    AxisValueLabel(format: Date.FormatStyle(time: .shortened))
                }
            }
            .chartXScale(domain: Date().stripDate().stripTime().addingTimeInterval(7 * 3600 + 50 * 60) ... Date().stripDate().stripTime().addingTimeInterval(12 * 3600 + 30 * 60))
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 6)) { _ in
                    AxisValueLabel(format: .dateTime.day())
                }
            }
            .chartYScale(domain: date.add(day: -5) ... date)
            .onChange(of: date) { _ in
                updateLectures()
            }
            .onReceive(_curriculum.$wrappedValue) { _ in
                updateLectures()
            }
            .frame(height: 230)
        }
    }
}
