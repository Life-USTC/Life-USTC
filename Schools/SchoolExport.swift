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

    var localFeedJSOName: String { "" }

    var examDelegate: any ExamDelegateProtocol { USTCExamDelegate.shared }

    var curriculumDelegate: any CurriculumProtocol {
        USTCCurriculumDelegate.shared
    }

    var curriculumBehavior: CurriculumBehavior { CurriculumBehavior() }

    var scoreDelegate: any ScoreDelegateProtocol { USTCScoreDelegate.shared }

    //    var baseModifier: some ViewModifier {
    //        USTCBaseModifier()
    //    }

    var firstLoginView: (Binding<Bool>) -> AnyView {
        { .init(USTCCASLoginView.sheet(isPresented: $0)) }
    }

    var features: [String: [FeatureWithView]] { [:] }
}
