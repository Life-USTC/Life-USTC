//
//  ExamPreview.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import SwiftUI

struct ExamPreview: View {
    var body: some View {
        AsyncView { exams in
            makeView(with: exams)
        } loadData: {
            try await UstcUgAASClient.main.getExamInfo()
        }
    }

    func makeView(with exams: [Exam]) -> some View {
        List {
            ForEach(exams) { exam in
                HStack {
                    TitleAndSubTitle(title: exam.className, subTitle: exam.classRoomName, style: .substring)
                    Spacer()
                    Text(exam.time)
                }
            }
        }
        .listStyle(.plain)
        .frame(height: cardHeight / 3 * Double(exams.count))
    }

    var happyView: some View {
        VStack {
            Image(systemName: "signature")
                .foregroundColor(.accentColor)
                .font(.system(size: 40))
            Text("No more exam!")
        }
    }
}
