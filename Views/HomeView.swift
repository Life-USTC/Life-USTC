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
}

extension HomeViewCardType {
    var view: some View {
        Group {
            switch self {
            case .curriculumToday:
                CurriculumTodayCard()
            case .examPreview:
                ExamPreviewCard()
            case .featurePreview:
                FeaturePreviewCard()
            }
        }
    }

    var name: LocalizedStringKey {
        switch self {
        case .curriculumToday:
            return "Curriculum"
        case .examPreview:
            return "Exam Arrangement"
        case .featurePreview:
            return "Features"
        }
    }
}

let defaultHomeViewOrder: [HomeViewCardType] = [
    .featurePreview,
    .curriculumToday,
    .examPreview,
]

struct HomeView: View {
    @AppStorage("homeViewOrder") var homeViewOrder: [HomeViewCardType] = defaultHomeViewOrder
    @AppStorage("Life-USTC") var lifeUstc = false

    var navigationTitle: LocalizedStringKey {
        lifeUstc ? "Life@USTC" : "Study@USTC"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 40) {
                ForEach(homeViewOrder, id: \.self) { cardType in
                    cardType.view
                        .padding(.horizontal, 20)
                }
            }
        }
        .navigationTitle(navigationTitle)
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
