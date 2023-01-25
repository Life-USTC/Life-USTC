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
    var body: some View {
        NavigationStack {
            AsyncView { exams in
                List {
                    ForEach(exams) { exam in
                        SingleExamView(exam: exam)
                    }
                }
                .scrollContentBackground(.hidden)
            } loadData: {
                try await UstcUgAASClient.main.getExamInfo()
            } refreshData: {
                try await UstcUgAASClient.main.forceUpdateExamInfo()
                return try await UstcUgAASClient.main.getExamInfo()
            }
            .navigationBarTitle("Exam", displayMode: .inline)
        }
    }
}

struct ExamView_Previews: PreviewProvider {
    static var previews: some View {
        ExamView()
#if os(macOS)
            .frame(width: 400, height: 800)
#endif
    }
}
