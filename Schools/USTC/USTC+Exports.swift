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

let ustcFeedListURL = URL(
    string: "https://static.xzkd.online/feed_source.json"
)!

let ustcGeoLocationDataURL = URL(
    string: "https://static.xzkd.online/geo_data.json"
)!

class USTCExports: SchoolExport {
    @AppStorage("ustcStudentType", store: .appGroup) var ustcStudentType: USTCStudentType = .graduate

    override var abbrName: String { "USTC" }

    override var fullName: String {
        "The University of Science and Technology of China"
    }

    override var fullChineseName: String { "中国科学技术大学" }

    override var commonNames: [String] { ["中科大"] }

    override var settings: [SettingWithView] {
        [
            .init(
                name: "CAS Settings",
                destinationView: { USTCCASLoginView.newPage }
            ),
            .init(
                name: "Select Additional Course",
                destinationView: { USTCAdditionalCourseView() }
            ),
        ]
    }

    override var remoteFeedURL: URL { ustcFeedListURL }

    override var examDelegate: ExamDelegateProtocol {
        USTCExamDelegate.shared
    }

    override var curriculumDelegate: CurriculumProtocol {
        if ustcStudentType == .graduate {
            USTCGraduateCurriculumDelegate.shared
        } else {
            USTCUndergraduateCurriculumDelegate.shared
        }
    }

    override var curriculumBehavior: CurriculumBehavior {
        ustcCurriculumBehavior
    }

    override var geoLocationDataURL: URL {
        ustcGeoLocationDataURL
    }

    override var buildingimgMappingURL: URL {
        URL(string: "https://static.xzkd.online/building_img_rules.json")!
    }

    override var buildingimgBaseURL: URL {
        URL(string: "https://static.xzkd.online/")!
    }

    override var scoreDelegate: ScoreDelegateProtocol {
        USTCScoreDelegate.shared
    }

    override var homeworkDelegate: HomeworkDelegateProtocol {
        USTCBBHomeworkDelegate.shared
    }

    //    override var baseModifier: some ViewModifier {
    //        USTCBaseModifier()
    //    }

    override var firstLoginView: (Binding<Bool>) -> any View {
        { USTCCASLoginView.sheet(isPresented: $0) }
    }

    override var features: [String: [FeatureWithView]] {
        if appShouldPresentDemo {
            return [:]
        }
        return [
            "Web": ustcWebFeatures.map { FeatureWithView($0) },
            "Public": [
                .init(
                    image: "doc.text.magnifyingglass",
                    title: "Classroom Status",
                    subTitle: "",
                    destinationView: { USTCClassroomView() }
                ),
                .init(
                    image: "bus",
                    title: "Bus Timetable",
                    subTitle: "",
                    destinationView: { USTC_SchoolBusView() }
                ),
            ],
            "AAS": [
                .init(
                    image: "rectangle.stack",
                    title: "Homework (BB)",
                    subTitle: "",
                    destinationView: { HomeworkDetailView() }
                )
            ],
        ]
    }

    override var setCookiesBeforeWebView: (() async throws -> Void)? {
        return {
            _ = try await UstcCasClient.shared.login()
        }
    }
}

extension SchoolExport { static let ustc = USTCExports() }
