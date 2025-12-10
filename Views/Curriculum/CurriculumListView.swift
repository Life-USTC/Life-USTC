//
//  CurriculumListView.swift
//  Life@USTC
//
//  Created by TianKai Ma on 2024/3/11.
//

import Charts
import EventKit
import SwiftData
import SwiftUI

struct CurriculumListView: View {
    @Query(sort: \Semester.startDate, order: .reverse) var semesters: [Semester]

    var dismissAction: (() -> Void)

    @ViewBuilder
    func section(for semester: Semester) -> some View {
        Section {
            ForEach(semester.courses, id: \.lessonCode) { course in
                VStack(alignment: .leading) {
                    HStack(alignment: .bottom) {
                        Text(course.name)
                        Text(String(course.credit))
                            .font(.system(.caption, weight: .semibold))
                            .foregroundColor(.secondary)

                        Spacer()
                    }

                    Text(course.lessonCode)
                        .font(.system(.caption2, weight: .light))
                        .foregroundColor(.secondary)

                    if let dateTimePlacePersonText = course.dateTimePlacePersonText,
                        !dateTimePlacePersonText.isEmpty
                    {
                        HStack {
                            Spacer()
                            Text(dateTimePlacePersonText)
                                .font(.system(.caption2, design: .monospaced, weight: .light))
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text(semester.name)

                Spacer()

                HStack(spacing: 0) {
                    Text(semester.startDate, style: .date)
                    Text("~")
                    Text(semester.endDate, style: .date)
                }
                .font(.system(.caption2, design: .monospaced, weight: .light))
            }
        } footer: {
        }
    }

    var body: some View {
        List {
            ForEach(semesters.filter { !$0.courses.isEmpty }, id: \.id) { semester in
                section(for: semester)
            }
        }
        .navigationTitle("Curriculum")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismissAction()
                } label: {
                    Label("Done", systemImage: "xmark")
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

                Button {
                    Task {
                        try await Curriculum.update()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}
