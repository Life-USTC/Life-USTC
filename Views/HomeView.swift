//
//  HomeView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import SwiftUI

struct HomeView: View {
    @State var navigationToSettingsView = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                CurriculumTodayCard_old()
                CurriculumTodayCard()
                ExamPreviewCard()
                CurriculumWeekCard()
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
