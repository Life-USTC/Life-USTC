//
//  CurriculumWeekCard.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/25.
//

import SwiftUI

struct CurriculumWeekCard: View {
    @ManagedData(.curriculum) var curriculum: Curriculum

    @State var currentSemester: Semester?
    @State var flipped = false
    @State var _date: Date = .now
    @State var lectures: [Lecture] = []
    @State var weekNumber: Int?

    var date: Date { _date.startOfWeek() }

    var body: some View {
        FlipableCard(flipped: $flipped) {
            mainView
        } settingsView: {
            settingsView
        }
        .onChange(of: currentSemester) {
            _ in updateLecturesAndWeekNumber()
        }
        .onChange(of: curriculum) { _ in
            updateLecturesAndWeekNumber()
            updateSemester()
        }
        .onChange(of: _date) { _ in
            updateLecturesAndWeekNumber()
            updateSemester()
        }
        .onAppear {
            updateLecturesAndWeekNumber()
            updateSemester()
        }
    }
}

extension CurriculumWeekCard {
    var refreshButton: some View {
        Button {
            _curriculum.triggerRefresh()
            updateLecturesAndWeekNumber()
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
            Label(
                flipped ? "Chart" : "Settings",
                systemImage: flipped ? "chart.bar.xaxis" : "gearshape"
            )
            .font(.caption)
        }
    }

    var mainView: some View {
        CurriculumWeekView(
            lectures: lectures,
            _date: _date,
            currentSemesterName: currentSemester?.name ?? "All".localized,
            weekNumber: weekNumber
        )
        .frame(height: 230)
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                .onEnded { value in
                    if abs(value.translation.width) < 20 {
                        // too small a swipe
                        return
                    }

                    if value.translation.width < 0 {
                        _date = _date.add(day: 7)
                    } else {
                        _date = _date.add(day: -7)
                    }
                }
        )
        .asyncStatusOverlay(
            _curriculum.status,
            text: "Curriculum",
            showLight: false,
            showToolbar: true
        ) {
            flipButton
        }
    }

    var settingsView: some View {
        VStack(alignment: .leading) {
            Spacer()
                .frame(height: 20)

            DatePicker(selection: $_date, displayedComponents: .date) {
                VStack(alignment: .leading) {
                    Text("Date")

                    Text("You can also swipe left/right to switch weeks")
                        .font(.system(.caption, weight: .light))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading) {
                    Text("Semester")

                    Text(
                        "Semester selection is automatically updated based on current date"
                    )
                    .font(.system(.caption, weight: .light))
                    .foregroundColor(.secondary)
                }

                Spacer()

                Menu {
                    ForEach(curriculum.semesters) { semester in
                        Button(semester.name) {
                            currentSemester = semester
                        }
                    }
                    Button("All") { currentSemester = nil }
                } label: {
                    Text(currentSemester?.name ?? "All".localized)
                }
            }

            Divider()

            Spacer()
        }
        .asyncStatusOverlay(
            _curriculum.status,
            text: "Curriculum",
            showLight: true,
            showToolbar: true
        ) {
            HStack {
                refreshButton
                flipButton
            }
        }
    }

    func updateLecturesAndWeekNumber() {
        lectures =
            (currentSemester == nil
            ? curriculum.semesters.flatMap(\.courses).flatMap(\.lectures)
            : currentSemester!.courses.flatMap(\.lectures))
            .filter {
                (0.0 ..< 3600.0 * 24 * 7)
                    .contains($0.startDate.stripTime().timeIntervalSince(date))
            }

        if let currentSemester {
            weekNumber =
                (Calendar(identifier: .gregorian)
                    .dateComponents(
                        [.weekOfYear],
                        from: currentSemester.startDate,
                        to: date
                    )
                    .weekOfYear ?? 0) + 1
        } else {
            weekNumber = nil
        }
    }

    func updateSemester() {
        currentSemester =
            curriculum.semesters
            .filter {
                ($0.startDate ... $0.endDate).contains(_date)
            }
            .first
    }
}
