//
//  ExamDetailView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import SwiftData
import SwiftUI

struct ExamDetailView: View {
    @Query(sort: \Exam.startDate, order: .forward) var _exams: [Exam]

    var exams: [Exam] {
        _exams.staged()
    }

    var body: some View {
        List {
            Section {
                if exams.isEmpty {
                    ContentUnavailableView(
                        "No More Exam!",
                        systemImage: "calendar.badge.checkmark"
                    )
                } else {
                    ForEach(exams) { exam in
                        ExamCardView(exam: exam)
                    }
                }
            } header: {
                EmptyView()
            } footer: {
                Text("disclaimer")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Exam")
        .task {
            Task {
                try await Exam.update()
            }
        }
        .refreshable {
            Task {
                try await Exam.update()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        try? await CalendarSaveHelper.saveExams()
                    }
                } label: {
                    Label("Save to Calendar", systemImage: "calendar.badge.plus")
                }

                Button {
                    Task {
                        try await Exam.update()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}
