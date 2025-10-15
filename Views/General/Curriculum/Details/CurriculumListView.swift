//
//  CurriculumListView.swift
//  学在科大
//
//  Created by TianKai Ma on 2024/3/11.
//

import Charts
import SwiftUI

struct CurriculumListView: View {
    @ManagedData(.curriculum) var curriculum: Curriculum
    @State var saveToCalendarStatus: RefreshAsyncStatus? = nil

    var dismissAction: (() -> Void)

    var body: some View {
        List {
            ForEach(curriculum.semesters) { semester in
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
        }
        .asyncStatusOverlay(_curriculum.status)
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
                        try await $saveToCalendarStatus.exec {
                            try await curriculum.saveToCalendar()
                        }
                    }
                } label: {
                    Label(
                        "Save to Calendar",
                        systemImage: saveToCalendarStatus == nil
                            ? "calendar.badge.plus" : saveToCalendarStatus!.iconName
                    )
                }

                Button {
                    _curriculum.triggerRefresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .navigationTitle("Curriculum")
        .navigationBarTitleDisplayMode(.inline)
    }
}
