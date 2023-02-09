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
        VStack(alignment: .leading, spacing: 25) {
            VStack (alignment: .leading){
                HStack (alignment: .center){
                    Text("\(exam.className)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(exam.typeName)")
                        .foregroundColor(Color.gray)
                        .font(.subheadline)
                        
                }
                Text("\(exam.classIDString)")
                    .foregroundColor(Color.gray)
                    .font(.subheadline)
            }
            VStack (alignment: .leading, spacing: 3) {
                HStack {
                    Image(systemName: "location.fill.viewfinder")
                    Text("\(exam.classRoomDistrict) \(exam.classRoomBuildingName) \(exam.classRoomName)")
                }
                .font(.callout)
                HStack {
                    Image(systemName: "calendar.badge.clock")
                    Text(exam.time)
                    Spacer()
                    Text(String(format: "%@ days left".localized, String(exam.daysLeft())))
                        .foregroundColor(exam.daysLeft() <= 7 ? .red : .accentColor)
                        .fontWeight(.bold)
                }
                .font(.callout)
            }
        }
        .padding(.vertical, 5)
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
                .listStyle(.plain)
                .padding(5)
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
        .listStyle(.inset)

    }
}
