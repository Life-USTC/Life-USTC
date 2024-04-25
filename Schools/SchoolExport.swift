//
//  SchoolExport.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import SwiftUI

class SchoolExport {
    static var shared: SchoolExport { USTCExports() }

    var abbrName: String { "" }

    var fullName: String { "" }

    var fullChineseName: String { "" }

    var commonNames: [String] { [] }

    var settings: [SettingWithView] { [] }

    var remoteFeedURL: URL { exampleURL }

    var examDelegate: ExamDelegateProtocol {
        USTCExamDelegate.shared
    }

    var curriculumDelegate: CurriculumProtocol {
        USTCExports.shared.curriculumDelegate
    }

    var curriculumBehavior: CurriculumBehavior { CurriculumBehavior() }

    var geoLocationDataURL: URL { exampleURL }

    var buildingimgMappingURL: URL { exampleURL }

    var buildingimgBaseURL: URL { exampleURL }

    var scoreDelegate: ScoreDelegateProtocol {
        USTCScoreDelegate.shared
    }

    var homeworkDelegate: HomeworkDelegateProtocol {
        USTCBBHomeworkDelegate.shared
    }

    //    var baseModifier: some ViewModifier {
    //        USTCBaseModifier()
    //    }

    var firstLoginView: (Binding<Bool>) -> any View {
        { USTCCASLoginView.sheet(isPresented: $0) }
    }

    var features: [String: [FeatureWithView]] { [:] }

    var setCookiesBeforeWebView: (() async throws -> Void)? { nil }
}
