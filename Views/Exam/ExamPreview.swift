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

    var body: some View {
        VStack(spacing: 10) {
            if exams.isEmpty {
                ContentUnavailableView(
                    "No More Exam!",
                    systemImage: "calendar.badge.checkmark",
                    description: Text("Enjoy!")
                )
            } else {
                ForEach(exams) { exam in
                    ExamView(exam: exam, color: color)
                }
            }
        }
    }
}
