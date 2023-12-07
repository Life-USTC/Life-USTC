//
//  FeaturesView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import Reeeed
import SwiftUI

struct FeaturesView: View {
    @ManagedData(.feedSource) var feedSourceList: [FeedSource]
    
    @State var navigationToSettingsView = false

    @State var searchText = ""

    var features: [String: [FeatureWithView]] = [:]
    var featureSearched: [String: [FeatureWithView]] {
        guard searchText.isEmpty else {
            var result: [String: [FeatureWithView]] = [:]
            for (key, value) in features {
                let tmp = value.filter {
                    $0.title.lowercased().contains(searchText.lowercased())
                        || $0.subTitle.lowercased()
                            .contains(searchText.lowercased())
                        || $0.title.localized.contains(searchText)
                        || $0.subTitle.localized.contains(searchText)
                }
                if !tmp.isEmpty { result[key] = tmp }
            }
            return result
        }
        return features
    }

    var body: some View {
        List {
            ForEach(
                featureSearched.sorted(by: { $0.value.count < $1.value.count }),
                id: \.key
            ) { key, features in
                Section {
                    ForEach(features, id: \.id) { feature in
                        NavigationLink {
                            AnyView(feature.destinationView())
                        } label: {
                            Label(
                                feature.title.localized,
                                systemImage: feature.image
                            )
                            .symbolRenderingMode(.hierarchical)
                        }
                    }
                } header: {
                    Text(key.localized)
                }
            }

            Section {

            } footer: {
                Spacer()
                    .frame(height: 70)
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .automatic)
        .navigationTitle("Features")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            Button {
                navigationToSettingsView = true
            } label: {
                Image(systemName: "gearshape")
            }
        }
        .sheet(isPresented: $navigationToSettingsView) {
            NavigationStack {
                SettingsView()
            }
        }
    }

    init() {
        features = collectFeatures()
    }
}

extension FeaturesView {
    func collectFeatures() -> [String: [FeatureWithView]] {
        var results: [String: [FeatureWithView]] = [:]

        results["Feed"] =
            [
                .init(
                    image: "doc.richtext",
                    title: "Feed",
                    subTitle: "",
                    destinationView: {
                        AllSourceView()
                            .navigationBarTitleDisplayMode(.inline)
                    }
                )
            ] + feedSourceList.map { FeatureWithView($0) }

        results["AAS"] = [
            .init(
                image: "book",
                title: "Curriculum",
                subTitle: "",
                destinationView: { CurriculumDetailView() }
            ),
            .init(
                image: "calendar.badge.clock",
                title: "Exam",
                subTitle: "",
                destinationView: { ExamDetailView() }
            ),
            .init(
                image: "graduationcap",
                title: "Score",
                subTitle: "",
                destinationView: { ScoreView() }
            ),
            .init(
                image: "rectangle.stack",
                title: "Homework (Blackboard)",
                subTitle: "",
                destinationView: { HomeworkDetailView() }
            )
        ]

        for (key, features) in SchoolExport.shared.features {
            if results.keys.contains(key) {
                results[key]! += features
            } else {
                results[key] = features
            }
        }

        return results
    }
}

struct FeaturesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            FeaturesView()
        }
    }
}
