//
//  CurriculumWeekView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/20.
//

import Charts
import SwiftUI

@available(iOS 17.0, *)
struct CurriculumWeekView: View {
    @ManagedData(.curriculum) var curriculum: Curriculum

    @State var currentSemester: Semester?
//    @State var scrollPostion: Int = 7 * 60 + 50 {
//        willSet {
//            // round to nearest showTimes
//            scrollPostion = shownTimes.min(by: {
//                abs($0 - newValue) < abs($1 - newValue)
//            }) ?? newValue
//        }
//    }
    @State var flipped = false
    @State var date: Date = .init() {
        willSet {
            date = newValue.stripTime()
        }
    }

    var flippedDegrees: Double {
        flipped ? 180 : 0
    }

    var shownDateRange: ClosedRange<Date> {
        date.add(day: -4) ... date.add(day: 4)
    }

    var dateRange: ClosedRange<Date> {
        date.add(day: -3) ... date.add(day: 3)
    }

    var dates: [Date] {
        (-3 ... 3).map { date.add(day: $0) }
    }

    var lectures: [Lecture] {
        if currentSemester == nil {
            return curriculum.semesters.flatMap {
                $0.courses.flatMap(\.lectures)
            }.filter {
                dateRange.contains($0.startDate.stripTime())
            }
        } else {
            return (currentSemester?.courses.flatMap(\.lectures) ?? []).filter {
                dateRange.contains($0.startDate.stripTime())
            }
        }
    }

    var shownTimes: [Int] = [
        7 * 60 + 50,
        9 * 60 + 45,
        11 * 60 + 20,
        14 * 60 + 0,
        15 * 60 + 55,
        17 * 60 + 30,
        19 * 60 + 30,
        21 * 60 + 5,
        21 * 60 + 55,
    ]

    var highLightTimes: [Int] = [
        12 * 60 + 10,
        18 * 60 + 20,
    ]

    var settingsView: some View {
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
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .overlay(alignment: .topTrailing) {
            flipButton
        }
    }

    var chartView: some View {
        Chart {
            ForEach(lectures) { lecture in
                BarMark(xStart: .value("Start Time", lecture.startDate.HHMM),
                        xEnd: .value("End Time", lecture.endDate.HHMM),
                        y: .value("Date", lecture.startDate.stripTime(), unit: .day))
                    .foregroundStyle(by: .value("Course Name", lecture.name))
                    .annotation(position: .overlay) {
                        Text(lecture.name + " @ " + lecture.location)
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
                AxisValueLabel(anchor: .trailing) {
                    Text("Now")
                        .foregroundColor(.red)
                }
                AxisGridLine()
                    .foregroundStyle(.red)
            }

            AxisMarks(position: .bottom, values: highLightTimes) { value in
                if let hhmm = value.as(Int.self) {
                    AxisValueLabel(anchor: .trailing) {
                        Text("\(hhmm / 60):\(hhmm % 60, specifier: "%02d")")
                            .foregroundColor(.blue)
                    }
                    AxisGridLine()
                        .foregroundStyle(.blue)
                }
            }
        }
        .chartXScale(domain: shownTimes.first! ... shownTimes.last!)
//        .chartScrollPosition(x: $scrollPostion)
        .chartScrollPosition(initialX: shownTimes.first!)
        .chartScrollTargetBehavior(.valueAligned(unit: 75, majorAlignment: .page))
        .chartYAxis {
            AxisMarks(position: .leading, values: dates) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
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
        .chartYScale(domain: shownDateRange)
        .chartLegend(.hidden)
        .chartScrollableAxes(.horizontal)
        .frame(height: 230)
    }

    var jumpView: some View {
        Menu {
//            Button {
//                scrollPostion = 7 * 60 + 20
//            } label: {
//                Text("7:50")
//            }
//
//            Button {
//                scrollPostion = 14 * 60 + 0
//            } label: {
//                Text("14:00")
//            }
//
//            Button {
//                scrollPostion = 19 * 60 + 30
//            } label: {
//                Text("19:30")
//            }
        } label: {
            Label("Jump", systemImage: "arrow.up.and.down")
                .font(.caption)
        }
    }

    var mainView: some View {
        VStack {
            HStack {
                Text("Curriculum")
                    .font(.caption)
                    .fontWeight(.bold)
                    .fontDesign(.monospaced)

                AsyncStatusLight(status: _curriculum.status)

                Spacer()

                refreshButton
                flipButton
            }

            chartView
                .asyncStatusOverlay(_curriculum.status, showLight: false)
                .refreshable {
                    _curriculum.triggerRefresh()
                }

            jumpView
        }
    }

    var refreshButton: some View {
        Button {
            _curriculum.triggerRefresh()
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .font(.caption)
        }
    }

    var flipButton: some View {
        Button {
            withAnimation(.easeInOut) {
                flipped.toggle()
            }
        } label: {
            Label(flipped ? "Chart" : "Settings",
                  systemImage: flipped ? "chart.bar.xaxis" : "gearshape")
                .font(.caption)
        }
    }

    var body: some View {
        VStack(alignment: .trailing) {
            ZStack {
                mainView
                    .flipRotate(flippedDegrees)
                    .opacity(flipped ? 0 : 1)

                settingsView
                    .flipRotate(-180 + flippedDegrees)
                    .opacity(flipped ? 1 : 0)
            }
            .padding()
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.secondary, lineWidth: 0.2)
            }
        }
    }
}

extension View {
    func flipRotate(_ degrees: Double) -> some View {
        rotation3DEffect(
            Angle(degrees: degrees),
            axis: (x: 1.0, y: 0.0, z: 0.0)
        )
    }
}
