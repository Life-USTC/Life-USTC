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
        VStack(alignment: .leading, spacing: 8) {
            Text(exam.className)
                .font(.title3)
            Text("\(exam.classIDString) \(exam.typeName)")

            HStack {
                Image(systemName: "calendar.badge.clock")
                Text(exam.time)

                Spacer()
                Text(String(format: "%@ days left".localized, String(exam.daysLeft())))
                    .foregroundColor(exam.daysLeft() <= 7 ? .red : .accentColor)
            }
            .foregroundColor(.accentColor)
            HStack {
                Image(systemName: "location.fill.viewfinder")
                Text("\(exam.classRoomDistrict) \(exam.classRoomBuildingName) \(exam.classRoomName)")
            }
            .foregroundColor(.accentColor)
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
        List {
            SingleExamView(exam: .example)
        }
    }
}
