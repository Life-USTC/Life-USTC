//
//  ExamPreviewCard.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/26.
//

import SwiftUI

struct ExamPreviewCard: View {
    @ManagedData(.exam) var exams: [Exam]

    var body: some View {
        VStack {
            HStack {
                Text("Exams")
                    .font(.system(.title2, weight: .medium))
                Spacer()
            }
            ExamPreview(exams: exams)
                .asyncStatusOverlay(_exams.status)
        }
        .card()
    }
}
