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
    @AppStorage("homeViewOrder") var homeViewOrder: [HomeViewCardType] = [
        .curriculumToday, .examPreview, .curriculumWeek,
    ]
    @State var navigationToSettingsView = false

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack {
                    Spacer()
                        .frame(height: 42)
                    
                    HStack {
                        Text("Life@USTC")
                            .font(.largeTitle.bold())
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
            .sheet(isPresented: $navigationToSettingsView) {
                NavigationStack {
                    SettingsView()
                }
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
