//
//  CurriculumWeekView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/20.
//

import Charts
import SwiftUI

func HHMM(hour: Int, minute: Int) -> Int {
    hour * 60 + minute
}

struct CurriculumWeekView: View {
    @ManagedData(\.curriculum) var curriculum: Curriculum!
    @State var status: AsyncStatus?
    @State var date: Date = .init() {
        willSet {
            date = newValue.stripTime()
        }
    }

    @State var currentSemester: Semester?
    @State var lectures: [Lecture] = []
    @State var scrollPostion: Int = 0

    var dateRange: ClosedRange<Date> {
        date
            .add(day: -2)
            ...
            date
            .add(day: 3)
    }

    var dates: [Date] {
        (-2 ... 2).map {
            date
                .add(day: $0)
        }
    }

    func updateLectures() {
        if currentSemester == nil {
            lectures = (curriculum?.semesters.flatMap {
                $0.courses.flatMap(\.lectures)
            } ?? []).filter {
                dateRange.contains($0.startDate.stripTime())
            }
        } else {
            lectures = (currentSemester?.courses.flatMap(\.lectures) ?? []).filter {
                dateRange.contains($0.startDate.stripTime())
            }
        }
    }

    var shownTimes: [Int] = [
        HHMM(hour: 7, minute: 50),
        HHMM(hour: 9, minute: 45),
        HHMM(hour: 11, minute: 20),
        HHMM(hour: 14, minute: 0),
        HHMM(hour: 15, minute: 55),
        HHMM(hour: 17, minute: 30),
        HHMM(hour: 19, minute: 30),
        HHMM(hour: 21, minute: 5),
        HHMM(hour: 21, minute: 55),
    ]

    var highLightTimes: [Int] = [
        HHMM(hour: 12, minute: 10),
        HHMM(hour: 18, minute: 20),
    ]

    var body: some View {
        if #available(iOS 17.0, *) {
            VStack {
                List {
                    DatePicker(selection: $date, displayedComponents: .date) {
                        Text("Date")
                    }

                    HStack {
                        Text("Semester")
                        Spacer()
                        Menu {
                            ForEach(curriculum.semesters) { semester in
                                Button(semester.name) {
                                    currentSemester = semester
                                }
                            }
                            Button("All") {
                                currentSemester = nil
                            }
                        } label: {
                            Text(currentSemester?.name ?? "All")
                        }
                    }
                }
                .listStyle(.grouped)
                .scrollContentBackground(.hidden)
                .frame(height: 150)

                Chart {
                    ForEach(lectures) { lecture in
                        BarMark(xStart: .value("Start Time", lecture.startDate.HHMM),
                                xEnd: .value("End Time", lecture.endDate.HHMM),
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
                    AxisMarks(position: .top, values: shownTimes) { value in
                        if let hhmm = value.as(Int.self) {
                            AxisValueLabel {
                                Text("\(hhmm / 60):\(hhmm % 60, specifier: "%02d")")
                            }
                            AxisGridLine()
                        }
                    }

                    AxisMarks(position: .bottom, values: [Date().stripDate().HHMM]) { _ in
                        AxisValueLabel {
                            Text("Now")
                                .foregroundColor(.red)
                        }
                        AxisGridLine()
                            .foregroundStyle(.red)
                    }

                    AxisMarks(position: .bottom, values: highLightTimes) { value in
                        if let hhmm = value.as(Int.self) {
                            AxisValueLabel {
                                Text("\(hhmm / 60):\(hhmm % 60, specifier: "%02d")")
                                    .foregroundColor(.blue)
                            }
                            AxisGridLine()
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .chartXScale(domain: shownTimes.first! ... shownTimes.last!,
                             range: .plotDimension(padding: 5))
                .chartScrollPosition(initialX: shownTimes.first!)
                .chartScrollPosition(x: $scrollPostion)
                .chartYAxis {
                    AxisMarks(position: .leading, values: dates) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel(anchor: .topTrailing) {
                                HStack(spacing: 2) {
                                    Text(date, format: .dateTime.day())
                                    Text(date, format: .dateTime.weekday())
                                }
                                .fontDesign(.monospaced)
                                .foregroundColor(date == self.date ? .red : .secondary)
                            }
                            AxisGridLine()
                        }
                    }
                }
                .chartYScale(domain: dateRange)
                .chartLegend(.hidden)
                .chartScrollableAxes(.horizontal)
                .onChange(of: date) { _ in
                    updateLectures()
                }
                .onChange(of: currentSemester) { _ in
                    updateLectures()
                }
                .onReceive(_curriculum.$wrappedValue) { _ in
                    updateLectures()
                }
                .frame(height: 230)
            }
            .asyncStatusMask(status: status)
            .refreshable {
                _curriculum.userTriggeredRefresh()
            }
            .onReceive(_curriculum.$status, perform: {
                status = $0
            })
        }
    }
}
