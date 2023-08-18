//
//  SharedViews.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/7.
//

import SwiftUI

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
