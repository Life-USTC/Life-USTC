//
//  ExamPreviewCard.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/26.
//

import SwiftData
import SwiftUI

struct ExamPreviewCard: View {
    @Query(sort: \Exam.startDate, order: .forward) var exams: [Exam]

    var body: some View {
        VStack {
            HStack {
                Text("Exams")
                    .font(.system(.title2, weight: .medium))
                Spacer()
            }
            ExamPreview(exams: exams)
        }
        .card()
        .task { await refresh() }
    }

    private func refresh() async {
        try? await ExamRepository.refresh()
    }
}
