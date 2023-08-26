//
//  ExamPreview.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import Combine
import SwiftUI

struct ExamView: View {
    var exam: Exam
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(exam.isFinished ? .gray : .red)
                .frame(width: 5)
                .frame(maxHeight: 50)
            VStack(alignment: .leading) {
                Text(exam.courseName)
                    .fontWeight(.bold)
                    .strikethrough(exam.isFinished)
                Text(exam.classRoomName)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(exam.startDate, style: .date)
                    .font(.system(.body, design: .monospaced))
                Text(exam.startDate ... exam.endDate)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ExamPreview: View {
    var exams: [Exam]

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(exams) { exam in
                ExamView(exam: exam)
            }
            if exams.isEmpty {
                ExamView(exam: .example)
                    .redacted(reason: .placeholder)
            }
        }
    }
}
