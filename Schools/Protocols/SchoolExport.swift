//
//  SchoolExport.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import SwiftUI

enum ReeedEnabledMode {
    case always
    case userDefined
    case never
}

protocol SchoolExport {
    associatedtype VM: ViewModifier

    var abbrName: String { get }

    var fullName: String { get }

    var fullChineseName: String { get }

    var commonNames: [String] { get }

    var settings: [SettingWithView] { get }

    var remoteFeedURL: URL { get }

    var examDelegate: ExamDelegateProtocol { get }

    var curriculumDelegate: CurriculumProtocol { get }

    var curriculumBehavior: CurriculumBehavior { get }

    var geoLocationDataURL: URL { get }

    var buildingimgMappingURL: URL { get }

    var buildingimgBaseURL: URL { get }

    var scoreDelegate: ScoreDelegateProtocol { get }

    var homeworkDelegate: HomeworkDelegateProtocol { get }

    var baseModifier: VM { get }

    var firstLoginView: (Binding<Bool>) -> AnyView { get }

    var features: [LocalizedStringKey: [FeatureWithView]] { get }

    var setCookiesBeforeWebView: ((_ url: URL) async throws -> Void)? { get }

    var reeedEnabledMode: ((_ url: URL) -> ReeedEnabledMode) { get }
}
