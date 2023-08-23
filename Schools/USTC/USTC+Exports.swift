//
//  USTC+Exports.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/9.
//

import SwiftUI

class USTCExports: SchoolExport {
    override var abbrName: String {
        "USTC"
    }

    override var fullName: String {
        "The University of Science and Technology of China"
    }

    override var fullChineseName: String {
        "中国科学技术大学"
    }

    override var commonNames: [String] {
        ["中科大"]
    }

    override var settings: [SettingWithView] {
        [
            .init(name: "CAS Settings",
                  destinationView: .init(USTCCASLoginView.newPage)),
        ]
    }

    override var feedURLs: [URL] {
        [
            ustcHomePageFeedURL,
            ustcOAAFeedURL,
            mp_ustc_sgy_URL,
            mp_ustc_official_URL,
            mp_ustc_graduate_student_union_URL,
            mp_ustc_youth_league_committee_URL,
            mp_ustc_undergraduate_student_union_URL,
            mp_ustc_undergraduate_admission_office_URL,
        ]
    }

    override var remoteFeedURL: URL {
        ustcFeedListURL
    }

    override var localFeedJSOName: String {
        "ustc_feed_source"
    }

    override var examDelegate: any ExamDelegateProtocol {
        USTCExamDelegate.shared
    }

    override var curriculumDelegate: any CurriculumProtocol {
        USTCCurriculumDelegate.shared
    }

    override var curriculumBehavior: CurriculumBehavior {
        ustcCurriculumBehavior
    }

    override var scoreDelegate: any ScoreDelegateProtocol {
        USTCScoreDelegate.shared
    }

//    override var baseModifier: some ViewModifier {
//        USTCBaseModifier()
//    }

    override var firstLoginView: (Binding<Bool>) -> AnyView {
        { .init(USTCCASLoginView.sheet(isPresented: $0)) }
    }

    override var features: [String: [FeatureWithView]] {
        [
            "Web": ustcWebFeatures.map { FeatureWithView($0) },
            "Public": [.init(image: "doc.text.magnifyingglass",
                             title: "Classroom Status".localized,
                             subTitle: "",
                             destinationView: USTCClassroomView())],
        ]
    }
}

extension SchoolExport {
    static var ustc = USTCExports()
}

struct USTCBaseModifier: ViewModifier {
    @LoginClient(.ustcCAS) var casClient: UstcCasClient
    @LoginClient(.ustcUgAAS) var ugAASClient: UstcUgAASClient

    @State var casLoginSheet: Bool = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $casLoginSheet) {
                USTCCASLoginView.sheet(isPresented: $casLoginSheet)
            }
            .onAppear(perform: onLoadFunction)
    }

    func onLoadFunction() {
        Task {
            _casClient.clearLoginStatus()
            _ugAASClient.clearLoginStatus()

            if casClient.precheckFails {
                casLoginSheet = true
                return
            }
            // if the login result fails, present the user with the sheet.
            casLoginSheet = try await !_casClient.requireLogin()
        }
    }
}
