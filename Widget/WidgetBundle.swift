//
//  ExamWidgetBundle.swift
//  ExamWidget
//
//  Created by TiankaiMa on 2023/1/22.
//

import SwiftUI
import WidgetKit

var sharedSchoolExport: (any SchoolExport)! {
    nil
}

@main
struct ExamWidgetBundle: WidgetBundle {
    var body: some Widget {
        CurriculumWeekWidget()
        CurriculumPreviewWidget()
        ExamWidget()
    }
}
