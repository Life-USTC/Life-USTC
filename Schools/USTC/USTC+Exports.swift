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
    string: "\(staticURLPrefix)/feed_source.json"
)!

let ustcGeoLocationDataURL = URL(
    string: "\(staticURLPrefix)/geo_data.json"
)!

class USTCExports: SchoolExport {
    @AppStorage("ustcStudentType", store: .appGroup) var ustcStudentType: USTCStudentType = .graduate
    @LoginClient(.ustcCAS) var casClient: UstcCasClient

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
        URL(string: "\(staticURLPrefix)/building_img_rules.json")!
    }

    override var buildingimgBaseURL: URL {
        URL(string: "\(staticURLPrefix)/")!
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
                    destinationView: {
                        Browser(
                            url: URL(string: "https://catalog.ustc.edu.cn/query/classroom")!,
                            title: "Classroom Status"
                        )
                    }
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

    override var setCookiesBeforeWebView: ((_ url: URL) async throws -> Void)? {
        return { url in
            // url should start with *.ustc.edu.cn
            guard url.host?.hasSuffix("ustc.edu.cn") == true else {
                return
            }
            _ = try await self._casClient.requireLogin()
        }
    }

    override func reeedEnabledMode(for url: URL) -> ReeedEnabledMode {
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

extension SchoolExport { static let ustc = USTCExports() }
