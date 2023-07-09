//
//  SharedViews.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/7.
//

import SwiftUI

var SharedScoreView: some View {
    ScoreView(scoreDeleage: USTCScoreDelegate.shared)
}

var SharedExamView: some View {
    ExamView(examDelegate: USTCExamDelegate.shared)
}

var SharedHomeView: some View {
    HomeView(curriculumDelegate: USTCCurriculumDelegate.shared,
             examDelegate: USTCExamDelegate.shared)
}

var SharedCurriculumView: some View {
    CurriculumView(curriculumDelegate: USTCCurriculumDelegate.shared)
}
