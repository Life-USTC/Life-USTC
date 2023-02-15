//
//  FeedPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/1.
//

import SwiftUI

struct FeedSettingView: View {
    @AppStorage("homeShowPostNumbers") var feedPostNumber = 4
    @AppStorage("feedSourceNameListToRemove") var removedNameList: [String] = []
    @AppStorage("useReeed") var useReeed = true
    @AppStorage("useNewUIForFeed") var useNewUI = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Stepper("Front page post numbers: ".localized + String(feedPostNumber), value: $feedPostNumber)
                    Toggle("Use new UI", isOn: $useNewUI)
                    Toggle("Use reader", isOn: $useReeed)
                } header: {
                    Text("General")
                        .textCase(.none)
                } footer: {
                    Text("Reader would generaly improve reading experience for web page that aren't optimized for mobile.")
                }

                Section {
                    ForEach(FeedSource.all.map(\.name), id: \.self) { name in
                        Button {
                            if removedNameList.contains(name) {
                                removedNameList.removeAll(where: { $0 == name })
                            } else {
                                removedNameList.append(name)
                            }
                        } label: {
                            HStack {
                                Text(name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if !removedNameList.contains(name) {
                                    Image(systemName: "checkmark.seal.fill")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Feed source to show")
                        .textCase(.none)
                } footer: {
                    Text("A reload may be required for this to take effect.")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationBarTitle("Feed Source Settings", displayMode: .inline)
        }
    }
}

struct FeedSettingView_Previews: PreviewProvider {
    static var previews: some View {
        FeedSettingView()
    }
}
