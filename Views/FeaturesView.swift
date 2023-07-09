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
        VStack(spacing: 10) {
            configuration.icon
                .font(.title)
                .symbolRenderingMode(.hierarchical)
            configuration.title
                .lineLimit(2)
                .font(.caption)
        }
        .frame(width: 110, height: 110)
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
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

    @State var searchText = ""
    @AppStorage("userType") var userType: UserType?
    @AppStorage("featureViewStyle") private var style: Style = .list

    let gridItemLayout = [GridItem(.adaptive(minimum: 110)),
                          GridItem(.adaptive(minimum: 110)),
                          GridItem(.adaptive(minimum: 110))]

    var features: [String: [FeatureWithView]] = {
        var results: [String: [FeatureWithView]] = [:]
        var tmp: [FeatureWithView] = []

        // MARK: - Feeds:

        tmp = [.init(image: "doc.richtext",
                     title: "Feed".localized,
                     subTitle: "",
                     destinationView: AllSourceView().navigationBarTitleDisplayMode(.inline))]
        for feedSource in FeedSource.allToShow {
            tmp.append(feedSource.featureWithView)
        }
        results["Feed"] = tmp

        // MARK: - Classrooms:

        tmp = [.init(image: "doc.text.magnifyingglass",
                     title: "Classroom Status".localized,
                     subTitle: "",
                     destinationView: ClassroomView())]
        results["Public"] = tmp

        // MARK: -

        tmp = [.init(image: "book",
                     title: "Curriculum".localized,
                     subTitle: "",
                     destinationView: SharedCurriculumView),
               .init(image: "calendar.badge.clock",
                     title: "Exam".localized,
                     subTitle: "",
                     destinationView: SharedExamView),
               .init(image: "graduationcap",
                     title: "Score".localized,
                     subTitle: "",
                     destinationView: SharedScoreView)]
        results["UG AAS"] = tmp

        // MARK: -

        tmp = []
        for webFeature in FeaturesView.availableFeatures {
            tmp.append(webFeature)
        }
        results["Web"] = tmp

        return results
    }()

    var webFeaturesSearched: [String: [FeatureWithView]] {
        if searchText.isEmpty {
            return features
        } else {
            var result: [String: [FeatureWithView]] = [:]
            for (key, value) in features {
                let tmp = value.filter {
                    $0.title.lowercased().contains(searchText.lowercased()) ||
                        $0.subTitle.lowercased().contains(searchText.lowercased()) ||
                        $0.title.localized.contains(searchText) ||
                        $0.subTitle.localized.contains(searchText)
                }
                if !tmp.isEmpty {
                    result[key] = tmp
                }
            }
            return result
        }
    }

    var gridView: some View {
        ScrollView(showsIndicators: false) {
            ForEach(webFeaturesSearched.sorted(by: { $0.value.count < $1.value.count }), id: \.key) { key, features in
                Text(key.localized)
                    .font(.title2)
                    .fontWeight(.medium)
                    .hStackLeading()
                LazyVGrid(columns: gridItemLayout) {
                    ForEach(features, id: \.self) { feature in
                        NavigationLink {
                            feature.destinationView
                        } label: {
                            Label(feature.title.localized, systemImage: feature.image)
                                .labelStyle(FeatureLabelStyle())
                        }
                    }
                }
            }
            .padding()
        }
    }

    var mainView: some View {
        List {
            ForEach(webFeaturesSearched.sorted(by: { $0.value.count < $1.value.count }), id: \.key) { key, features in
                Section {
                    ForEach(features, id: \.self) { feature in
                        NavigationLink {
                            feature.destinationView
                        } label: {
                            Label(feature.title.localized, systemImage: feature.image)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                } header: {
                    Text(key.localized)
                }
            }
        }
        .scrollIndicators(.hidden)
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    var body: some View {
        Group {
            switch style {
            case .grid:
                gridView
            case .list:
                mainView
            }
        }
        .navigationTitle("Features")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                withAnimation {
                    style = style.next()
                }
            } label: {
                Label("Switch", systemImage: style.next().imageName)
            }
        }
        .searchable(text: $searchText, placement: .automatic)
    }
}

struct FeaturesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            FeaturesView()
        }
    }
}
