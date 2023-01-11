//
//  ExamView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import SwiftUI

private struct SingleExamView: View {
    var exam: Exam
    @State var fold = true

    var body: some View {
        Section {
            Group {
                HStack {
                    Text("Class Name")
                    Spacer()
                    Text(exam.className)
                }
                HStack {
                    Text("Time")
                    Spacer()
                    Text(exam.time)
                }
                HStack {
                    Text("Classroom")
                    Spacer()
                    Text(exam.classRoomName)
                }
            }
            .fontWeight(.bold)
            if fold == false {
                Group {
                    HStack {
                        Text("Class ID")
                        Spacer()
                        Text(exam.classIDString)
                    }
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(exam.typeName)
                    }

                    HStack {
                        Text("Building")
                        Spacer()
                        Text(exam.classRoomBuildingName)
                    }
                    HStack {
                        Text("Campus")
                        Spacer()
                        Text(exam.classRoomDistrict)
                    }
                    if !exam.description.isEmpty {
                        HStack {
                            Text("Description")
                            Spacer()
                            Text(exam.description)
                        }
                    }
                }
                .fontWeight(.light)
            }
            Button {
                withAnimation {
                    fold.toggle()
                }
            } label: {
                Text(fold ? "More" : "Less")
            }
        }
    }
}

struct ExamView: View {
    @State var exams: [Exam] = []
    @State var status: AsyncViewStatus = .inProgress

    var body: some View {
        NavigationStack {
            List {
                ForEach(exams) { exam in
                    SingleExamView(exam: exam)
                }
            }
            .navigationTitle("Exam")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                asyncBind($exams, status: $status) {
                    try await UstcUgAASClient.main.getExamInfo()
                }
            }
        }
    }
}
