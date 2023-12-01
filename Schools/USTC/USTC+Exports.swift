//
//  USTC+Exports.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/9.
//

import SwiftUI

let ustcFeedListURL = URL(
    string: "https://static.xzkd.online/feed_source.json"
)!

let ustcGeoLocationDataURL = URL(
    string: "https://static.xzkd.online/geo_data.json"
)!

class USTCExports: SchoolExport {
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
                name: "Additional Course",
                destinationView: { USTCAdditionalCourseView() }
            ),
        ]
    }

    override var remoteFeedURL: URL { ustcFeedListURL }

    override var examDelegate: ExamDelegateProtocol {
        USTCExamDelegate.shared
    }

    override var curriculumDelegate: CurriculumProtocol {
        USTCCurriculumDelegate.shared
    }

    override var curriculumBehavior: CurriculumBehavior {
        ustcCurriculumBehavior
    }

    override var geoLocationDataURL: URL {
        ustcGeoLocationDataURL
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
        ]
    }
}

extension SchoolExport { static let ustc = USTCExports() }
