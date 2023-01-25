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
            if exams.isEmpty {
                return happyView
            } else {
                return makeView(with: exams)
            }
        } loadData: {
            try await UstcUgAASClient.main.getExamInfo()
        }
    }

    func makeView(with exams: [Exam]) -> some View {
        VStack {
            ForEach(exams) { exam in
                HStack {
                    TitleAndSubTitle(title: exam.className, subTitle: exam.classRoomName, style: .substring)
                    Spacer()
                    Text(exam.time)
                }
                Divider()
            }
        }
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
