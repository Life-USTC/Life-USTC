//
//  CurriculumDetailView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/19.
//

import Charts
import SwiftUI

struct CurriculumDetailView: View {
    @AppStorage("HideWeekendinCurriculum") var hideWeekend = true
    @AppStorage(
        "curriculumChartShouldHideEvening",
        store: .appGroup
    ) var curriculumChartShouldHideEvening: Bool = false

    @ManagedData(.curriculum) var curriculum: Curriculum

    @State var showLandscape: Bool = {
        if UIDevice.current.orientation.isFlat {
            return false
        }
        return UIDevice.current.orientation.isLandscape
    }()
    @State var _date: Date = .now
    @State var lectures: [Lecture] = []
    @State var currentSemester: Semester?
    @State var weekNumber: Int?
    var heightPerClass = 10

    var date: Date { _date.startOfWeek() }

    @ViewBuilder
    var detailBarView: some View {
        HStack {
            Text(currentSemester?.name ?? "All".localized)

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

            Text(date ... date.add(day: 6))
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
                    DatePicker(selection: $_date, displayedComponents: .date) {}
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
            ToolbarItemGroup(placement: .primaryAction) {
                if showLandscape {
                    Button {
                        curriculumChartShouldHideEvening.toggle()
                    } label: {
                        Label(
                            "Hide evening",
                            systemImage: curriculumChartShouldHideEvening ? "moon" : "moon.fill"
                        )
                    }
                } else {
                    Button {
                        hideWeekend.toggle()
                    } label: {
                        Label(
                            "Hide weekend",
                            systemImage: hideWeekend
                                ? "distribute.horizontal.center" : "distribute.horizontal.center.fill"
                        )
                    }
                }

                NavigationLink {
                    CurriculumListView()
                } label: {
                    Label("Details", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("Curriculum")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            _curriculum.triggerRefresh()
        }
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
            if newOrientation.isFlat {
#if DEBUG
                showLandscape = false
#else
                return
#endif
            }
            if newOrientation.isLandscape {
                showLandscape = true
            } else {
                showLandscape = false
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
