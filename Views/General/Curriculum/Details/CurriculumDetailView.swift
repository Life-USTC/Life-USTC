//
//  CurriculumDetailView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/19.
//

import Charts
import SwiftUI

struct CurriculumDetailView: View {
    @AppStorage("CurriculumDetailViewUseUI_v2") var useNewUI = true
    @ManagedData(.curriculum) var curriculum: Curriculum
    @State var semester: Semester? = nil
    @State var saveToCalendarStatus: RefreshAsyncStatus? = nil
    @State var showLandscape: Bool = false
    @State var _date: Date = .now
    @State var lectures: [Lecture] = []
    @State var currentSemester: Semester?
    @State var weekNumber: Int?
    var heightPerClass = 10

    var date: Date { _date.startOfWeek() }

    var normalView: some View {
        GeometryReader { geo in
            ScrollView {
                VStack {
                    HStack(alignment: .bottom) {
                        AsyncStatusLight(status: _curriculum.status)
                        Spacer()
                        DatePicker(selection: $_date, displayedComponents: .date) {}
                    }
                    .padding(.horizontal, 20)
                    
                    HStack {
                        Text(date ... date.add(day: 6))
                        
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

                        Text(currentSemester?.name ?? "All".localized)
                    }
                    .font(.system(.caption2, design: .monospaced, weight: .light))
                    .padding(.horizontal, 20)

                    if useNewUI {
                        CurriculumWeekViewVerticalNew(
                            lectures: lectures,
                            _date: _date,
                            currentSemesterName: currentSemester?.name ?? "All".localized,
                            weekNumber: weekNumber
                        )
                    } else {
                        CurriculumWeekViewVertical(
                            lectures: lectures,
                            _date: _date,
                            currentSemesterName: currentSemester?.name ?? "All".localized,
                            weekNumber: weekNumber
                        )
                        .padding(.horizontal, 20)
                    }
                }
                .frame(
                    minWidth: geo.size.width,
                    minHeight: geo.size.height
                )
            }
        }
        .refreshable {
            _curriculum.triggerRefresh()
        }
        .asyncStatusOverlay(_curriculum.status, showLight: false)
    }

    var landscapeView: some View {
        CurriculumWeekView(
            lectures: lectures,
            _date: _date,
            currentSemesterName: currentSemester?.name ?? "All".localized,
            weekNumber: weekNumber
        )
        .asyncStatusOverlay(_curriculum.status)
    }

    var body: some View {
        Group {
            if showLandscape {
                landscapeView
            } else {
                normalView
            }
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
        .onChange(of: _curriculum.status) { _ in
            semester = curriculum.semesters.first
        }
        .onAppear {
            semester = curriculum.semesters.first
            updateLecturesAndWeekNumber()
            updateSemester()
        }
        .onRotate { newOrientation in
            if newOrientation.isLandscape {
                showLandscape = true
            } else {
                showLandscape = false
            }
        }
        .onDisappear {
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        try await $saveToCalendarStatus.exec {
                            try await curriculum.saveToCalendar()
                        }
                    }
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }

                Button {
                    showLandscape.toggle()
                    let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                    windowScene?
                        .requestGeometryUpdate(.iOS(interfaceOrientations: showLandscape ? .landscapeRight : .portrait))
                } label: {
                    Label("Flip", systemImage: showLandscape ? "rectangle.grid.2x2" : "rectangle.grid.1x2.fill")
                }
            }
        }
        .navigationTitle("Curriculum")
        .navigationBarTitleDisplayMode(.inline)
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
