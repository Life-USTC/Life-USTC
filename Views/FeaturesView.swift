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
                .foregroundColor(Color.accentColor)
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
    enum Style: String, CaseIterable {
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

        func next() -> Style {
            let allCases = Style.allCases
            let currentIndex = allCases.firstIndex(of: self)!
            let nextIndex = (currentIndex + 1) % allCases.count
            return allCases[nextIndex]
        }
    }

    @ManagedData(.feedSources) var feedSources: [FeedSource]

    @AppStorage("featureViewStyle") var style: Style = .grid

    @State var searchText = ""

    let gridItemLayout = [
        GridItem(.adaptive(minimum: 125)),
        GridItem(.adaptive(minimum: 125)),
        GridItem(.adaptive(minimum: 125)),
        GridItem(.adaptive(minimum: 125)),
    ]

    let sectionPriority: [LocalizedStringKey: Int] = [
        "AAS": 2,
        "Feed": 4,
        "Public": 1,
        "Web": 3,
    ]

    var features: [LocalizedStringKey: [FeatureWithView]] {
        collectFeatures()
    }

    var featuresSearched: [LocalizedStringKey: [FeatureWithView]] {
        guard !searchText.isEmpty else { return features }

        var result: [LocalizedStringKey: [FeatureWithView]] = [:]
        for (key, value) in features {
            let filtered = value.filter { feature in
                String(describing: feature.title).lowercased().contains(searchText.lowercased())
                    || String(describing: feature.subTitle).lowercased().contains(searchText.lowercased())
            }
            if !filtered.isEmpty { result[key] = filtered }
        }
        return result
    }

    var gridView: some View {
        VStack {
            Spacer()
                .frame(height: 10)
            ForEach(
                featuresSearched.sorted(by: { sectionPriority[$0.key] ?? 10 < sectionPriority[$1.key] ?? 10 }),
                id: \.key
            ) { key, features in
                VStack(alignment: .leading) {
                    Text(key)
                        .font(.title2)
                        .fontWeight(.medium)
                        .padding(.top, 20)
                        .padding(.leading, 20)
                    LazyVGrid(columns: gridItemLayout) {
                        ForEach(features, id: \.self) { feature in
                            NavigationLink {
                                AnyView(feature.destinationView())
                            } label: {
                                Label(feature.title, systemImage: feature.image)
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
                featuresSearched.sorted(by: { sectionPriority[$0.key] ?? 10 < sectionPriority[$1.key] ?? 10 }),
                id: \.key
            ) { key, features in
                Section {
                    ForEach(features, id: \.id) { feature in
                        NavigationLink {
                            AnyView(feature.destinationView())
                        } label: {
                            Label(feature.title, systemImage: feature.image)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                } header: {
                    Text(key)
                }
            }
        }
    }

    var body: some View {
        Group {
            switch style {
            case .grid:
                ScrollView(showsIndicators: false) {
                    VStack {
                        gridView
                            .padding(.horizontal, 18)
                        Spacer()
                            .frame(height: 70)
                    }
                }
                .background(Color(.systemGroupedBackground))
            case .list:
                listView
            }
        }
        .navigationTitle("Features")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    withAnimation {
                        style = style.next()
                    }
                } label: {
                    Label("Switch", systemImage: style.next().imageName)
                }
            }
        }
        .searchable(text: $searchText)
    }
}

extension FeaturesView {
    func collectFeatures() -> [LocalizedStringKey: [FeatureWithView]] {
        var results: [LocalizedStringKey: [FeatureWithView]] = [:]

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
                destinationView: { ScoreDetailView() }
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
                    }
                )
            ] + feedSources.map { FeatureWithView($0) }

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
