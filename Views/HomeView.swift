//
//  HomeView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import SwiftUI

enum HomeViewCardType: String, CaseIterable, Codable {
    case curriculumToday
    case examPreview
    case featurePreview

    case curriculumToday_old
    case examPreview_old

}

extension HomeViewCardType {
    var view: any View {
        switch self {
        case .curriculumToday:
            CurriculumTodayCard()
        case .examPreview:
            ExamPreviewCard()
        case .featurePreview:
            FeaturePreviewCard()
        case .curriculumToday_old:
            CurriculumTodayCard_old()
        case .examPreview_old:
            ExamPreviewCard_old()
        }
    }

    var name: String {
        switch self {
        case .curriculumToday:
            return "Curriculum"
        case .examPreview:
            return "Exam Arrangement"
        case .featurePreview:
            return "Features"
        case .curriculumToday_old:
            return "Curriculum (old)"
        case .examPreview_old:
            return "Exam Arrangement (old)"
        }
    }
}

struct HomeView: View {
    @AppStorage("homeViewOrder") var homeViewOrder: [HomeViewCardType] = defaultHomeViewOrder
    @AppStorage("Life-USTC") var life_ustc: Bool = false

    var body: some View {
        VStack {
            ScrollView(showsIndicators: false) {
                Spacer()
                    .frame(height: 10)

                VStack(spacing: 40) {
                    ForEach(homeViewOrder, id: \.self) { cardType in
                        AnyView(
                            cardType.view
                        )
                    }
                }

                Spacer()
                    .frame(height: 70)
            }
            .padding(.horizontal, 20)
        }
        .navigationTitle(life_ustc ? "Life@USTC" : "Study@USTC")
        .background(Color(.systemGroupedBackground))
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HomeView()
        }
    }
}
