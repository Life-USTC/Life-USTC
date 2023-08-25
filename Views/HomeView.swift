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
    @State var date = Date()
    @State var navigationToSettingsView = false

    var mmddFormatter: DateFormatter {
        let tmp = DateFormatter()
        tmp.dateStyle = .short
        tmp.timeStyle = .none
        return tmp
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            CurriculumWeekView()

            ExamPreview(exams: [])
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
