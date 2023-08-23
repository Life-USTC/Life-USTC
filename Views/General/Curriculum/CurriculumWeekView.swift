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
    @State var flipped = false
    @State var _date: Date = .init()
    @State var lectures: [Lecture] = []
    var date: Date {
        _date.startOfWeek()
    }

    var flippedDegrees: Double {
        flipped ? 180 : 0
    }

    func updateLectures() {
        lectures = (
            currentSemester == nil ?
                curriculum.semesters.flatMap { $0.courses.flatMap(\.lectures) } :
                currentSemester!.courses.flatMap(\.lectures)
        ).filter {
            (0.0 ..< 3600.0 * 24 * 7).contains(
                $0.startDate.stripTime().timeIntervalSince(date)
            )
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
        VStack(alignment: .leading) {
            topBar

            DatePicker("Date", selection: $_date, displayedComponents: .date)
                .datePickerStyle(.compact)

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

            Divider()

            Spacer()
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
                        Text("\(hhmm / 60, specifier: "%02d"):\(hhmm % 60, specifier: "%02d")")
                    }
                    AxisGridLine()
                }
            }

            AxisMarks(position: .bottom, values: [Date().stripDate().HHMM]) { _ in
                AxisValueLabel(anchor: .topTrailing) {
                    Text("Now")
                        .foregroundColor(.red)
                }
                AxisGridLine()
                    .foregroundStyle(.red)
            }

            AxisMarks(position: .bottom, values: highLightTimes) { value in
                if let hhmm = value.as(Int.self) {
                    AxisValueLabel(anchor: .topTrailing) {
                        Text("\(hhmm / 60, specifier: "%02d"):\(hhmm % 60, specifier: "%02d")")
                            .foregroundColor(.blue)
                    }
                    AxisGridLine()
                        .foregroundStyle(.blue)
                }
            }
        }
        .chartXScale(domain: shownTimes.first! ... shownTimes.last!)
        .chartScrollPosition(initialX: shownTimes.first!)
        .chartScrollTargetBehavior(.valueAligned(unit: 75, majorAlignment: .page))
        .chartYAxis {
            AxisMarks(position: .leading, values: .stride(by: .day)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        HStack(spacing: 2) {
                            Text(date, format: .dateTime.day())
                            Text(date, format: .dateTime.weekday())
                        }
                        .fontDesign(.monospaced)
                        .foregroundColor(date == Date().stripTime() ? .red : .secondary)
                    }
                    AxisGridLine()
                }
            }
        }
        .chartYVisibleDomain(length: 3600 * 24 * 7)
        .chartYScale(domain: date ... date.add(day: 6))
        .chartLegend(.hidden)
        .chartScrollableAxes([.horizontal, .vertical])
        .frame(height: 230)
    }

    var topBar: some View {
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
    }

    var mainView: some View {
        VStack {
            topBar

            chartView
                .asyncStatusOverlay(_curriculum.status, showLight: false)
        }
    }

    var refreshButton: some View {
        Button {
            _curriculum.triggerRefresh()
            updateLectures()
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .font(.caption)
        }
    }

    var flipButton: some View {
        Button {
            withAnimation(.spring) {
                flipped.toggle()
            }
        } label: {
            Label(flipped ? "Chart" : "Settings",
                  systemImage: flipped ? "chart.bar.xaxis" : "gearshape")
                .font(.caption)
        }
    }

    var body: some View {
        ZStack {
            mainView
                .card()
                .flipRotate(flippedDegrees)
                .opacity(flipped ? 0 : 1)

            settingsView
                .card()
                .flipRotate(-180 + flippedDegrees)
                .opacity(flipped ? 1 : 0)
        }
        .onChange(of: currentSemester) { _ in
            updateLectures()
        }
        .onChange(of: _date) { _ in
            updateLectures()
        }
        .onAppear {
            updateLectures()
        }
    }
}

extension View {
    func card() -> some View {
        padding()
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.secondary, lineWidth: 0.2)
            }
    }

    func flipRotate(_ degrees: Double) -> some View {
        rotation3DEffect(
            Angle(degrees: degrees),
            axis: (x: 0.0, y: 1.0, z: 0.0)
        )
    }
}
