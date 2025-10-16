//
//  HomeSettingPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/30.
//

import SwiftUI

let defaultHomeViewOrder: [HomeViewCardType] = [
    .featurePreview,
    .curriculumToday,
    .examPreview,
]

struct HomeSettingPage: View {
    @AppStorage("homeViewOrder") var homeViewOrder: [HomeViewCardType] = defaultHomeViewOrder

    var body: some View {
        List($homeViewOrder, id: \.rawValue, editActions: .all) { $type in
            Text(type.name)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(HomeViewCardType.allCases, id: \.rawValue) { type in
                        if !homeViewOrder.contains(type) {
                            Button {
                                homeViewOrder.append(type)
                            } label: {
                                Label(type.name, systemImage: "plus")
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
        .navigationTitle("Home Page Settings")
    }
}

#Preview {
    HomeSettingPage()
}
