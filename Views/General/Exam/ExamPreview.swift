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
        AsyncView(delegate: ExamDelegate.shared, showReloadButton: false) { exams in
            if exams.isEmpty {
                return happyView
            } else {
                return makeView(with: exams)
            }
        }
    }

    func makeView(with exams: [Exam]) -> some View {
        VStack {
            ForEach(exams) { exam in
                HStack {
                    VStack(alignment: .leading) {
                        Text(exam.className)
                            .strikethrough(exam.isFinished)
                        Text(exam.classRoomName)
                            .font(.subheadline)
                            .foregroundColor(Color.gray)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(exam.rawTime.split(separator: " ")[0])
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text(exam.rawTime.split(separator: " ")[1])
                            .font(.subheadline)
                    }
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
