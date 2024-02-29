//
//  FeaturesView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import Reeeed
import SwiftUI

struct FeatureLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .center, spacing: 0) {
            configuration.icon
                .foregroundColor(Color("AccentColor"))
                .font(.title)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 50, height: 50)
                .padding(.horizontal, 10)
            configuration.title
                .foregroundColor(.primary)
                .lineLimit(2, reservesSpace: true)
                .font(.caption)
        }
    }
}

struct FeaturesView: View {
    private enum Style: String, CaseIterable {
        case list
        case grid

        var imageName: String {
            switch self {
            case .list:
                return "list.bullet.below.rectangle"
            case .grid:
                return "square.grid.2x2"
            }
        }
    }

    @ManagedData(.feedSource) var feedSourceList: [FeedSource]

    @State var navigationToSettingsView = false

    @State var searchText = ""

    @AppStorage("featureViewStyle") private var style: Style = .grid

    let gridItemLayout = [
        GridItem(.adaptive(minimum: 125)),
        GridItem(.adaptive(minimum: 125)),
        GridItem(.adaptive(minimum: 125)),
        GridItem(.adaptive(minimum: 125)),
    ]

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

    //TODO: should be change to enum in FeatureWithView
    var sectionPriority: [String: Int] = [
        "AAS": 2,
        "Feed": 4,
        "Public": 1,
        "Web": 3,
    ]

    var gridView: some View {
        VStack{
            Spacer()
                .frame(height: 10)
            ForEach(
                featureSearched.sorted(by: { sectionPriority[$0.key] ?? 10 < sectionPriority[$1.key] ?? 10 }),
                id: \.key
            ) { key, features in
                VStack(alignment: .leading) {
                    Text(key.localized)
                        .font(.title2)
                        .fontWeight(.medium)
                        .padding(.top, 20)
                        .padding(.leading, 20)
                    LazyVGrid(columns: gridItemLayout) {
                        ForEach(features, id: \.self) { feature in
                            NavigationLink {
                                AnyView(feature.destinationView())
                            } label: {
                                Label(feature.title.localized, systemImage: feature.image)
                                    .labelStyle(FeatureLabelStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                }
                .background {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color("BackgroundWhite"))
                }
                .padding(.bottom, 30)
            }
        }
    }

    var listView: some View {
        List {
            ForEach(
                featureSearched.sorted(by: { sectionPriority[$0.key] ?? 10 < sectionPriority[$1.key] ?? 10 }),
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
    }

    var body: some View {
        VStack (alignment: .leading){
            Group {
                switch style {
                case .grid:
                    ScrollView (showsIndicators: false) {
                        VStack {
                            gridView
                                .padding(.horizontal, 18)
                            Spacer()
                                .frame(height: 70)
                        }
                    }
                case .list:
                    listView
                }
            }
            .navigationTitle("Features")
            .toolbar {
                Button {
                    withAnimation {
                        style = style.next()
                    }
                } label: {
                    Label("Switch", systemImage: style.next().imageName)
                }
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
            .searchable(text: $searchText, placement: .automatic)
        }
        .background(Color(.systemGroupedBackground))
    }

    init() {
        features = collectFeatures()
    }
}

extension FeaturesView {
    func collectFeatures() -> [String: [FeatureWithView]] {
        var results: [String: [FeatureWithView]] = [:]

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
        ]

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
