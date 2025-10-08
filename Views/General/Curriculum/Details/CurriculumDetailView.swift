//
//  CurriculumDetailView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/19.
//

import Charts
import SwiftUI

struct CurriculumDetailView: View {
    var heightPerClass = 10
    var weekStartDate: Date { _date.startOfWeek() }

    @AppStorage(
        "curriculumChartShouldHideEvening",
        store: .appGroup
    ) var curriculumChartShouldHideEvening: Bool = false
    @AppStorage("HideWeekendinCurriculum") var hideWeekend = true

    @ManagedData(.curriculum) var curriculum: Curriculum

    @State var showLandscape: Bool = {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return false
        }
        return UIDevice.current.orientation.isLandscape
    }()
    @State var _date: Date = .now
    @State var lectures: [Lecture] = []
    @State var currentSemester: Semester?
    @State var weekNumber: Int?

    @ViewBuilder
    var detailBarView: some View {
        HStack {
            Text(currentSemester?.name ?? "All".localized)

            if let weekNumber {
                Spacer()

                if (weekStartDate ... weekStartDate.add(day: 6)).contains(Date().stripTime()) {
                    Text(String(format: "Week %@".localized, String(weekNumber)))
                } else {
                    Text(String(format: "Week %@ [NOT CURRENT]".localized, String(weekNumber)))
                }
            } else if !(weekStartDate ... weekStartDate.add(day: 6)).contains(Date().stripTime()) {
                Spacer()

                Text("[NOT CURRENT]")
            }

            Spacer()

            Text(weekStartDate ... weekStartDate.add(day: 6))
        }
        .font(.system(.caption2, design: .monospaced, weight: .light))
        .padding(.horizontal, 20)
    }

    var body: some View {
        VStack {
            if !showLandscape {
                HStack(alignment: .bottom) {
                    AsyncStatusLight(status: _curriculum.status)
                    Spacer()
                }
                .padding(.horizontal, 20)
            }

            detailBarView

            if showLandscape {
                CurriculumWeekView(
                    lectures: lectures,
                    _date: _date,
                    currentSemesterName: currentSemester?.name ?? "All".localized,
                    weekNumber: weekNumber
                )
                .id(curriculumChartShouldHideEvening)  // so that a forced refresh would happen if the user toggles the setting
            } else {
                CurriculumWeekViewVerticalNew(
                    lectures: lectures,
                    _date: _date,
                    currentSemesterName: currentSemester?.name ?? "All".localized,
                    weekNumber: weekNumber,
                    hideWeekend: hideWeekend
                )
            }
        }
        .asyncStatusOverlay(_curriculum.status)
        .toolbar {
            ToolbarItemGroup(placement: .secondaryAction) {
                Button {
                    _curriculum.triggerRefresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                if showLandscape {
                    Button {
                        curriculumChartShouldHideEvening.toggle()
                    } label: {
                        Label(
                            curriculumChartShouldHideEvening ? "Show evening" : "Hide evening",
                            systemImage: curriculumChartShouldHideEvening ? "moon" : "moon.fill"
                        )
                    }
                } else {
                    Button {
                        hideWeekend.toggle()
                    } label: {
                        Label(
                            hideWeekend ? "Show weekend" : "Hide weekend",
                            systemImage: hideWeekend
                                ? "distribute.horizontal.center" : "distribute.horizontal.center.fill"
                        )
                    }
                }
            }

            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    CurriculumListView()
                } label: {
                    Label("Details", systemImage: "info.circle")
                }
            }

            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    _date = _date.add(day: -7)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                DatePicker("Pick Date", selection: $_date, displayedComponents: .date)
                    .labelsHidden()

                Spacer()

                Button {
                    _date = _date.add(day: 7)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
        }
        .navigationTitle("Curriculum")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            _curriculum.triggerRefresh()
        }
        .highPriorityGesture(
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
        .onRotate { newOrientation in
            if UIDevice.current.userInterfaceIdiom == .pad {
                showLandscape = false
                return
            }

            if newOrientation.isFlat {
                return
            }

            showLandscape = newOrientation.isLandscape
        }
    }

    func updateLecturesAndWeekNumber() {
        lectures =
            (currentSemester == nil
            ? curriculum.semesters.flatMap(\.courses).flatMap(\.lectures)
            : currentSemester!.courses.flatMap(\.lectures))
            .filter {
                (0.0 ..< 3600.0 * 24 * 7)
                    .contains($0.startDate.stripTime().timeIntervalSince(weekStartDate))
            }

        if let currentSemester {
            weekNumber =
                (Calendar(identifier: .gregorian)
                    .dateComponents(
                        [.weekOfYear],
                        from: currentSemester.startDate,
                        to: weekStartDate
                    )
                    .weekOfYear ?? 0) + 1
        } else {
            weekNumber = nil
        }

        if lectures.contains(where: { lecture in
            let weekday = Calendar.current.component(.weekday, from: lecture.startDate)
            return weekday == 7 || weekday == 1  // Saturday (7) or Sunday (1)
        }) {
            hideWeekend = false
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
