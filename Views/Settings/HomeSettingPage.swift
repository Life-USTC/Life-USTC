//
//  HomeSettingPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/30.
//

import SwiftUI

struct HomeSettingPage: View {
    @AppStorage("homeViewOrder") var homeViewOrder: [HomeViewCardType] = [
        .curriculumToday, .examPreview, .curriculumWeek,
    ]

    var body: some View {
        List($homeViewOrder, id: \.rawValue, editActions: .all) { $type in
            Text(type.name.localized)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(HomeViewCardType.allCases, id: \.rawValue) { type in
                        if !homeViewOrder.contains(type) {
                            Button {
                                homeViewOrder.append(type)
                            } label: {
                                Label(type.name.localized, systemImage: "plus")
                            }
                        }
                    }
                } label: {
                    Label("Add Card", systemImage: "plus")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .navigationTitle("Home Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview{
    HomeSettingPage()
}
