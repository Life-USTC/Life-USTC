//
//  ExamView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import SwiftUI

struct ExamView<ExamDelegate: ExamDelegateProtocol>: View {
    @ObservedObject var examDelegate: ExamDelegate
    @State var saveToCalendarStatus: AsyncViewStatus? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            if examDelegate.data.isEmpty {
                VStack {
                    Text("No More Exam!")
                        .font(.system(.body, design: .monospaced))
                        .padding(.vertical, 10)
                }
            } else {
                ForEach(examDelegate.data) { exam in
                    SingleExamView(exam: exam)
                    Divider()
                }
                .padding(.top, 25)
            }
        }
        .padding(.horizontal, 25)
        .asyncViewStatusMask(status: examDelegate.status)
        .refreshable {
            examDelegate.userTriggerRefresh()
        }
        .toolbar {
            Button {
                Task {
                    saveToCalendarStatus = .inProgress
                    do {
                        try await Exam.saveToCalendar(examDelegate.data)
                        saveToCalendarStatus = .success
                    } catch {
                        saveToCalendarStatus = .failure
                    }
                }
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .asyncViewStatusMask(status: saveToCalendarStatus)
            }
        }
        .navigationTitle("Exam")
        .navigationBarTitleDisplayMode(.inline)
    }

    init(examDelegate: ExamDelegate) {
        self.examDelegate = examDelegate
    }
}

struct ExamView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            SingleExamView(exam: .example)
        }
        .listStyle(.inset)
    }
}
