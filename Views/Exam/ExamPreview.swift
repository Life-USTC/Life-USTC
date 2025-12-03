//
//  ExamPreviewView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import SwiftUI

struct ExamPreview: View {
    var exams: [Exam] = []
    var color: Color = .blue

    @ViewBuilder
    var noExamView: some View {
        ZStack {
            // ExamView(exam: .example)
            //     .redacted(reason: .placeholder)

            VStack {
                Text("No More Exam!")
                    .lineLimit(1)
                    .font(.system(.body, weight: .semibold))

                Text("Enjoy!")
                    .lineLimit(1)
                    .font(.caption)
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(exams) { exam in
                ExamView(exam: exam, color: color)
            }

            if exams.isEmpty {
                noExamView
            }
        }
    }
}
