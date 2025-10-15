//
//  ExamDetailView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import SwiftUI

struct ExamDetailView: View {
    @ManagedData(.exam) var exams: [Exam]

    @StateObject var saveToCalendar = RefreshAsyncStatusUpdateObject {}

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
                    ForEach(exams.clean()) { exam in
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
        .asyncStatusOverlay(_exams.status)
        .padding(.horizontal)
        .refreshable {
            _exams.triggerRefresh()
        }
        .onAppear {
            saveToCalendar.action = {
                try await self.exams.saveToCalendar()
            }
        }
        .toolbar {
            Button {
                Task {
                    await self.saveToCalendar.exec()
                }
            } label: {
                Label(
                    "Save to calendar",
                    systemImage: {
                        switch saveToCalendar.status {
                        case .none: return "square.and.arrow.down"
                        case .waiting: return "arrow.clockwise"
                        case .success: return "checkmark"
                        case .error: return "exclamationmark.triangle"
                        }
                    }()
                )
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
