//
//  USTC+Exports.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/9.
//

import SwiftUI

enum USTCStudentType: String {
    case undergraduate = "Undergraduate"
    case graduate = "Graduate"
}

class USTCExports: SchoolExport {
    static let shared = USTCExports()

    @AppStorage(
        "ustcStudentType",
        store: .appGroup
    ) var ustcStudentType: USTCStudentType = .graduate
    @LoginClient(.ustcCAS) var casClient: UstcCasClient

    var abbrName: String { "USTC" }

    var fullName: String {
        "The University of Science and Technology of China"
    }

    var fullChineseName: String { "中国科学技术大学" }

    var commonNames: [String] { ["中科大"] }

    var settings: [SettingWithView] {
        [
            .init(
                name: "CAS Settings",
                destinationView: { USTCCASLoginView() }
            ),
            .init(
                name: "Select Additional Course",
                destinationView: { USTCAdditionalCourseView() }
            ),
        ]
    }

    var remoteFeedURL: URL {
        URL(string: "\(staticURLPrefix)/feed_source.json")!
    }

    var examDelegate: ExamDelegateProtocol {
        USTCExamDelegate.shared
    }

    var curriculumDelegate: CurriculumProtocol {
        if ustcStudentType == .graduate {
            USTCGraduateCurriculumDelegate.shared
        } else {
            USTCUndergraduateCurriculumDelegate.shared
        }
    }

    var curriculumBehavior: CurriculumBehavior {
        ustcCurriculumBehavior
    }

    var geoLocationDataURL: URL {
        URL(string: "\(staticURLPrefix)/geo_data.json")!
    }

    var buildingimgMappingURL: URL {
        URL(string: "\(staticURLPrefix)/building_img_rules.json")!
    }

    var buildingimgBaseURL: URL {
        URL(string: "\(staticURLPrefix)/")!
    }

    var scoreDelegate: ScoreDelegateProtocol {
        USTCScoreDelegate.shared
    }

    var homeworkDelegate: HomeworkDelegateProtocol {
        USTCBBHomeworkDelegate.shared
    }

    var baseModifier = USTCBaseModifier()

    var firstLoginView: (Binding<Bool>) -> AnyView {
        { AnyView(USTCOnboardingCoordinator(isPresented: $0)) }
    }

    var features: [LocalizedStringKey: [FeatureWithView]] {
        [
            "Web": ustcWebFeatures,
            "Meeting Rooms": ustcMeetingRoomFeatures,
            "Public": ustcPublicFeatures,
            "AAS": ustcAASFeatures,
        ]
    }

    var setCookiesBeforeWebView: ((_ url: URL) async throws -> Void)? {
        return { url in
            // hook no longer needed as autofill is app-wide:
            // guard url.host?.hasSuffix("ustc.edu.cn") == true else {
            //     return
            // }
            // _ = try await self._casClient.requireLogin()
        }
    }

    var reeedEnabledMode: ((_: URL) -> ReeedEnabledMode) = { url in
        guard let host = url.host?.lowercased() else {
            return .never
        }

        // Always use reader mode for ustc.edu.cn & (www.)?.teach.ustc.edu.cn:
        if host == "ustc.edu.cn" || host == "www.ustc.edu.cn"
            || host == "teach.ustc.edu.cn" || host == "www.teach.ustc.edu.cn"
        {
            return .always
        }

        // for all other ustc.edu.cn subdomains, .never
        if host.hasSuffix(".ustc.edu.cn") {
            return .never
        }

        // special rule for mp.weixin.qq.com & icourse.club, .never
        if host == "mp.weixin.qq.com" || host == "icourse.club" {
            return .never
        }

        // Default to user choice
        return .userDefined
    }
}
