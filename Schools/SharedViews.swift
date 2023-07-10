//
//  SharedViews.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/7.
//

import SwiftUI

var SharedScoreView: some View {
    ScoreView(scoreDeleage: USTCScoreDelegate.shared)
}

var SharedExamView: some View {
    ExamView(examDelegate: USTCExamDelegate.shared)
}

var SharedHomeView: some View {
    HomeView(curriculumDelegate: USTCCurriculumDelegate.shared,
             examDelegate: USTCExamDelegate.shared)
}

var SharedCurriculumView: some View {
    CurriculumView(curriculumDelegate: USTCCurriculumDelegate.shared)
}

extension FeaturesView {
    static var availableFeatures: [String: [FeatureWithView]] {
        USTCExports.features
    }
}

extension FeedSource {
    static var feedURLs: [URL] {
        USTCExports.feedURLs
    }

    static var remoteURL: URL {
        USTCExports.remoteFeedURL
    }

    static var localFeedJSONName: String {
        USTCExports.localFeedJSOName
    }
}

extension SettingsView {
    static var availableSettings: [SettingWithView] {
        USTCExports.settings
    }
}

extension ContentView {
    static var SharedModifier: some ViewModifier {
        USTCExports.baseModifier
    }

    static var firstLoginView: (Binding<Bool>) -> AnyView {
        USTCExports.firstLoginView
    }
}
