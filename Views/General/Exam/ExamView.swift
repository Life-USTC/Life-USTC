//
//  ExamView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import SwiftUI

struct ExamView: View {
    @ManagedData(.exam) var exams: [Exam]

    @State var saveToCalendarStatus: RefreshAsyncStatus? = nil
    var saveButton: some View {
        Button {
            Task {
                try await $saveToCalendarStatus.exec {
                    try await Exam.saveToCalendar(exams)
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.down")
        }
    }

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
                    ForEach(exams, id: \.lessonCode) { exam in
                        SingleExamView(exam: exam)
                        Divider()
                    }
                    .padding(.top, 5)
                }
            } header: {
                AsyncStatusLight(status: _exams.status)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.horizontal)
        .asyncStatusOverlay(_exams.status, showLight: false)
        .refreshable {
            _exams.triggerRefresh()
        }
        .toolbar {
            saveButton
        }
        .navigationTitle("Exam")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ExamView_Previews: PreviewProvider {
    static var previews: some View {
        ExamView()
    }
}
