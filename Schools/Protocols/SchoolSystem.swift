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

    let remoteFeedURL: URL
    let geoLocationURL: URL
    let buildingimgBaseURL: URL
    let buildingimgMappingURL: URL

    let curriculumBehavior: CurriculumBehavior

    let updateCurriculum: () async throws -> Void
    let updateExam: () async throws -> Void
    let updateScore: () async throws -> Void
    let updateHomework: () async throws -> Void

    let firstLoginView: (Binding<Bool>) -> AnyView
    let settings: [SettingWithView]
    let features: [LocalizedStringKey: [FeatureWithView]]

    let setCookiesBeforeWebView: ((URL) async throws -> Void)?
    let reeedEnabledMode: (URL) -> ReeedEnabledMode
}

enum SchoolSystem {
    static var current: School!
}
