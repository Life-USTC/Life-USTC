import SwiftUI

enum USTCStudentType: String {
    case undergraduate = "Undergraduate"
    case graduate = "Graduate"
}

enum USTCSchool {
    static func make() -> School {
        return School(
            abbrName: "USTC",
            fullName: "The University of Science and Technology of China",
            fullChineseName: "中国科学技术大学",
            commonNames: ["中科大"],

            remoteFeedURL: URL(string: "\(Constants.staticURLPrefix)/feed_source.json")!,
            geoLocationURL: URL(string: "\(Constants.staticURLPrefix)/geo_data.json")!,
            buildingimgBaseURL: URL(string: "\(Constants.staticURLPrefix)/")!,
            buildingimgMappingURL: URL(string: "\(Constants.staticURLPrefix)/building_img_rules.json")!,

            curriculumBehavior: ustcCurriculumBehavior,

            updateCurriculum: updateCurriculum,
            updateExam: updateExam,
            updateScore: updateScore,
            updateHomework: updateHomework,

            firstLoginView: { AnyView(USTCOnboardingView(isPresented: $0)) },
            settings: [
                .init(name: "CAS Settings", destinationView: { USTCCASLoginView() }),
                .init(name: "Select Additional Course", destinationView: { USTCAdditionalCourseView() }),
            ],
            features: ustcFeatures,

            setCookiesBeforeWebView: { _ in },
            reeedEnabledMode: { url in
                guard let host = url.host?.lowercased() else {
                    return .never
                }

                if host.hasSuffix("ustc.edu.cn") {
                    if host == "ustc.edu.cn"
                        || host == "www.ustc.edu.cn"
                        || host == "teach.ustc.edu.cn"
                        || host == "www.teach.ustc.edu.cn"
                    {
                        return .always
                    }

                    return .never
                }

                if host == "mp.weixin.qq.com" || host == "icourse.club" {
                    return .never
                }
                return .userDefined
            }
        )
    }
}
