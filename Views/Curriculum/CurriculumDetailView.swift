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
    var todayStart: Date { ProductCalendar.dayStart(referenceDate) }
    var weekStart: Date { todayStart.startOfWeek() }
    var weekEnd: Date { ProductCalendar.weekRange(containing: referenceDate).upperBound }

    var isCurrentWeek: Bool {
        ProductCalendar.weekRange(containing: referenceDate).contains(Date())
    }

    var currentSemester: Semester? {
        let day = ProductCalendar.dayStart(referenceDate)
        return semesters.first { ($0.startDate ... $0.endDate).contains(day) }
            ?? semesters.first {
                ProductCalendar.teachingWeekNumber(
                    containing: referenceDate, semesterStart: $0.startDate, semesterEnd: $0.endDate
                ) != nil
            }
    }

    var weekNumber: Int? {
        guard let currentSemester else { return nil }
        return ProductCalendar.teachingWeekNumber(
            containing: referenceDate,
            semesterStart: currentSemester.startDate, semesterEnd: currentSemester.endDate
        )
    }

    var lectures: [Lecture] {
        lecturesQuery
            .filter {
                ProductCalendar.weekRange(containing: referenceDate).contains($0.startDate)
            }
    }

    @ViewBuilder
    var detailBarView: some View {
        HStack {
            Text(currentSemester?.name ?? "All".localized)

            Spacer()

            if isCurrentWeek {
                if let weekNumber {
                    Text(String(format: "Week %@".localized, String(weekNumber)))
                }
            } else {
                if let weekNumber {
                    Text(String(format: "Week %@ [NOT CURRENT]".localized, String(weekNumber)))
                } else {
                    Text("[NOT CURRENT]")
                }
            }

            Spacer()

            Text(weekStart ... ProductCalendar.addingDays(-1, to: weekEnd))
        }
        .font(.system(.caption2, design: .monospaced, weight: .light))
        .padding(.horizontal, 20)
    }

    var body: some View {
        VStack {
            detailBarView

            if showLandscape {
                CurriculumChartView(
                    lectures: lectures,
                    referenceDate: referenceDate,
                    behavior: SchoolSystem.current.curriculumBehavior,
                )
            } else {
                CurriculumWeekViewVerticalNew(
                    lectures: lectures,
                    referenceDate: referenceDate,
                    hideWeekend: hideWeekend
                )
            }
        }
        .navigationTitle("Curriculum")
        .accountToolbar()
        .task {
            Task {
                try await Curriculum.update()
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !showLandscape {
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
                        try await CalendarSaveHelper.saveCurriculum()
                    }
                } label: {
                    Label("Save to Calendar", systemImage: "calendar.badge.plus")
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
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                .onEnded { value in
                    if abs(value.translation.width) < 20 {  // too small a swipe
                        return
                    }

                    if value.translation.width < 0 {
                        referenceDate = ProductCalendar.addingDays(7, to: referenceDate)
                    } else {
                        referenceDate = ProductCalendar.addingDays(-7, to: referenceDate)
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
        .environment(\.calendar, ProductCalendar.calendar)
        .environment(\.timeZone, ProductCalendar.timeZone)
    }
}
