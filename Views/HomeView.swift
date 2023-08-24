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
            if #available(iOS 17.0, *) { CurriculumWeekView() }
        }.padding(.horizontal).navigationTitle("Life@USTC")
            .navigationBarTitleDisplayMode(.inline).sheet(
                isPresented: $navigationToSettingsView
            ) { NavigationStack { SettingsView() } }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View { NavigationStack { HomeView() } }
}
