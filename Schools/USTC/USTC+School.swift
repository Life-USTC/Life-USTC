import SwiftUI

enum USTCSchool {
    @AppStorage("ustcStudentType", store: .appGroup) static var studentType: USTCStudentType = .graduate
    static func make() -> School {
        return School(
            abbrName: "USTC",
            fullName: "The University of Science and Technology of China",
            fullChineseName: "中国科学技术大学",
            commonNames: ["中科大"],
            settings: [
                .init(name: "CAS Settings", destinationView: { USTCCASLoginView() }),
                .init(name: "Select Additional Course", destinationView: { USTCAdditionalCourseView() }),
            ],
            remoteFeedURL: URL(string: "\(staticURLPrefix)/feed_source.json")!,
            examFetch: { try await USTCExamDelegate.shared.refresh() },
            curriculumFetch: {
                guard studentType == .graduate else {
                    return try await USTCUndergraduateCurriculumDelegate.shared.refresh()
                }
                return try await USTCGraduateCurriculumDelegate.shared.refresh()
            },
            curriculumBehavior: USTCExports().ustcCurriculumBehavior,
            geoLocationDataURL: URL(string: "\(staticURLPrefix)/geo_data.json")!,
            buildingimgMappingURL: URL(string: "\(staticURLPrefix)/building_img_rules.json")!,
            buildingimgBaseURL: URL(string: "\(staticURLPrefix)/")!,
            scoreFetch: { try await USTCScoreDelegate.shared.refresh() },
            homeworkFetch: { try await USTCBBHomeworkDelegate.shared.refresh() },
            firstLoginView: { AnyView(USTCOnboardingCoordinator(isPresented: $0)) },
            features: [
                "Web": USTCExports().ustcWebFeatures,
                "Meeting Rooms": USTCExports().ustcMeetingRoomFeatures,
                "Public": USTCExports().ustcPublicFeatures,
                "AAS": USTCExports().ustcAASFeatures,
            ],
            setCookiesBeforeWebView: { _ in },
            reeedEnabledMode: USTCExports().reeedEnabledMode
        )
    }
}
