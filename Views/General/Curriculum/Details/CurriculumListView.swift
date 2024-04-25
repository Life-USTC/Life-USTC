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

                            if let description = course.description {
                                Text(description)
                                    .font(.system(.caption2, weight: .light))
                                    .foregroundColor(.secondary)
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
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundColor(.secondary)
                    }
                } footer: {
                    Spacer()
                }
            }
        }
        .listStyle(.grouped)
        .scrollContentBackground(.hidden)
        .asyncStatusOverlay(_curriculum.status)
        .refreshable {
            _curriculum.triggerRefresh()
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
        .navigationTitle("Curriculum")
        .navigationBarTitleDisplayMode(.inline)
    }
}
