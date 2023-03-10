//
//  HomeView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import SwiftUI

private struct HomeFeature {
    var title: String
    var subTitle: String
    var destination: AnyView
    var preview: AnyView
}

struct HomeView: View {
    private var features: [HomeFeature] =
        [.init(title: "Feed",
               subTitle: currentDateString,
               destination: .init(AllSourceView()),
               preview: .init(FeedHScrollView())),
//         .init(title: "Health Check",
//               subTitle: "",
//               destination: .init(HealthCheckPage()),
//               preview: .init(HealthCheckPreview())),
         .init(title: "Curriculum",
               subTitle: currentWeekDayString,
               destination: .init(CurriculumView()),
               preview: .init(CurriculumPreview())),
         .init(title: "Exam",
               subTitle: "",
               destination: .init(ExamView()),
               preview: .init(ExamPreview()))]

    var body: some View {
        ScrollView(showsIndicators: false) {
            ForEach(features, id: \.title) { feature in
                HStack {
                    TitleAndSubTitle(title: feature.title, subTitle: feature.subTitle, style: .reverse)
                    NavigationLinkAddon {
                        feature.destination
                    } label: {
                        Label("More", systemImage: "chevron.right.2")
                            .labelStyle(.iconOnly)
                    }
                }
                .padding(.bottom, 7)
                .padding(.top, 15)

                feature.preview
            }
        }
        .padding([.leading, .trailing])
        .navigationTitle("Life@USTC")
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
