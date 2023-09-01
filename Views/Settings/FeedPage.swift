//
//  FeedPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/1.
//

import SwiftUI

struct FeedSettingView: View {
    @ManagedData(.feedSourceList) var feedSourceList: [FeedSource]

    @AppStorage("feedSourceNameListToRemove") var removedNameList: [String] = []

    var body: some View {
        List {
            Section {
                ForEach(feedSourceList.map(\.name), id: \.self) { name in
                    Button {
                        if removedNameList.contains(name) {
                            removedNameList.removeAll(where: { $0 == name })
                        } else {
                            removedNameList.append(name)
                        }
                    } label: {
                        HStack {
                            Text(name).foregroundColor(.primary)
                            Spacer()
                            if !removedNameList.contains(name) {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Feed source to show").textCase(.none)
                    AsyncStatusLight(status: _feedSourceList.status)
                }
            } footer: {
                Text("A reload may be required for this to take effect.")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    _feedSourceList.triggerRefresh()
                } label: {
                    Label("Refresh List", systemImage: "arrow.clockwise")
                }
            }
        }
        .asyncStatusOverlay(_feedSourceList.status, showLight: false)
        .scrollContentBackground(.hidden)
        .navigationBarTitle("Feed Source Settings", displayMode: .inline)
    }
}

struct FeedSettingView_Previews: PreviewProvider {
    static var previews: some View { NavigationStack { FeedSettingView() } }
}
