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

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Semester")
                    Spacer()
                    Menu {
                        ForEach(curriculum.semesters) { semester in
                            Button {
                                self.semester = semester
                            } label: {
                                Text(semester.name)
                            }
                        }
                    } label: {
                        Text(semester?.name ?? "Choose")
                    }
                }
            } header: {
                AsyncStatusLight(status: _curriculum.status)
            }

            if let semester {
                Section(header: Text(semester.name)) {
                    VStack(alignment: .leading) {
                        Text("Credits")
                            .font(
                                .system(
                                    .caption,
                                    design: .monospaced,
                                    weight: .semibold
                                )
                            )
                            .foregroundColor(.accentColor)
                        if #available(iOS 17, *) {
                            Chart {
                                ForEach(semester.courses) { course in
                                    SectorMark(
                                        angle: .value("Credit", course.credit),
                                        innerRadius: .ratio(0.65),
                                        angularInset: 2.0
                                    )
                                    .foregroundStyle(
                                        by: .value(
                                            "Name",
                                            course.name.truncated()
                                        )
                                    )
                                }
                            }
                            .chartScrollableAxes(.horizontal)
                            .chartLegend(position: .trailing)
                        }

                        HStack(alignment: .top) {
                            Image(systemName: "calendar.badge.clock")
                            Spacer()
                            Text(semester.startDate, style: .date)
                            Text("~")
                            Text(semester.endDate, style: .date)
                        }
                        .font(
                            .system(
                                .callout,
                                design: .monospaced,
                                weight: .bold
                            )
                        )
                        .foregroundColor(.secondary)
                        .padding(.vertical)
                    }

                    ForEach(semester.courses, id: \.lessonCode) { course in
                        HStack {
                            Text(course.name)
                            Text(String(course.credit))
                                .font(.system(.caption, weight: .semibold))
                                .foregroundColor(.secondary)

                            Spacer()

                            Text(course.description)
                                .lineLimit(2)
                                .font(.system(.caption2, weight: .light))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
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
    }
}
