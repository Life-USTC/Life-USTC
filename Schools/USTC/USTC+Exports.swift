//
//  USTC+Exports.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/9.
//

import SwiftUI

enum USTCExports {
    // MARK: - Information about the school

    static var abbrName = "USTC"
    static var fullName = "The University of Science and Technology of China"
    static var fullChineseName = "中国科学技术大学"
    static var commonNames: [String] = ["中科大"]

    // MARK: - Available Views

    static var settings: [SettingWithView] {
        [
            .init(name: "CAS Settings",
                  destinationView: .init(USTCCASLoginView.newPage)),
        ]
    }

    static var feedURLs: [URL] {
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

    static var remoteFeedURL: URL {
        ustcFeedListURL
    }

    static var localFeedJSOName: String {
        "ustc_feed_source"
    }

    static var examDelegate: some ExamDelegateProtocol {
        USTCExamDelegate.shared
    }

    static var curriculumDelegate: some CurriculumDelegateProtocol {
        USTCCurriculumDelegate.shared
    }

    static var scoreDelegate: some ScoreDelegateProtocol {
        USTCScoreDelegate.shared
    }

    static var baseModifier: some ViewModifier {
        USTCBaseModifier()
    }

    static var firstLoginView: (Binding<Bool>) -> AnyView {
        { firstLogin in
            .init(USTCCASLoginView.sheet(isPresented: firstLogin))
        }
    }

    static var semesterIDList: [Int: String] {
        UstcUgAASClient.semesterIDList
    }
}

struct USTCBaseModifier: ViewModifier {
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
            UstcCasClient.shared.clearLoginStatus()
            UstcUgAASClient.shared.clearLoginStatus()
            UstcQCKDClient.shared.clearLoginStatus()

            if UstcCasClient.shared.precheckFails {
                casLoginSheet = true
            }
            // if the login result fails, present the user with the sheet.
            casLoginSheet = try await !UstcCasClient.shared.requireLogin()
        }
    }
}
