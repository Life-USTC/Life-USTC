//
//  ExamPreview.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import SwiftUI

struct ExamPreview: View {
    @State var exams: [Exam] = []
    @State var status: AsyncViewStatus = .inProgress

    var body: some View {
        Group {
            if status == .inProgress {
                ProgressView()
            } else {
                if exams.isEmpty {
                    happyView
                } else {
                    mainView
                }
            }
        }
        .frame(width: cardWidth)
        .onAppear {
            asyncBind($exams, status: $status) {
                try await UstcUgAASClient.main.getExamInfo()
            }
        }
    }

    var mainView: some View {
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
