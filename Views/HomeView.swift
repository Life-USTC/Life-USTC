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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                ForEach(homeViewOrder, id: \.self) { cardType in
                    AnyView(
                        cardType.view
                    )
                }
            }

            Spacer()
                .frame(height: 70)
        }
        .padding(.horizontal)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    navigationToSettingsView = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $navigationToSettingsView) {
            NavigationStack {
                SettingsView()
            }
        }
        .navigationTitle("Life@USTC")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HomeView()
        }
    }
}
