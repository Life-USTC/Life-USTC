//
//  ExamView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import SwiftUI

struct ExamView: View {
    @ManagedData(\.exam) var exams: [Exam]!
    @State var status: AsyncStatus?

    var body: some View {
        ScrollView(showsIndicators: false) {
            if exams.isEmpty {
                VStack {
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
            EmptyView()
        }
        .toolbar {
            saveButton
        }
        .asyncStatusMask(status: status)
        .refreshable {
            _exams.userTriggeredRefresh()
        }
        .onReceive(_exams.$status, perform: {
            status = $0
        })
        .padding(.horizontal)
        .navigationTitle("Exam")
        .navigationBarTitleDisplayMode(.inline)
    }

    @State var saveToCalendarStatus: RefreshAsyncStatus? = nil

    var saveButton: some View {
        Button {
            Task {
                try await saveToCalendarStatus.exec {
                    try await Exam.saveToCalendar(exams)
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.down")
                .asyncStatusMask(status: .init(local: status?.local,
                                               refresh: saveToCalendarStatus))
        }
    }
}

struct ExamView_Previews: PreviewProvider {
    static var previews: some View {
        ExamView()
    }
}
