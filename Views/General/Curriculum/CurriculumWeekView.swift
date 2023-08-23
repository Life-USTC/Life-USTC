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

    @State var date: Date = .init() {
        willSet {
            date = newValue.stripTime()
        }
    }

    @State var currentSemester: Semester?
    @State var lectures: [Lecture] = []
    @State var scrollPostion: Int = 0

    var dateRange: ClosedRange<Date> {
        date.add(day: -2) ... date.add(day: 3)
    }

    var dates: [Date] {
        (-2 ... 2).map { date.add(day: $0) }
    }

    func updateLectures() {
        if currentSemester == nil {
            lectures = curriculum.semesters.flatMap {
                $0.courses.flatMap(\.lectures)
            }.filter {
                dateRange.contains($0.startDate.stripTime())
            }
        } else {
            lectures = (currentSemester?.courses.flatMap(\.lectures) ?? []).filter {
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
        .frame(height: 150)
    }

    var mainView: some View {
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
                    AxisValueLabel(anchor: .trailing) {
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
        .frame(height: 180)
        .asyncStatusMask(status: _curriculum.status)
        .refreshable {
            _curriculum.triggerRefresh()
        }
    }

    @State var flipped = false
    var flippedDegrees: Double {
        flipped ? 180 : 0
    }

    var body: some View {
        VStack(alignment: .trailing) {
            Button {
                withAnimation(.easeInOut) {
                    flipped.toggle()
                }
            } label: {
                Label(flipped ? "Chart" : "Settings",
                      systemImage: flipped ? "chart.bar.xaxis" : "gearshape")
                    .font(.caption2)
            }

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
