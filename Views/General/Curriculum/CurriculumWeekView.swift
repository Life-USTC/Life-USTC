//
//  CurriculumWeekView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/20.
//

import Charts
import SwiftUI

@available(iOS 17.0, *) struct CurriculumWeekView: View {
    @ManagedData(.curriculum) var curriculum: Curriculum

    @State var currentSemester: Semester?
    @State var flipped = false
    @State var _date: Date = .init()
    @State var lectures: [Lecture] = []

    var date: Date { _date.startOfWeek() }
    var flippedDegrees: Double { flipped ? 180 : 0 }
    var behavior: CurriculumBehavior { SchoolExport.shared.curriculumBehavior }

    func updateLectures() {
        lectures =
            (currentSemester == nil
            ? curriculum.semesters.flatMap { $0.courses.flatMap(\.lectures) }
            : currentSemester!.courses.flatMap(\.lectures))
            .filter {
                (0.0 ..< 3600.0 * 24 * 7)
                    .contains($0.startDate.stripTime().timeIntervalSince(date))
            }
    }

    var mergedTimes: [Int] {
        (behavior.shownTimes + behavior.highLightTimes).sorted()
    }

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
                        Button(semester.name) { currentSemester = semester }
                    }
                    Button("All") { currentSemester = nil }
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
                AxisValueLabel(anchor: .topTrailing) {
                    Text("Now").foregroundColor(.red)
                }
                AxisGridLine().foregroundStyle(.red)
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
                    AxisGridLine(stroke: .init(dash: [])).foregroundStyle(.blue)
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
        .chartYVisibleDomain(length: 3600 * 24 * 7)
        .chartYScale(domain: date ... date.add(day: 7)).frame(height: 230)
    }

    var topBar: some View {
        HStack {
            Text("Curriculum").font(.caption).fontWeight(.bold)
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
                .if(lectures.isEmpty) {
                    $0
                        .redacted(reason: .placeholder)
                        .blur(radius: 2)
                        .overlay {
                            Text("No Lectures for this week")
                                .font(.system(.title2, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                }
        }
    }

    var refreshButton: some View {
        Button {
            _curriculum.triggerRefresh()
            updateLectures()
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise").font(.caption)
        }
    }

    var flipButton: some View {
        Button {
            withAnimation(.spring) { flipped.toggle() }
        } label: {
            Label(
                flipped ? "Chart" : "Settings",
                systemImage: flipped ? "chart.bar.xaxis" : "gearshape"
            )
            .font(.caption)
        }
    }

    var body: some View {
        ZStack {
            mainView.card()
                .flipRotate(flippedDegrees)
                .opacity(flipped ? 0 : 1)

            settingsView.card()
                .flipRotate(-180 + flippedDegrees)
                .opacity(flipped ? 1 : 0)
        }
        .onChange(of: currentSemester) { _ in updateLectures() }
        .onChange(of: curriculum) { _ in updateLectures() }
        .onChange(of: _date) { _ in updateLectures() }
        .onAppear { updateLectures() }
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
