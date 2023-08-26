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
        ExamPreview(exams: exams)
            .asyncStatusOverlay(_exams.status, text: "Exams") {
                Button {
                    _exams.triggerRefresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
            }
            .card()
    }
}