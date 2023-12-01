//
//  ExamDetailView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import SwiftUI

struct ExamDetailView: View {
    @ManagedData(.exam) var exams: [Exam]
    
    var finishedExams: [Exam] {
        exams.filter { $0.isFinished }.sorted { $0.endDate > $1.endDate }
    }
    
    var unfinishedExams: [Exam] {
        exams.filter { !$0.isFinished }.sorted { $0.startDate < $1.startDate }
    }

    @State var saveToCalendarStatus: RefreshAsyncStatus? = nil

    var body: some View {
        List {
            Section {
                if exams.isEmpty {
                    SingleExamView(exam: .example)
                        .redacted(reason: .placeholder)
                        .overlay {
                            Text("No More Exam!")
                                .font(.system(.body, design: .monospaced))
                                .padding(.vertical, 10)
                        }
                } else {
                    ForEach(unfinishedExams) { exam in
                        SingleExamView(exam: exam)
                    }
                    
                    ForEach(finishedExams) { exam in
                        SingleExamView(exam: exam)
                    }
                }
            } header: {
                AsyncStatusLight(status: _exams.status)
            } footer: {
                Text("disclaimer")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.horizontal)
        .refreshable {
            _exams.triggerRefresh()
        }
        .toolbar {
            Button {
                Task {
                    try await $saveToCalendarStatus.exec {
                        try await exams.saveToCalendar()
                    }
                }
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
        }
        .navigationTitle("Exam")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ExamView_Previews: PreviewProvider {
    static var previews: some View {
        ExamDetailView()
    }
}
