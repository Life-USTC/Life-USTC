//
//  CurriculumDetailView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/19.
//

import Charts
import SwiftUI

struct CurriculumDetailView: View {
    @ManagedData(.curriculum) var curriculum: Curriculum
    @State var semester: Semester? = nil
    @State var saveToCalendarStatus: RefreshAsyncStatus? = nil
    @State var _date: Date = .now
    @State var lectures: [Lecture] = []
    @State var currentSemester: Semester?
    @State var weekNumber: Int?
    var heightPerClass = 10;
    
    var date: Date { _date.startOfWeek() }

    var body: some View {
        CurriculumWeekViewVertical(
            lectures: lectures,
            _date: _date,
            currentSemesterName: currentSemester?.name ?? "All".localized,
            weekNumber: weekNumber
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
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .asyncStatusOverlay(_curriculum.status, showLight: false)
        .refreshable {
            _curriculum.triggerRefresh()
        }
        .onChange(of: _curriculum.status) { _ in
            semester = curriculum.semesters.first
        }
        .onAppear {
            semester = curriculum.semesters.first
        }
        .toolbar {
            Button {
                Task {
                    try await $saveToCalendarStatus.exec {
                        try await curriculum.saveToCalendar()
                    }
                }
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
        }
        .navigationTitle("Curriculum").navigationBarTitleDisplayMode(.inline)
        .padding(.horizontal, 20)
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
