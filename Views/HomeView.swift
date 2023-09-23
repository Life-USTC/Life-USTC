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
    case curriculumWeek

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
        case .curriculumWeek:
            CurriculumWeekCard()
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
        case .curriculumWeek:
            return "Week Schedule"
        case .curriculumToday_old:
            return "Curriculum (old)"
        case .examPreview_old:
            return "Exam Arrangement (old)"
        }
    }
}

struct HomeView: View {
    @AppStorage("homeViewOrder") var homeViewOrder: [HomeViewCardType] = defaultHomeViewOrder

    @State var navigationToSettingsView = false
    @State private var textToBeDisplay = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack {
                Spacer()
                    .frame(height: 42)

                HStack {
                    Text(textToBeDisplay ? "Life@USTC" : "Study@USTC")
                        .font(.largeTitle.bold())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                textToBeDisplay.toggle()
                            }
                        }
                    Spacer()
                    Button {
                        navigationToSettingsView = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title2)
                    }
                }

                Spacer()
                    .frame(height: 30)

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
        .padding(.top, 0.1)
        .sheet(isPresented: $navigationToSettingsView) {
            NavigationStack {
                SettingsView()
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HomeView()
        }
    }
}
