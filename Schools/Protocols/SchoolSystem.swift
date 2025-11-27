import SwiftUI

enum ReeedEnabledMode {
    case always
    case userDefined
    case never
}

struct School {
    let abbrName: String
    let fullName: String
    let fullChineseName: String
    let commonNames: [String]

    let settings: [SettingWithView]

    let remoteFeedURL: URL

    let examFetch: () async throws -> [Exam]
    let curriculumFetch: () async throws -> Curriculum
    let curriculumBehavior: CurriculumBehavior

    let geoLocationDataURL: URL
    let buildingimgMappingURL: URL
    let buildingimgBaseURL: URL

    let scoreFetch: () async throws -> Score
    let homeworkFetch: () async throws -> [Homework]

    let firstLoginView: (Binding<Bool>) -> AnyView
    let features: [LocalizedStringKey: [FeatureWithView]]

    let setCookiesBeforeWebView: ((URL) async throws -> Void)?
    let reeedEnabledMode: (URL) -> ReeedEnabledMode
}

enum SchoolSystem {
    static var current: School!
}
