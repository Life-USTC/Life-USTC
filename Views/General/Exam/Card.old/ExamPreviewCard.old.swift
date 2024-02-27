//
//  ExamPreviewCard.old.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/28.
//

import SwiftUI

struct ExamPreviewCard_old: View {
    @ManagedData(.exam) var exams: [Exam]

    var body: some View {
        ExamPreview_old(exams: exams)
            .asyncStatusOverlay(_exams.status, text: "Exams", showLight: false)
            .card()
    }
}

#Preview {
    ExamPreviewCard_old()
}
