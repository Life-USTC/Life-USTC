//
//  CurriculumDetailView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/19.
//

import Charts
import EventKit
import SwiftData
import SwiftUI

struct CurriculumDetailView: View {
    var heightPerClass = 10

    @AppStorage(
        "curriculumChartShouldHideEvening",
        store: .appGroup
    ) var curriculumChartShouldHideEvening: Bool = false
    @AppStorage("HideWeekendinCurriculum") var hideWeekend = true

    @Query(sort: \Semester.startDate, order: .forward) var semesters: [Semester]
    @Query(sort: \Lecture.startDate, order: .forward) var lecturesQuery: [Lecture]

    @State var showLandscape: Bool = {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return false
        }
        return UIDevice.current.orientation.isLandscape
    }()
    @State var showCurriculumDetails = false

    @State var referenceDate: Date = Date()
    var todayStart: Date { referenceDate.stripTime() }
    var weekStart: Date { todayStart.startOfWeek() }
    var weekEnd: Date { weekStart.add(day: 7) }

    var isCurrentWeek: Bool {
        (weekStart ... weekEnd).contains(Date().stripTime())
    }

    var currentSemester: Semester? {
        semesters.filter { ($0.startDate ... $0.endDate).contains(referenceDate) }.first
    }

    var weekNumber: Int? {
        guard let currentSemester else {
            return nil
        }
        return
            (Calendar(identifier: .gregorian)
            .dateComponents(
                [.weekOfYear],
                from: currentSemester.startDate,
                to: weekStart
            )
            .weekOfYear ?? 0) + 1
    }

    var lectures: [Lecture] {
        lecturesQuery
            .filter {
                (weekStart ... weekEnd)
                    .contains($0.startDate.stripTime())
            }
    }

    @ViewBuilder
    var detailBarView: some View {
        HStack {
            Text(currentSemester?.name ?? "All".localized)

            if let weekNumber {
                Spacer()

                if isCurrentWeek {
                    Text(String(format: "Week %@".localized, String(weekNumber)))
                } else {
                    Text(String(format: "Week %@ [NOT CURRENT]".localized, String(weekNumber)))
                }
            } else if !isCurrentWeek {
                Spacer()

                Text("[NOT CURRENT]")
            }

            Spacer()

            Text(weekStart ... weekStart.add(day: 6))
        }
        .font(.system(.caption2, design: .monospaced, weight: .light))
        .padding(.horizontal, 20)
    }

    var body: some View {
        VStack {
            if !showLandscape {
                HStack(alignment: .bottom) {
                    Spacer()
                }
                .padding(.horizontal, 20)
            }

            detailBarView

            if showLandscape {
                CurriculumChartView(
                    lectures: lectures,
                    _date: referenceDate,
                    weekNumber: weekNumber
                )
                .id(curriculumChartShouldHideEvening)
            } else {
                CurriculumWeekViewVerticalNew(
                    lectures: lectures,
                    _date: referenceDate,
                    weekNumber: weekNumber,
                    hideWeekend: hideWeekend
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 50)
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .secondaryAction) {
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

                Button {
                    Task {
                        try await Curriculum.update()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    showCurriculumDetails = true
                } label: {
                    Label("Details", systemImage: "info.circle")
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        try await CalendarSaveHelper.saveCurriculum()
                    }
                } label: {
                    Label("Save to Calendar", systemImage: "calendar.badge.plus")
                }
            }

            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    referenceDate = referenceDate.add(day: -7)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                DatePicker("Pick Date", selection: $referenceDate, displayedComponents: .date)
                    .labelsHidden()

                Spacer()

                Button {
                    referenceDate = referenceDate.add(day: 7)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
        }
        .navigationTitle("Curriculum")
        .refreshable {
            Task {
                try await Curriculum.update()
            }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                .onEnded { value in
                    if abs(value.translation.width) < 20 {
                        // too small a swipe
                        return
                    }

                    if value.translation.width < 0 {
                        referenceDate = referenceDate.add(day: 7)
                    } else {
                        referenceDate = referenceDate.add(day: -7)
                    }
                }
        )
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
        .sheet(isPresented: $showCurriculumDetails) {
            NavigationStack {
                CurriculumListView(
                    dismissAction: {
                        showCurriculumDetails = false
                    }
                )
            }
        }
        .task {
            Task {
                try await Curriculum.update()
            }
        }
    }
}
